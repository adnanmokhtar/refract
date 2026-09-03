#!/usr/bin/env bash
# validate-optimize-artifacts.sh — enforces /optimize Phase 0 + ledger-row gates.
#
# Phase 0 (always): ai/optimize/_architecture-decisions.md
#   — 4 evidence blocks (non-empty), detector scans, per-finding citations,
#     hand-wave grep, idioms oracle presence (+ strict: oracle referenced).
#
# Per ledger row (when ai/optimize/ledger.md exists): fenced YAML rows with
#   id: <token> (same shape as migrate-parallel / optimize-parallel).
#   — gaps_in == gaps_closed for terminal statuses (re-detect parity; runs
#     whenever the ledger exists — NOT gated behind --strict)
#   — structural classes: net-lines ≤ 0 (when git + --phase-base available)
#   — non-structural classes with net line additions: idiom citation in findings file
#   — performance / render-waste rows: findings file MUST carry a measured
#     baseline + after pair (no perf claim without a measured pair)
# The ledger is MANDATORY for any run that fixed findings (findings/*.md present)
#   — it is the only re-detect proof surface.
#
# Run summary (final-report.md), always when present:
#   — coverage not dropped (baseline at ai/optimize/_coverage-baseline vs the
#     report's Coverage: line; warn-only if either surface is absent)
#   — boot-check: pass | skipped(<reason>) line REQUIRED; if skipped the reason
#     must also appear under Not validated:
#   — any perf claim (perf-win: / p95 / latency / throughput) needs a measured pair
#
# Usage:
#   validate-optimize-artifacts.sh [--artifact=PATH] [--ledger=PATH] [--findings-dir=PATH]
#   validate-optimize-artifacts.sh [--report=PATH] [--coverage-baseline=PATH]
#   validate-optimize-artifacts.sh [--strict] [--quiet] [--phase-base=<git-ref>]
#   validate-optimize-artifacts.sh                    # legacy: first positional = artifact path
#
# Exit codes:
#   0 — pass
#   1 — validation failures
#   2 — usage / fatal env

set -euo pipefail
export LC_ALL=C

ARCH_ARTIFACT="${ARCH_ARTIFACT:-ai/optimize/_architecture-decisions.md}"
LEDGER_PATH="${LEDGER_PATH:-ai/optimize/ledger.md}"
FINDINGS_DIR="${FINDINGS_DIR:-ai/optimize/findings}"
FINAL_REPORT="${FINAL_REPORT:-ai/optimize/final-report.md}"
COVERAGE_BASELINE="${COVERAGE_BASELINE:-ai/optimize/_coverage-baseline}"
# At least one convention oracle (matches commands/optimize.md pre-requisites).
ORACLE_IDIOMS=".claude/_extracted-idioms.md"
ORACLE_PROFILE=".claude/codebase-profile.md"
ORACLE_PROFILE_ROOT="codebase-profile.md"

STRICT=0
QUIET=0
PHASE_BASE=""
POSITIONAL_ARTIFACT=""

TOTAL_PASS=0
TOTAL_FAIL=0
FAILURES=()

log_pass() {
  TOTAL_PASS=$((TOTAL_PASS + 1))
  [[ $QUIET -eq 0 ]] && echo "  ✓ $1" || true
}

log_fail() {
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
  FAILURES+=("$1")
  echo "  ✗ $1" >&2
}

log_warn() {
  if [[ $STRICT -eq 1 ]]; then
    log_fail "[strict] $1"
  elif [[ $QUIET -eq 0 ]]; then
    echo "  ⚠ $1"
  fi
}

log_section() {
  [[ $QUIET -eq 0 ]] && echo && echo "── $1 ──" || true
}

# ── Structural vs functional-style (optimize / align taxonomy) ───────────────
is_structural_optimize() {
  case "${1:-}" in
    architectural|structural|dead-code|duplicated-logic|reinvented-wrapper|silent-catch|over-abstraction|drift|layer-violation|god-module|cyclic|cycl|clean-code|refactoring|solid-violation)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

is_terminal_optimize_status() {
  case "${1:-}" in
    verified|done|fixed)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# ── Ledger discovery (id + fenced YAML; status:/state:) ─────────────────────
