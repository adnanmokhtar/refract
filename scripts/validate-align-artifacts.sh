#!/usr/bin/env bash
# validate-align-artifacts.sh — universal align-discipline validator.
#
# Tool-agnostic. Runs from any AI tool's hook system, CI pipeline, or pre-commit.
# Validates the artifact set required by `align-discipline.md` for every finding
# in a phase (or for one finding with --finding=, or all with --all).
#
# Checks (per align-discipline.md § "Per-finding audit — 11 hard halts"
#         + § "Procedure: phase exit gate"):
#   1.  Evidence resolves        — every row's <path:line> resolves to a real file
#   2.  No hand-waves            — no "etc." / "..." / "several" / "multiple" / "N+"
#   3.  Closure verb in vocab    — verb in 21-verb closed vocabulary
#   4.  No new symbols           — git diff shows no new exports OR all named in idioms
#   5.  Net-lines non-positive   — structural rows: lines-removed ≥ lines-added
#   6.  Scope boundary           — diff touched files ⊂ row.scope
#   7.  Security tier minimum    — security rows ≥ standard tier; critical → heavy
#
# Remaining 7 checks (test-coverage, frontend-regression, idiom-citation,
# security-assertion, perf-baseline, oracle-unmodified, ledger-completeness)
# are agent-side enforcement until v2 ships them as script checks.
#
# Usage:
#   validate-align-artifacts.sh --phase=<N>             # validate every row in phase N
#   validate-align-artifacts.sh --finding=<id>          # validate one finding
#   validate-align-artifacts.sh --all                   # validate every row in ledger
#   validate-align-artifacts.sh --strict                # treat warnings as errors
#   validate-align-artifacts.sh --quiet                 # only print failures
#   validate-align-artifacts.sh --check=<name>          # run only the named check
#
# Exit codes:
#   0  — all checks pass
#   1  — at least one check failed
#   2  — usage error / unable to read ledger
#   3  — environment error (paths missing, tools missing)
#   4  — data-integrity error (duplicate IDs, malformed ledger)

set -euo pipefail
export LC_ALL=C

# ── Defaults (overridable via ai/align/_anchors.md) ─────────────────────────
LEDGER_PATH="ai/align/ledger.md"
PLAN_PATH="ai/align/plan.md"
HALTS_DIR="ai/align/halts"
IMPACT_DIR="ai/align/impact"
ANCHORS_FILE="ai/align/_anchors.md"
ORACLE_FILES=("_extracted-idioms.md" "ai/conventions.md" "ai/architecture.md")

PROJECT_KIND="frontend-vue"        # set per project via _anchors.md
EXTENSIONS_DEFAULT="ts tsx js jsx vue py go rb php java kt swift"

PHASE=""
FINDING=""
SCAN_ALL=0
STRICT=0
QUIET=0
CHECK_FILTER=""
PHASE_BASE=""

# ── Args ────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase=*)       PHASE="${1#--phase=}"; shift ;;
    --finding=*)     FINDING="${1#--finding=}"; shift ;;
    --all)           SCAN_ALL=1; shift ;;
    --strict)        STRICT=1; shift ;;
    --quiet)         QUIET=1; shift ;;
    --check=*)       CHECK_FILTER="${1#--check=}"; shift ;;
    --phase-base=*)  PHASE_BASE="${1#--phase-base=}"; shift ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--phase=N | --finding=ID | --all] [--strict] [--quiet] [--check=NAME]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PHASE" && -z "$FINDING" && "$SCAN_ALL" -eq 0 ]]; then
  echo "Usage: $0 [--phase=N | --finding=ID | --all]" >&2
  exit 2
fi

if [[ ! -f "$LEDGER_PATH" ]]; then
  echo "FATAL: ledger not found at $LEDGER_PATH" >&2
  echo "Run /align-scan first, OR you're in the wrong directory." >&2
  exit 3
fi

# ── Output helpers ──────────────────────────────────────────────────────────
TOTAL_CHECKED=0
TOTAL_PASS=0
TOTAL_FAIL=0
declare -a FAILURES

