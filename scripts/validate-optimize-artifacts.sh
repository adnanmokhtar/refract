#!/usr/bin/env bash
# validate-optimize-artifacts.sh — enforces /optimize Phase 0 + ledger-row gates.
#
# Phase 0 (always): ai/optimize/_architecture-decisions.md
#   — 4 evidence blocks (non-empty), detector scans, per-finding citations,
#     hand-wave grep, idioms oracle presence (+ strict: oracle referenced).
#
# Per ledger row (when ai/optimize/ledger.md exists): fenced YAML rows with
#   id: <token> (same shape as migrate-parallel / optimize-parallel).
#   — gaps_in == gaps_closed for terminal statuses
#   — structural classes: net-lines ≤ 0 (when git + --phase-base available)
#   — non-structural classes with net line additions: idiom citation in findings file
#
# Usage:
#   validate-optimize-artifacts.sh [--artifact=PATH] [--ledger=PATH] [--findings-dir=PATH]
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
ORACLE_IDIOMS=".claude/_extracted-idioms.md"

STRICT=0
QUIET=0
PHASE_BASE=""
POSITIONAL_ARTIFACT=""

TOTAL_PASS=0
TOTAL_FAIL=0
FAILURES=()

log_pass() {
  TOTAL_PASS=$((TOTAL_PASS + 1))
  [[ $QUIET -eq 0 ]] && echo "  ✓ $1"
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
  [[ $QUIET -eq 0 ]] && echo && echo "── $1 ──"
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
    body=$(awk -v T="$title" '
      BEGIN { grab = 0 }
      index($0, T) == 1 || $0 == T { grab = 1; next }
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
  detectors_scanned=$(grep -cE '^[[:space:]]*Modules scanned:[[:space:]]*[1-9][0-9]*' "$file" 2>/dev/null || echo 0)
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

  breaches=$(grep -cve '^[[:space:]]*$' "$tmp" 2>/dev/null || echo 0)
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
  if [[ ! -f "$ORACLE_IDIOMS" ]]; then
    log_fail "idioms oracle MISSING at $ORACLE_IDIOMS — run /setup-project --refine"
    return 1
  fi
  log_pass "idioms oracle present at $ORACLE_IDIOMS"

  if [[ $STRICT -eq 1 ]]; then
    if ! grep -qE '_extracted-idioms|\.claude/_extracted-idioms' "$ARCH_ARTIFACT" 2>/dev/null; then
      log_fail "[strict] Phase 0 doc must reference _extracted-idioms.md (discipline oracle)"
      return 1
    fi
    log_pass "[strict] Phase 0 references idioms oracle"
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

validate_optimize_row() {
  local line="$1"
  local id cls status gin gcl verb
  IFS='|' read -r id cls status gin gcl verb <<< "$line"

  [[ -z "$id" ]] && return 0

  log_section "ledger row $id"

  check_gap_count_parity "$id" "$status" "$gin" "$gcl" || true
  check_net_lines_structural "$id" "$cls" || true
  check_idiom_citation_functional "$id" "$cls" || true

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
  sed -n '2,22p' "$0"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact=*)       ARCH_ARTIFACT="${1#*=}"; shift ;;
    --ledger=*)         LEDGER_PATH="${1#*=}"; shift ;;
    --findings-dir=*)   FINDINGS_DIR="${1#*=}"; shift ;;
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

  log_section "Ledger rows (optional)"
  if [[ ! -f "$LEDGER_PATH" ]]; then
    if [[ $STRICT -eq 1 ]]; then
      log_fail "[strict] ledger required at $LEDGER_PATH"
    else
      log_warn "ledger not found at $LEDGER_PATH — skipping per-row checks"
    fi
  else
    local row
    while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      validate_optimize_row "$row" || true
    done < <(discover_optimize_rows)
  fi

  log_section "Findings directory hand-waves"
  scan_findings_handwaves || true

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