discover_optimize_rows() {
  awk '
    function emit() {
      if (id != "") print id "|" class "|" status "|" gaps_in "|" gaps_closed "|" verb
    }
    /^id: [A-Za-z0-9][A-Za-z0-9_-]*$/ {
      if (id != "") emit()
      id = $2
      class = ""; status = ""; gaps_in = ""; gaps_closed = ""; verb = ""
      in_block = 1
      next
    }
    /^```/ {
      if (in_block) emit()
      id = ""; class = ""; status = ""; gaps_in = ""; gaps_closed = ""; verb = ""
      in_block = 0
      next
    }
    in_block && /^status: / { status = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", status); next }
    in_block && /^state: / {
      if (status == "") { status = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", status) }
      next
    }
    in_block && /^class: / {
      class = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", class)
      next
    }
    in_block && /^gaps_in: / { gaps_in = $2; next }
    in_block && /^gaps_closed: / { gaps_closed = $2; next }
    in_block && /^closure_verb:/ { verb = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", verb); next }
    END { if (id != "") emit() }
  ' "$LEDGER_PATH"
}

# ── Phase 0 ───────────────────────────────────────────────────────────────────
check_artifact_exists() {
  if [[ ! -f "$ARCH_ARTIFACT" ]]; then
    log_fail "architecture-decisions artifact MISSING at $ARCH_ARTIFACT — Phase 0 must produce this file."
    return 1
  fi
  log_pass "architecture-decisions artifact exists at $ARCH_ARTIFACT"
  return 0
}

check_phase_0_blocks_nonempty() {
  local file="$ARCH_ARTIFACT"
  [[ ! -f "$file" ]] && return 0

  local blocks_required=(
    "Phase 0 — Dependency map evidence"
    "Phase 0 — Responsibility map evidence"
    "Phase 0 — Layer attribution evidence"
    "Phase 0 — Detector run evidence"
  )
  local missing=() empty=()
  local title body nonempty

  for title in "${blocks_required[@]}"; do
    if ! grep -qF "$title" "$file"; then
      missing+=("$title")
      continue
    fi
    # 🔴 THE BLOCK IS ALMOST ALWAYS A MARKDOWN HEADING, SO MATCH ONE.
    #
    # This read `index($0, T) == 1`, which demands the title start at COLUMN 1 — and the
    # artifact this validator polices writes `## Phase 0 — Dependency map evidence`, exactly
    # as the skill that generates it specifies (code-quality/skills/architectural-diagnosis
    # § "Phase 0"). Behind `## ` the title starts at column 4, so grab never turned on, body
    # came back empty, and a CORRECTLY WRITTEN artifact was reported as "Phase 0 evidence
    # blocks empty (heading only)" — all four blocks, every run.
    #
    # The `grep -qF` presence test above matches the same line as a substring, so the verdict
    # was never "missing" and always "empty": the check could see every heading and none of
    # their bodies. Found by writing this script's first --self-test — the fixture used the
    # documented format and could not be made to pass.
    body=$(awk -v T="$title" '
      BEGIN { grab = 0 }
      (index($0, T) > 0 && ($0 ~ /^#+[ \t]/ || $0 == T)) { grab = 1; next }
      grab && /^#{1,3} / { exit }
      grab { print }
    ' "$file")
    nonempty=$(echo "$body" | sed '/^[[:space:]]*$/d' | head -1)
    if [[ -z "$nonempty" ]]; then
      empty+=("$title")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fail "Phase 0 evidence blocks missing in $file: ${missing[*]}"
    return 1
  fi
  if [[ ${#empty[@]} -gt 0 ]]; then
    log_fail "Phase 0 evidence blocks empty (heading only) in $file: ${empty[*]}"
    return 1
  fi

  local detectors_scanned
  detectors_scanned=$( { grep -cE '^[[:space:]]*Modules scanned:[[:space:]]*[1-9][0-9]*' "$file" 2>/dev/null || echo 0; } | tail -1 )
  detectors_scanned=${detectors_scanned:-0}
  if [[ "$detectors_scanned" -lt 1 ]]; then
    log_fail "Phase 0 detector evidence has zero modules scanned in $file"
    return 1
  fi

  log_pass "Phase 0: 4 non-empty blocks, detector(s) with Modules scanned ≥ 1"
  return 0
}

check_per_finding_citations_phase0() {
  local file="$ARCH_ARTIFACT"
  [[ ! -f "$file" ]] && return 0

  local tmp breaches
  tmp=$(mktemp -t opt-fsec.XXXXXX)
  awk '
    function check_section() {
      if (buf !~ /<[^>]+:[0-9]+>/ && buf !~ /`[^`]+:[0-9]+`/) print sechead
    }
    /^### F-A-[0-9]+/ {
      if (in_section) check_section()
      sechead = $0
      buf = ""
      in_section = 1
      next
    }
    in_section { buf = buf $0 "\n" }
    END { if (in_section) check_section() }
  ' "$file" > "$tmp"

  breaches=$( { grep -cve '^[[:space:]]*$' "$tmp" 2>/dev/null || echo 0; } | tail -1 )
  rm -f "$tmp"
  if [[ "${breaches:-0}" -gt 0 ]]; then
    log_fail "One or more ### F-A-* sections in $file lack <path:line> citations"
    return 1
  fi
  log_pass "every Phase 0 ### F-A-* section has ≥1 path:line citation"
  return 0
}

check_no_handwaves_file() {
  local label="$1"
  local file="$2"
  [[ ! -f "$file" ]] && return 0

  local scrubbed handwaves
  scrubbed=$(mktemp -t optimize-scrub.XXXXXX)
  awk '
    BEGIN { inf = 0 }
    /^```/ { inf = 1 - inf; next }
    inf { next }
    {
      gsub(/`[^`]*`/, "")
      print
    }
  ' "$file" > "$scrubbed"
  handwaves=$(grep -cE '\.\.\.[[:space:]]*$|, etc\.| etc\.\)|\.\.\.[[:space:]]*\||\b[0-9]+\+[[:space:]]+(modules?|imports?|cycles?|fingerprints?)\b|\band so on\b|\bdeferred to phase 2\b|\bdeferred to tactical\b|\bdeferred to[\t ]+phase[\t ]+2\b|\bby inspection\b' "$scrubbed" 2>/dev/null || echo 0)
  rm -f "$scrubbed"
  handwaves=${handwaves:-0}

  if [[ "$handwaves" -gt 0 ]]; then
    log_fail "$label has $handwaves hand-wave(s) in $file"
    return 1
  fi
  log_pass "no hand-wave language in $label"
  return 0
}

check_oracle_present() {
  local oracle_path=""
  if [[ -f "$ORACLE_IDIOMS" ]]; then
    oracle_path="$ORACLE_IDIOMS"
  elif [[ -f "$ORACLE_PROFILE" ]]; then
    oracle_path="$ORACLE_PROFILE"
  elif [[ -f "$ORACLE_PROFILE_ROOT" ]]; then
    oracle_path="$ORACLE_PROFILE_ROOT"
  else
    log_fail "convention oracle MISSING — need $ORACLE_IDIOMS, $ORACLE_PROFILE, or $ORACLE_PROFILE_ROOT — run /setup-project --refine"
    return 1
  fi
  log_pass "convention oracle present at $oracle_path"

  if [[ $STRICT -eq 1 ]]; then
    if ! grep -qE '_extracted-idioms|codebase-profile|\.claude/_extracted-idioms' "$ARCH_ARTIFACT" 2>/dev/null; then
      log_fail "[strict] Phase 0 doc must reference _extracted-idioms.md or codebase-profile (discipline oracle)"
      return 1
    fi
    log_pass "[strict] Phase 0 references discipline oracle"
  fi
  return 0
}

# ── Row-level checks ──────────────────────────────────────────────────────────
_git_net_for_row() {
  local id="$1"
  local commits_shas added removed sha stat a r
  local range=()
  [[ -n "${PHASE_BASE:-}" ]] && range=("${PHASE_BASE}..HEAD")
  commits_shas=$(git log --grep="${id}:" --grep="optimize/${id}:" --format='%H' "${range[@]}" 2>/dev/null || true)
  added=0
  removed=0
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    stat=$(git show --shortstat "$sha" 2>/dev/null | tail -1 || true)
    a=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    r=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
    added=$((added + ${a:-0}))
    removed=$((removed + ${r:-0}))
  done <<< "$commits_shas"
  echo "$added $removed ${commits_shas:-}"
}

# ── CHECK: code-level smells in the row's ACTUAL commit diff (#30) ──────────
# The optimize validator checked only the ledger/report, so an optimization "fix" that ADDED a
# silent catch or debug print shipped green. optimize has no per-row scope field, but it ties a
# row to its commits by message convention — so grep the ADDED lines of those commits for an
# unambiguous silent swallow (empty catch{} / except: pass → FAIL) + debug prints (WARN).
check_row_code_smells() {
  local id="$1"
  command -v git >/dev/null 2>&1 || { log_warn "$id: git not on PATH; code-smell scan skipped"; return 0; }
  local range=() commits_shas
  [[ -n "${PHASE_BASE:-}" ]] && range=("${PHASE_BASE}..HEAD")
  commits_shas=$(git log --grep="${id}:" --grep="optimize/${id}:" --format='%H' "${range[@]}" 2>/dev/null || true)
  [[ -z "$commits_shas" ]] && { log_pass "$id: no commit found; code-smell scan skipped"; return 0; }
  local smells=0 sha added
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    added=$(git show "$sha" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)
    if echo "$added" | grep -qE 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}|except[^:]*:[[:space:]]*pass[[:space:]]*$'; then
      log_fail "$id: commit $sha ADDS a silent catch (empty catch{} / except: pass) — route failures through the error handler (No Silent Catch)"
      smells=$((smells + 1))
    fi
    if echo "$added" | grep -qE '\bconsole\.(log|debug)\(|^\+[[:space:]]*print\('; then
      log_warn "$id: commit $sha ADDS a debug print (console.log / print) — use the project logger"
    fi
  done <<< "$commits_shas"
  [[ $smells -eq 0 ]] && log_pass "$id: optimization commits free of silent-catch smells"
  [[ $smells -gt 0 ]] && return 1
  return 0
}

check_gap_count_parity() {
  local id="$1" status="$2" gin="$3" gcl="$4"

  if ! is_terminal_optimize_status "$status"; then
    log_pass "$id: gap parity N/A (non-terminal status $status)"
    return 0
  fi

  local gi gc
  gi=$(echo "$gin" | tr -cd '0-9')
  gc=$(echo "$gcl" | tr -cd '0-9')
  gi=${gi:-0}
  gc=${gc:-0}

  if [[ "$gi" != "$gc" ]]; then
    log_fail "$id: gaps_in ($gi) != gaps_closed ($gc) — cannot advance to $status"
    return 1
  fi
  log_pass "$id: gap-count parity ($gi == $gc) for terminal status"
  return 0
}

check_net_lines_structural() {
  local id="$1" cls="$2"

  if ! is_structural_optimize "$cls"; then
    log_pass "$id: class '$cls' — structural net-lines rule N/A"
    return 0
  fi
  if [[ -z "${PHASE_BASE:-}" ]]; then
    log_warn "$id: --phase-base not provided; skipping structural net-lines check"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_warn "$id: git not on PATH; skipping structural net-lines check"
    return 0
  fi

  local stats added removed commits
  read -r added removed commits <<< "$(_git_net_for_row "$id")"
  if [[ -z "$commits" ]]; then
    log_warn "$id: no commits matched grep '${id}:' — skipping net-lines"
    return 0
  fi

  local net=$((added - removed))
  if (( net <= 0 )); then
    log_pass "$id: structural net-lines = $net (added=$added, removed=$removed)"
  else
    log_fail "$id: structural net-lines = $net > 0 — entropy must not grow on structural rows"
  fi
}

check_actionable_next_steps() {
  # Per templates/snippets/actionable-next-steps.md: if a final-report.md exists,
  # it MUST end with an `## Actionable next steps` section containing paste-ready
  # commands for every deferred / out-of-scope finding. Halts when the section
  # is missing OR when a `/<command>` line lacks a concrete path / --scope=<path>.
  local report="${1:-ai/optimize/final-report.md}"
  [[ ! -f "$report" ]] && return 0

  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$report"; then
    log_fail "final-report missing '## Actionable next steps' section at $report — every deferred finding MUST be a paste-ready command (see templates/snippets/actionable-next-steps.md)"
    return 1
  fi

  # Extract content under the actionable section, then check each /<command> line
  # has a path or --scope= argument.
  local extracted bad=0
  extracted=$(awk '
    /^##[[:space:]]+Actionable next steps/ { in_sec=1; next }
    in_sec && /^##[[:space:]]/ { in_sec=0 }
    in_sec { print }
  ' "$report")

  if ! echo "$extracted" | grep -qE '^[[:space:]]*```'; then
    log_fail "actionable next steps section has no bash fence at $report — commands must be inside ```bash``` so they are paste-ready"
    return 1
  fi

  # Per-command-line check: lines starting with / must have a path token (/ in arg) or --scope=
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*/[a-z-]+ ]] || continue
    # Strip inline comments + leading whitespace, then drop the command word.
    local clean args arg_count
    clean=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    args=$(echo "$clean" | cut -s -d' ' -f2-)
    arg_count=$(echo "$args" | wc -w | tr -d ' ')
    # 0 args (bare command, e.g., `/polish`) → intentional whole-project, accept.
    [[ "$arg_count" == "0" ]] && continue
    # 1 arg (single token: path / identifier / name, e.g., `/add-adr crossModuleServices`) → accept.
    [[ "$arg_count" == "1" ]] && continue
    # 2+ args → reject if it looks like prose (no path / flag / extension markers).
    if echo "$args" | grep -qE '/|=|--|\.[a-zA-Z]+'; then
      continue
    fi
    log_fail "actionable next-step line looks like prose, not a paste-ready command (no path / flag / extension marker): $line"
    bad=$((bad + 1))
  done <<< "$extracted"

  if [[ $bad -gt 0 ]]; then
    return 1
  fi
  log_pass "final report ends with paste-ready actionable next steps"
  return 0
}

check_idiom_citation_functional() {
  local id="$1" cls="$2"

  if is_structural_optimize "$cls"; then
    log_pass "$id: structural class — idiom citation rule N/A"
    return 0
  fi
  if [[ -z "${PHASE_BASE:-}" ]]; then
    log_warn "$id: --phase-base not set; skipping functional idiom citation check"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_warn "$id: git not on PATH; skipping functional idiom citation check"
    return 0
  fi

  local stats added removed commits
  read -r added removed commits <<< "$(_git_net_for_row "$id")"
  if [[ -z "$commits" ]]; then
    log_warn "$id: no commits for net-line heuristic — skipping idiom citation check"
    return 0
  fi
  local net=$((added - removed))
  if (( net <= 0 )); then
    log_pass "$id: functional-style row adds no net lines — idiom citation N/A"
    return 0
  fi

  local ff="$FINDINGS_DIR/${id}.md"
  if [[ ! -f "$ff" ]]; then
    log_warn "$id: findings file missing ($ff) — cannot verify idiom citation for net-positive functional row"
    return 0
  fi

  if grep -qiE 'idiom|_extracted-idioms|gold.standard|Gold standard' "$ff"; then
    log_pass "$id: findings cite idioms / discipline"
  else
    log_fail "$id: functional-style row with net line additions must cite idioms discipline in $ff"
  fi
}

# ── CHECK: performance rows ship a measured baseline + after pair (fix #1) ──
# commands/optimize.md states perf wins MUST ship with baseline + post-fix
# measurement (~46 / ~106 / ~353), but nothing enforced it — a perf "win" could
# ship as prose. Any row with class: performance (or render-waste, which the doc
# also requires a before/after rebuild-count / frame-time for) MUST carry BOTH a
# baseline: token and an after: token in its findings/<id>.md. Mirrors the
# check_per_finding_citations_phase0 style (per-finding evidence presence).
_row_is_perf_class() {
  case "${1:-}" in
    performance|perf|render-waste|render|rebuild|frame-time)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# A measurement token = a baseline/after key, OR a comparison arrow with units
# (e.g. 410ms → 95ms, 4.2s → 280ms, p95 200ms→35ms, 60fps).
_has_measurement_pair() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local has_baseline has_after has_arrow
  has_baseline=$(grep -ciE '(^|[^a-z])baseline[[:space:]]*[:=]' "$file" 2>/dev/null); has_baseline=${has_baseline:-0}
  has_after=$(grep -ciE '(^|[^a-z])after[[:space:]]*[:=]' "$file" 2>/dev/null); has_after=${has_after:-0}
  has_arrow=$(grep -cE '[0-9][0-9.]*[[:space:]]*(ms|s|µs|us|fps|MB|KB|%|rps|qps)[[:space:]]*(->|→|=>)[[:space:]]*[0-9]' "$file" 2>/dev/null); has_arrow=${has_arrow:-0}
  if [[ "$has_baseline" -ge 1 && "$has_after" -ge 1 ]]; then return 0; fi
  if [[ "$has_arrow" -ge 1 ]]; then return 0; fi
  return 1
}

check_perf_measurement_row() {
  local id="$1" cls="$2"

  if ! _row_is_perf_class "$cls"; then
    log_pass "$id: class '$cls' — perf measurement gate N/A"
    return 0
  fi

  local ff="$FINDINGS_DIR/${id}.md"
  if [[ ! -f "$ff" ]]; then
    log_fail "$id: performance row has no findings file ($ff) — a perf win MUST ship a measured baseline + after pair (commands/optimize.md hard rule)"
    return 1
  fi
  if _has_measurement_pair "$ff"; then
    log_pass "$id: performance row carries a measured baseline + after pair"
    return 0
  fi
  log_fail "$id: performance row in $ff lacks a measured baseline + after pair (need 'baseline:' AND 'after:' tokens, or an 'N ms → M ms'-style measured pair) — no perf claim without a measured pair"
  return 1
}

# ── CHECK: perf claims in the final report carry a measured pair (fix #1) ────
# Guards the prose surface too: if final-report.md asserts a perf win
# (perf-win: / p95 / latency / throughput) the report's perf-wins block MUST
# contain a measured pair. Catches perf claims that never became a ledger row.
check_perf_claims_final_report() {
  local report="$1"
  [[ ! -f "$report" ]] && return 0

  local claims
  claims=$(grep -ciE 'perf-win:|p95|p99|latency|throughput|Perf wins' "$report" 2>/dev/null); claims=${claims:-0}
  if [[ "$claims" -lt 1 ]]; then
    log_pass "final report makes no perf claim — perf measurement gate N/A"
    return 0
  fi

  if _has_measurement_pair "$report"; then
    log_pass "final report perf claim carries a measured pair"
    return 0
  fi
  log_fail "final report asserts a perf win (perf-win: / p95 / latency / throughput) at $report without a measured baseline + after pair — reject perf claims lacking a measured pair"
  return 1
}

# ── CHECK: boot-check record present in the summary (fix #3) ─────────────────
# smoke-verify is skippable (--no-boot-check) but was skippable with NO record.
# The run summary (final-report.md) MUST carry a `boot-check: pass` or
# `boot-check: skipped(<reason>)` line. When skipped, the reason MUST also appear
# under the `Not validated:` honesty line (negative space must be surfaced).
check_boot_check_record() {
  local report="$1"
  [[ ! -f "$report" ]] && return 0

  local line
  line=$(grep -iE '^[[:space:]]*boot-check:' "$report" | head -1 || true)
  if [[ -z "$line" ]]; then
    log_fail "final report missing a 'boot-check: pass | skipped(<reason>)' line at $report — smoke-verify result MUST be recorded, not silently skipped"
    return 1
  fi

  if echo "$line" | grep -qiE 'boot-check:[[:space:]]*pass'; then
    log_pass "boot-check recorded as pass"
    return 0
  fi

  if echo "$line" | grep -qiE 'boot-check:[[:space:]]*skipped[[:space:]]*\(.+\)'; then
    # Skipped → reason must also appear under Not validated:
    local reason notvalidated
    reason=$(echo "$line" | sed -E 's/.*skipped[[:space:]]*\((.*)\).*/\1/')
    notvalidated=$(awk '
      /^[[:space:]]*Not validated:/ { print; in_nv=1; next }
      in_nv && /^[[:space:]]*(Risks:|Revert:)/ { in_nv=0 }
      in_nv { print }
    ' "$report")
    if echo "$notvalidated" | grep -qiE 'boot-check|smoke|boot|did not (boot|start)'; then
      log_pass "boot-check skipped($reason) and surfaced under 'Not validated:'"
      return 0
    fi
    log_fail "boot-check skipped($reason) but the skip is not surfaced under 'Not validated:' at $report — a skipped smoke-verify is negative space and MUST be named"
    return 1
  fi

  log_fail "final report 'boot-check:' line is malformed at $report — expected 'pass' or 'skipped(<reason>)': $line"
  return 1
}

# ── CHECK: coverage not dropped (fix #2 — mechanical) ───────────────────────
# Phase 0.5 test-shield captures a coverage baseline; commands/optimize.md states
# 3× that coverage must not drop. Enforce it mechanically: read the baseline
# percentage from ai/optimize/_coverage-baseline and the reported after-coverage
# from the final report's `Coverage:` line, and require after >= baseline.
# If neither surface exists this is best-effort (agent-side) and only warns.
_extract_pct() {
  # First N.M% (or N%) token from stdin.
  grep -oE '[0-9]+(\.[0-9]+)?%' | head -1 | tr -d '%'
}

check_coverage_not_dropped() {
  local report="$1"
  local baseline_pct after_pct

  if [[ -f "$COVERAGE_BASELINE" ]]; then
    baseline_pct=$(_extract_pct < "$COVERAGE_BASELINE")
  fi
  if [[ -f "$report" ]]; then
    after_pct=$(grep -iE '^[[:space:]]*Coverage:' "$report" | tail -1 | _extract_pct)
  fi

  if [[ -z "${baseline_pct:-}" || -z "${after_pct:-}" ]]; then
    log_warn "coverage-not-dropped is best-effort (agent-side): need a baseline at $COVERAGE_BASELINE AND a 'Coverage:' line in $report to enforce mechanically"
    return 0
  fi

  # Compare as integers scaled ×100 to avoid bc dependency.
  local b a
  b=$(awk -v v="$baseline_pct" 'BEGIN { printf "%d", v * 100 }')
  a=$(awk -v v="$after_pct" 'BEGIN { printf "%d", v * 100 }')
  if (( a >= b )); then
    log_pass "coverage not dropped (baseline ${baseline_pct}% → after ${after_pct}%)"
    return 0
  fi
  log_fail "coverage DROPPED (baseline ${baseline_pct}% → after ${after_pct}%) at $report — behaviour-preserving fixes must not reduce coverage"
  return 1
}

validate_optimize_row() {
  local line="$1"
  local id cls status gin gcl verb
  IFS='|' read -r id cls status gin gcl verb <<< "$line"

  [[ -z "$id" ]] && return 0

  log_section "ledger row $id"

  check_gap_count_parity "$id" "$status" "$gin" "$gcl" || true
  check_net_lines_structural "$id" "$cls" || true
  check_idiom_citation_functional "$id" "$cls" || true
  check_perf_measurement_row "$id" "$cls" || true
  check_row_code_smells "$id" || true

  local ffile="$FINDINGS_DIR/${id}.md"
  if [[ -f "$ffile" ]]; then
    check_no_handwaves_file "findings/$id" "$ffile" || true
  fi
}

scan_findings_handwaves() {
  [[ ! -d "$FINDINGS_DIR" ]] && return 0
  local f
  shopt -s nullglob
  for f in "$FINDINGS_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    check_no_handwaves_file "findings/$(basename "$f")" "$f" || true
  done
  shopt -u nullglob
}

# ── Args ──────────────────────────────────────────────────────────────────────
usage() {
  sed -n '2,35p' "$0"
  exit 2
}

# ── --self-test ───────────────────────────────────────────────────────────────
# A GOOD fixture that must pass and a BAD one that must fail, both under $repo_root/tmp/.
#
# Writing this one found the Phase-0 block extractor bug: it demanded the evidence title at
# column 1 while the artifact is written with `## ` headings, so every correctly formatted
# file was reported "empty (heading only)". The fixture below uses the documented format and
# could not be made to pass until that was fixed — see the note at the extractor.
run_optimize_self_test() {
  local td repo_root rc me
  # Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
  # § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
  _ss="${BASH_SOURCE[0]}"
  while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
  repo_root="$(cd -P "$(dirname "$_ss")/.." && pwd)"
  me="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"; unset _ss _sd
  mkdir -p "$repo_root/tmp"
  td=$(mktemp -d "$repo_root/tmp/optimize-selftest.XXXXXX")
  mkdir -p "$td/ai/optimize/findings" "$td/.claude" "$td/src"
  printf 'const q = 1\n' > "$td/src/q.ts"
  printf '# Extracted idioms\n\nOne service per module.\n' > "$td/.claude/_extracted-idioms.md"
  cat > "$td/ai/optimize/_architecture-decisions.md" <<'FIX'
# Architecture decisions

## Phase 0 — Dependency map evidence

`src/q.ts:1` imports nothing; the module graph is a single node.

## Phase 0 — Responsibility map evidence

`src/q.ts:1` owns query construction only.

## Phase 0 — Layer attribution evidence

`src/q.ts:1` sits in the data layer.

## Phase 0 — Detector run evidence

Modules scanned: 1
Ran the duplicate-query detector over `src/`: 1 hit at `src/q.ts:1`.
FIX

  rc=0
  ( cd "$td" && ARCH_ARTIFACT="$td/ai/optimize/_architecture-decisions.md" \
      LEDGER_PATH="$td/ai/optimize/ledger.md" FINDINGS_DIR="$td/ai/optimize/findings" \
      FINAL_REPORT="$td/ai/optimize/final-report.md" bash "$me" >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: the GOOD fixture was rejected (exit $rc)" >&2
    exit 1
  fi

  # A heading with nothing under it. This is the exact state the extractor bug reported for
  # every file, so the BAD case pins that the check still fires when it is genuinely true.
  # Strip EVERY body line under the heading, not just one. The GOOD fixture carries two
  # (`Modules scanned:` and the detector line); removing only the detector left the block with a
  # body, so "heading-only" was no longer what the BAD case was testing.
  grep -vE 'Ran the duplicate-query detector|^Modules scanned:' "$td/ai/optimize/_architecture-decisions.md" > "$td/bad.md"
  mv "$td/bad.md" "$td/ai/optimize/_architecture-decisions.md"
  rc=0
  ( cd "$td" && ARCH_ARTIFACT="$td/ai/optimize/_architecture-decisions.md" \
      LEDGER_PATH="$td/ai/optimize/ledger.md" FINDINGS_DIR="$td/ai/optimize/findings" \
      FINAL_REPORT="$td/ai/optimize/final-report.md" bash "$me" >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -eq 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: a Phase 0 evidence block that is heading-only was accepted" >&2
    exit 1
  fi

  rm -rf "$td"
  echo "validate-optimize-artifacts.sh --self-test OK"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact=*)       ARCH_ARTIFACT="${1#*=}"; shift ;;
    --ledger=*)         LEDGER_PATH="${1#*=}"; shift ;;
    --findings-dir=*)   FINDINGS_DIR="${1#*=}"; shift ;;
    --report=*)         FINAL_REPORT="${1#*=}"; shift ;;
    --coverage-baseline=*) COVERAGE_BASELINE="${1#*=}"; shift ;;
    --self-test) run_optimize_self_test ;;
    --strict)           STRICT=1; shift ;;
    --quiet|-q)         QUIET=1; shift ;;
    --phase-base=*)     PHASE_BASE="${1#*=}"; shift ;;
    -h|--help)          usage ;;
    *)
      if [[ -z "$POSITIONAL_ARTIFACT" && "$1" != -* ]]; then
        POSITIONAL_ARTIFACT="$1"
        shift
        continue
      fi
      echo "Unknown argument: $1" >&2
      usage ;;
  esac