log_pass() {
  TOTAL_PASS=$((TOTAL_PASS + 1))
  if [[ $QUIET -eq 0 ]]; then
    echo "  ✓ $1"
  fi
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
  if [[ $QUIET -eq 0 ]]; then
    echo
    echo "── $1 ──"
  fi
}

# ── Project anchors ─────────────────────────────────────────────────────────
load_project_anchors() {
  if [[ ! -f "$ANCHORS_FILE" ]]; then
    return 0
  fi
  local fm
  fm=$(awk '/^---$/{c++; next} c==1' "$ANCHORS_FILE")
  local pk
  pk=$(echo "$fm" | grep -m1 '^project_kind:' | sed 's/^project_kind:[[:space:]]*//' | tr -d '"' | tr -d "'")
  [[ -n "$pk" ]] && PROJECT_KIND="$pk"
}

# ── Parse ledger to discover findings ──────────────────────────────────────
# Ledger format (per align-ledger.md): yaml-fenced or yaml-block format.
# Each row has: id, class, scope (list), evidence (list), closure_verb, tier,
# status, phase (optional), idiom_cited (optional), severity (security only).
#
# Output: "<id>|<class>|<phase>|<status>|<tier>|<closure_verb>|<severity>"
discover_findings() {
  awk '
    /^- id: A[0-9]+[a-z]?$/ {
      if (id != "") print id "|" class "|" phase "|" status "|" tier "|" verb "|" severity
      id = $3; class=""; phase=""; status=""; tier=""; verb=""; severity=""
      in_block = 1
      next
    }
    /^[[:space:]]*$/ && in_block == 1 {
      # Blank line ends a yaml block in this format
      if (id != "") print id "|" class "|" phase "|" status "|" tier "|" verb "|" severity
      id=""; class=""; phase=""; status=""; tier=""; verb=""; severity=""
      in_block = 0
      next
    }
    in_block && /^[[:space:]]+class:/        { class=$2; next }
    in_block && /^[[:space:]]+phase:/        { phase=$2; next }
    in_block && /^[[:space:]]+status:/       { status=$2; next }
    in_block && /^[[:space:]]+tier:/         { tier=$2; next }
    in_block && /^[[:space:]]+closure_verb:/ { verb=$2; next }
    in_block && /^[[:space:]]+severity:/     { severity=$2; next }
    END {
      if (id != "") print id "|" class "|" phase "|" status "|" tier "|" verb "|" severity
    }
  ' "$LEDGER_PATH"
}

filter_findings() {
  if [[ -n "$FINDING" ]]; then
    grep "^${FINDING}|" || true
  elif [[ -n "$PHASE" ]]; then
    awk -F'|' -v p="$PHASE" '$3 == p' || true
  else
    cat
  fi
}

# ── Closure-verb vocabulary (21 verbs) ──────────────────────────────────────
STRUCTURAL_VERBS="remove inline dedupe rename-comment-out replace-with-shared"
FUNCTIONAL_VERBS="add-gate parameterize escape move-to-secrets add-validator parallelize batch project-columns add-index cache-with-explicit-ttl extract-to-shared split-extract inline-magic-to-named-const inline-filter-to-query bump-dep rename"
ALL_VERBS="$STRUCTURAL_VERBS $FUNCTIONAL_VERBS"

is_structural_class() {
  local cls="$1"
  case "$cls" in
    dead-code|duplicated-logic|reinvented-wrapper|silent-catch|over-abstraction|drift)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# ── CHECK 1: evidence resolves ───────────────────────────────────────────────
# Read all `evidence:` <path:line> entries for the row from the ledger;
# verify each path exists and the line number is within bounds.
check_evidence_resolves() {
  local id="$1"
  local row_block
  row_block=$(awk -v id="$id" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block { print }
    /^[[:space:]]*$/ && in_block { exit }
  ' "$LEDGER_PATH")

  local in_evidence=0
  local missing=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]+evidence: ]]; then
      in_evidence=1
      # Inline list?  evidence: [path:line, path:line]
      local inline
      inline=$(echo "$line" | sed 's/^[[:space:]]*evidence:[[:space:]]*//; s/^\[//; s/\]$//')
      if [[ -n "$inline" && "$inline" != "[]" ]]; then
        IFS=',' read -ra entries <<< "$inline"
        for entry in "${entries[@]}"; do
          entry=$(echo "$entry" | xargs)  # trim
          [[ -z "$entry" ]] && continue
          if ! evidence_resolves "$entry"; then
            log_fail "$id: evidence does not resolve: $entry"
            missing=$((missing + 1))
          fi
        done
        in_evidence=0
        continue
      fi
      continue
    fi

    if [[ $in_evidence -eq 1 ]]; then
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        local entry
        entry=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*#.*$//' | tr -d '"' | tr -d "'")
        [[ -z "$entry" ]] && continue
        if ! evidence_resolves "$entry"; then
          log_fail "$id: evidence does not resolve: $entry"
          missing=$((missing + 1))
        fi
      else
        in_evidence=0
      fi
    fi
  done <<< "$row_block"

  if [[ $missing -eq 0 ]]; then
    log_pass "$id: evidence resolves"
  fi
}

evidence_resolves() {
  local entry="$1"
  if [[ ! "$entry" =~ ^([^:]+):([0-9]+)$ ]]; then
    return 1
  fi
  local path="${BASH_REMATCH[1]}"
  local lineno="${BASH_REMATCH[2]}"
  [[ ! -f "$path" ]] && return 1
  local file_lines
  file_lines=$(wc -l < "$path")
  (( lineno <= file_lines + 1 )) || return 1
  return 0
}

# ── CHECK 2: no hand-waves in any field ─────────────────────────────────────
check_scan_report_evidence() {
  # Equivalent of migration's check_section_0_evidence — for /align, verify the scan-report.md
  # shows machine-verifiable evidence per detector class. Without per-detector run evidence,
  # the scan is a Trusted Summary and the gate refuses it.
  local scan_report="${ALIGN_DIR:-ai/align}/scan-report.md"
  if [[ ! -f "$scan_report" ]]; then
    [[ $QUIET -eq 0 ]] && echo "  ▸ scan-report.md not present at $scan_report (skipping evidence check)"
    return 0
  fi

  # Required: per-detector run evidence — each of the 11 universal classes must show
  # "Detector: <class> | Modules scanned: N | Fingerprint matches: M" or equivalent
  local detector_blocks
  detector_blocks=$(grep -cE 'Detector:[[:space:]]+(dead-code|duplicated-logic|reinvented-wrapper|silent-catch|over-abstraction|drift|solid-violation|clean-code|performance|security|stack-specific)' "$scan_report" 2>/dev/null || echo 0)
  detector_blocks=${detector_blocks:-0}
  if [[ "$detector_blocks" -lt 1 ]]; then
    log_fail "scan-report.md has zero per-detector evidence blocks. Each of the 11 universal classes (dead-code, duplicated-logic, reinvented-wrapper, silent-catch, over-abstraction, drift, solid-violation, clean-code, performance, security, stack-specific) MUST emit \"Detector: <class>\" + scan counts. Without this evidence the scan is Trusted-Summary."
    return 1
  fi

  # Required: oracle citation — _extracted-idioms.md or codebase-profile.md must be cited
  local oracle_cited
  oracle_cited=$(grep -cE '_extracted-idioms\.md|codebase-profile\.md|ai/conventions\.md|ai/architecture\.md' "$scan_report" 2>/dev/null || echo 0)
  oracle_cited=${oracle_cited:-0}
  if [[ "$oracle_cited" -lt 1 ]]; then
    log_fail "scan-report.md doesn't cite the convention oracle. The detector MUST consult _extracted-idioms.md (or codebase-profile.md / ai/conventions.md / ai/architecture.md) and reference it in the report."
    return 1
  fi

  log_pass "scan-report evidence: $detector_blocks detector blocks, $oracle_cited oracle citations"
  return 0
}