done

[[ -n "$POSITIONAL_ARTIFACT" ]] && ARCH_ARTIFACT="$POSITIONAL_ARTIFACT"

main() {
  log_section "Phase 0 — architecture decisions"
  check_artifact_exists || true
  check_phase_0_blocks_nonempty || true
  check_per_finding_citations_phase0 || true
  check_no_handwaves_file "architecture-decisions" "$ARCH_ARTIFACT" || true
  check_oracle_present || true

  log_section "Ledger rows"
  # The ledger is the ONLY re-detect proof surface (gap-count parity). Any run
  # that FIXED findings (findings/<id>.md present, or a final report claiming
  # closed findings) MUST have a ledger — otherwise parity is unprovable.
  local findings_present=0
  if [[ -d "$FINDINGS_DIR" ]]; then
    shopt -s nullglob
    local _ff
    for _ff in "$FINDINGS_DIR"/*.md; do
      [[ -f "$_ff" ]] && { findings_present=1; break; }
    done
    shopt -u nullglob
  fi

  if [[ ! -f "$LEDGER_PATH" ]]; then
    if [[ $STRICT -eq 1 ]]; then
      log_fail "[strict] ledger required at $LEDGER_PATH"
    elif [[ $findings_present -eq 1 ]]; then
      log_fail "ledger MANDATORY at $LEDGER_PATH — findings were fixed (findings/*.md present) and the ledger is the only re-detect proof surface (gap-count parity)"
    else
      log_warn "ledger not found at $LEDGER_PATH and no findings fixed — skipping per-row checks"
    fi
  else
    # Robustness (fix #6): a non-empty ledger that parses to zero rows is almost
    # always malformed (e.g. indented YAML under the fence) — warn, don't pass.
    local parsed_rows
    parsed_rows=$(discover_optimize_rows)
    if [[ -s "$LEDGER_PATH" ]] && [[ -z "$(echo "$parsed_rows" | sed '/^[[:space:]]*$/d')" ]]; then
      log_warn "ledger at $LEDGER_PATH is non-empty but ZERO rows parsed — check for indented YAML or a missing 'id:' key (re-detect parity cannot be verified)"
    fi
    local row
    while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      validate_optimize_row "$row" || true
    done <<< "$parsed_rows"
  fi

  log_section "Findings directory hand-waves"
  scan_findings_handwaves || true

  log_section "Coverage — not dropped"
  check_coverage_not_dropped "$FINAL_REPORT" || true

  log_section "Boot-check record"
  check_boot_check_record "$FINAL_REPORT" || true

  log_section "Performance claims — measured pair"
  check_perf_claims_final_report "$FINAL_REPORT" || true

  log_section "Final report — actionable next steps"
  check_actionable_next_steps "$FINAL_REPORT" || true

  echo
  echo "── Summary ──"
  echo "  checks passed: $TOTAL_PASS"
  echo "  checks failed: $TOTAL_FAIL"

  if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
    exit 1
  fi
  exit 0
}

main "$@"