check_no_handwaves() {
  local id="$1"
  local row_block
  row_block=$(awk -v id="$id" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block { print }
    /^[[:space:]]*$/ && in_block { exit }
  ' "$LEDGER_PATH")

  local hits
  hits=$(echo "$row_block" | grep -iE '\betc\.|\.\.\.|\bseveral\b|\bmultiple (call sites|endpoints|places)\b|\bN\+ (duplicates|items)\b|\band so on\b|\band similar\b' || true)
  if [[ -n "$hits" ]]; then
    log_fail "$id: hand-wave token detected — refactor row to enumerate instances explicitly"
    if [[ $QUIET -eq 0 ]]; then
      echo "$hits" | head -3 | sed 's/^/        /'
    fi
  else
    log_pass "$id: no hand-waves"
  fi
}

# ── CHECK 3: closure verb in vocabulary ─────────────────────────────────────
check_closure_verb_in_vocab() {
  local id="$1" verb="$2"
  if [[ -z "$verb" ]]; then
    log_fail "$id: closure_verb missing"
    return
  fi
  if [[ " $ALL_VERBS " == *" $verb "* ]]; then
    log_pass "$id: closure_verb '$verb' is in vocabulary"
  else
    log_fail "$id: closure_verb '$verb' NOT in 21-verb vocabulary — re-classify or route to /refactor"
  fi
}

# ── CHECK 4: no new symbols (with idioms-named exemption) ───────────────────
# Diff <phase-base>..HEAD for added exports. Each new export must be named in
# _extracted-idioms.md, otherwise it's a Reinvented Wrapper.
check_no_new_symbols() {
  local id="$1"
  if [[ -z "$PHASE_BASE" ]]; then
    log_warn "$id: --phase-base not provided; skipping no-new-symbols check"
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_warn "$id: git not on PATH; skipping no-new-symbols check"
    return
  fi

  local diff_added
  diff_added=$(git diff --diff-filter=A "$PHASE_BASE..HEAD" 2>/dev/null \
    | grep -E '^\+(export\s+(default\s+)?(function|class|const|let|interface|type)|export\s+\{)' \
    | grep -v '^+++' \
    | head -20 || true)

  if [[ -z "$diff_added" ]]; then
    log_pass "$id: no new exports"
    return
  fi

  if [[ ! -f "_extracted-idioms.md" ]]; then
    log_warn "$id: _extracted-idioms.md not found; cannot verify exemption"
    return
  fi

  local violations=0
  while IFS= read -r exline; do
    [[ -z "$exline" ]] && continue
    local symbol
    symbol=$(echo "$exline" | grep -oE '(function|class|const|let|interface|type)\s+[A-Za-z_][A-Za-z0-9_]*' | awk '{print $2}' | head -1)
    [[ -z "$symbol" ]] && continue
    if ! grep -q "$symbol" "_extracted-idioms.md" 2>/dev/null; then
      log_fail "$id: new export '$symbol' not named in _extracted-idioms.md (Reinvented Wrapper anti-pattern)"
      violations=$((violations + 1))
    fi
  done <<< "$diff_added"

  if [[ $violations -eq 0 ]]; then
    log_pass "$id: new exports all named in idioms inventory"
  fi
}

# ── CHECK 5: net-lines non-positive on structural rows ──────────────────────
check_net_lines_structural() {
  local id="$1" cls="$2"
  if ! is_structural_class "$cls"; then
    log_pass "$id: functional class '$cls' — net-lines rule N/A (idiom citation applies instead)"
    return
  fi
  if [[ -z "$PHASE_BASE" ]]; then
    log_warn "$id: --phase-base not provided; skipping net-lines check"
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_warn "$id: git not on PATH; skipping net-lines check"
    return
  fi

  # Find commit(s) for this row by message convention: align/<phase>/<id>:
  local row_commits
  row_commits=$(git log --grep="${id}:" --format='%H' "$PHASE_BASE..HEAD" 2>/dev/null || true)
  if [[ -z "$row_commits" ]]; then
    log_warn "$id: no commit found via 'align/<phase>/$id:' message; skipping net-lines"
    return
  fi

  local added=0 removed=0
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    local stat
    stat=$(git show --shortstat "$sha" 2>/dev/null | tail -1 || true)
    local a r
    a=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    r=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
    added=$((added + ${a:-0}))
    removed=$((removed + ${r:-0}))
  done <<< "$row_commits"

  local net=$((added - removed))
  if (( net <= 0 )); then
    log_pass "$id: structural net-lines = $net (added=$added, removed=$removed)"
  else
    log_fail "$id: structural net-lines = $net > 0 (added=$added, removed=$removed) — closure verb applied wrong"
  fi
}

# ── CHECK 6: scope boundary ─────────────────────────────────────────────────
check_scope_boundary() {
  local id="$1"
  if ! command -v git >/dev/null 2>&1; then
    log_warn "$id: git not on PATH; skipping scope-boundary check"
    return
  fi

  local row_commit
  row_commit=$(git log --grep="${id}:" --format='%H' --max-count=1 2>/dev/null || true)
  if [[ -z "$row_commit" ]]; then
    log_warn "$id: no commit for this row; skipping scope-boundary check"
    return
  fi

  local scope_files
  scope_files=$(awk -v id="$id" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block && /^[[:space:]]+scope:/ {
      in_scope = 1
      sub(/^[[:space:]]+scope:[[:space:]]*/, "")
      sub(/^\[/, ""); sub(/\]$/, "")
      gsub(/, /, "\n")
      gsub(/,/, "\n")
      print
      next
    }
    in_scope && /^[[:space:]]+- / { sub(/^[[:space:]]+-[[:space:]]*/, ""); print; next }
    in_scope && !/^[[:space:]]+/ { in_scope = 0 }
    /^[[:space:]]*$/ && in_block { exit }
  ' "$LEDGER_PATH" | tr -d '"' | tr -d "'" | sort -u)

  if [[ -z "$scope_files" ]]; then
    log_warn "$id: scope field empty; skipping boundary check"
    return
  fi

  local touched
  touched=$(git show --name-only --format='' "$row_commit" 2>/dev/null | sort -u)

  local violations=()
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local in_scope=0
    while IFS= read -r scope_path; do
      [[ -z "$scope_path" ]] && continue
      # Match: file is exactly scope_path OR file is inside scope_path/
      if [[ "$file" == "$scope_path" || "$file" == "$scope_path"/* ]]; then
        in_scope=1
        break
      fi
    done <<< "$scope_files"
    if [[ $in_scope -eq 0 ]]; then
      violations+=("$file")
    fi
  done <<< "$touched"

  if [[ ${#violations[@]} -eq 0 ]]; then
    log_pass "$id: all touched files within scope"
  else
    log_fail "$id: scope creep — touched files outside scope:"
    for v in "${violations[@]:0:5}"; do
      echo "        $v" >&2
    done
  fi
}

# ── CHECK 7: security tier minimum ───────────────────────────────────────────
check_security_tier_minimum() {
  local id="$1" cls="$2" tier="$3" severity="$4"
  if [[ "$cls" != "security" ]]; then
    return  # not applicable
  fi
  case "$tier" in
    trivial)
      log_fail "$id: security finding at trivial tier — security must be ≥ standard"
      return
      ;;
    standard)
      case "$severity" in
        critical)
          log_fail "$id: critical-severity security at standard tier — must be heavy"
          return
          ;;
      esac
      ;;
    heavy)
      ;;
    *)
      log_warn "$id: tier '$tier' not recognized for security row"
      return
      ;;
  esac
  log_pass "$id: security tier '$tier' valid for severity '$severity'"
}

# ── Per-finding orchestrator ────────────────────────────────────────────────
validate_finding() {
  local id="$1" cls="$2" phase="$3" status="$4" tier="$5" verb="$6" severity="$7"
  TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
  log_section "$id ($cls / phase=$phase / status=$status / tier=$tier)"

  # Skip rows in non-terminal states (not yet relevant to the gate)
  case "$status" in
    detected|in-progress)
      log_warn "$id: status=$status — not yet relevant to gate; skipping checks"
      return
      ;;
    archived-pre-existing|archived-deprecated|parked)
      log_pass "$id: status=$status — terminal non-fix state; no checks needed"
      return
      ;;
  esac

  # Run the 7 checks, optionally filtered by --check
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "evidence" ]]; then
    check_evidence_resolves "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "handwaves" ]]; then
    check_no_handwaves "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "verb" ]]; then
    check_closure_verb_in_vocab "$id" "$verb"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "no-new-symbols" ]]; then
    check_no_new_symbols "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "net-lines" ]]; then
    check_net_lines_structural "$id" "$cls"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "scope" ]]; then
    check_scope_boundary "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "security-tier" ]]; then
    check_security_tier_minimum "$id" "$cls" "$tier" "$severity"
  fi
}

check_actionable_next_steps() {
  # Per templates/snippets/actionable-next-steps.md: if a final-report.md exists,
  # it MUST end with an `## Actionable next steps` section containing paste-ready
  # commands for every deferred / out-of-scope finding.
  local report="${1:-ai/align/final-report.md}"
  [[ ! -f "$report" ]] && return 0

  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$report"; then
    log_fail "final-report missing '## Actionable next steps' section at $report — every deferred finding MUST be a paste-ready command (see templates/snippets/actionable-next-steps.md)"
    return 1
  fi

  local extracted bad=0
  extracted=$(awk '
    /^##[[:space:]]+Actionable next steps/ { in_sec=1; next }
    in_sec && /^##[[:space:]]/ { in_sec=0 }
    in_sec { print }
  ' "$report")

  if ! echo "$extracted" | grep -qE '^[[:space:]]*```'; then
    log_fail "actionable next steps section has no bash fence at $report — commands must be inside \`\`\`bash\`\`\` so they are paste-ready"
    return 1
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*/[a-z-]+ ]] || continue
    local clean args arg_count
    clean=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    args=$(echo "$clean" | cut -s -d' ' -f2-)
    arg_count=$(echo "$args" | wc -w | tr -d ' ')
    [[ "$arg_count" == "0" ]] && continue
    [[ "$arg_count" == "1" ]] && continue
    if echo "$args" | grep -qE '/|=|--|\.[a-zA-Z]+'; then
      continue
    fi
    log_fail "actionable next-step line looks like prose, not a paste-ready command (no path / flag / extension marker): $line"
    bad=$((bad + 1))
  done <<< "$extracted"

  [[ $bad -gt 0 ]] && return 1
  log_pass "final report ends with paste-ready actionable next steps"
  return 0
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  load_project_anchors
  if [[ $QUIET -eq 0 ]]; then
    echo "validate-align-artifacts.sh"
    echo "  ledger:  $LEDGER_PATH"
    echo "  project: $PROJECT_KIND"
    [[ -n "$PHASE" ]] && echo "  scope:   phase $PHASE"
    [[ -n "$FINDING" ]] && echo "  scope:   finding $FINDING"
    [[ $SCAN_ALL -eq 1 ]] && echo "  scope:   all findings"
    [[ -n "$CHECK_FILTER" ]] && echo "  check:   $CHECK_FILTER"
  fi

  # Pre-check: duplicate IDs
  local dupes
  dupes=$(grep -oE '^- id: A[0-9]+[a-z]?$' "$LEDGER_PATH" 2>/dev/null | sort | uniq -d)
  if [[ -n "$dupes" ]]; then
    echo "FATAL: duplicate ledger IDs:" >&2
    echo "$dupes" | sed 's/^/  /' >&2
    exit 4
  fi

  # Run the run-level evidence check ONCE before per-finding validation
  # This catches Trusted-Summary scans that produce findings without per-detector evidence
  log_section "Run-level evidence check (scan-report.md)"
  check_scan_report_evidence

  local findings
  findings=$(discover_findings | filter_findings)
  if [[ -z "$findings" ]]; then
    echo "No findings matched the scope. Check ledger contents." >&2
    exit 2
  fi

  while IFS='|' read -r id cls phase status tier verb severity; do
    [[ -n "$id" ]] || continue
    validate_finding "$id" "$cls" "$phase" "$status" "$tier" "$verb" "$severity"
  done <<< "$findings"

  check_actionable_next_steps "ai/align/final-report.md" || true

  echo
  echo "── Summary ──"
  echo "  findings checked: $TOTAL_CHECKED"
  echo "  checks passed:    $TOTAL_PASS"
  echo "  checks failed:    $TOTAL_FAIL"

  if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
    exit 1
  fi

  if [[ $QUIET -eq 0 ]]; then
    echo
    echo "Note: 7 checks remain agent-side enforcement (test-coverage, frontend-regression,"
    echo "      idiom-citation, security-assertion, perf-baseline, oracle-unmodified,"
    echo "      ledger-completeness). Implement in v2 when patterns stabilize."
  fi
  exit 0
}

main "$@"
