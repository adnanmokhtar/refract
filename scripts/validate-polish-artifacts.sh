#!/usr/bin/env bash
# validate-polish-artifacts.sh — enforces evidence requirements on /polish stack-conditional audits.
#
# Halts the gate if any of the following per-stack audit artifacts is missing required evidence:
#   - frontend-*: ai/polish/_visual-decisions.md (visual baseline + a11y + design-token evidence)
#   - backend-*:  ai/polish/_api-decisions.md (envelope / error / pagination / naming / log / metric / trace evidence)
#   - data-*:     ai/polish/_schema-decisions.md (column / type / index / FK / migration evidence)
#   - mobile-*:   ai/polish/_platform-decisions.md (per-platform UI tree + spec compliance evidence)
#
# Same anti-Trusted-Summary discipline as migration's check_section_0_evidence.

set -euo pipefail

POLISH_DIR="${POLISH_DIR:-ai/polish}"
QUIET="${QUIET:-0}"
PROJECT_KIND="${PROJECT_KIND:-}"

# Auto-detect PROJECT_KIND from .claude/_extracted-codebase.md if not set
if [[ -z "$PROJECT_KIND" && -f .claude/_extracted-codebase.md ]]; then
  PROJECT_KIND=$(grep -m1 -E '^[[:space:]]*PROJECT_KIND:' .claude/_extracted-codebase.md 2>/dev/null | sed 's/.*PROJECT_KIND:[[:space:]]*//' | tr -d '"' | tr -d "'")
fi
PROJECT_KIND="${PROJECT_KIND:-frontend-vue}"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILURES=()

log_pass() { TOTAL_PASS=$((TOTAL_PASS + 1)); [[ $QUIET -eq 0 ]] && echo "  ✓ $1"; }
log_fail() { TOTAL_FAIL=$((TOTAL_FAIL + 1)); FAILURES+=("$1"); echo "  ✗ $1" >&2; }

# Closed UI/UX closure-verb vocabulary from ui-design-sweep.md.
# Frontend polish findings MUST use one of these verbs (or no verb at all).
# Verbs not on this list = either (a) an architectural concern routed elsewhere,
# (b) a code-structure concern (refactoring-sweep), or (c) a 19th-verb invention
# the skill explicitly forbids. Rejecting them here mirrors the way
# validate-refactor-artifacts.sh enforces refactoring-sweep's 10-verb set.
UI_DESIGN_SWEEP_VERBS=(
  consolidate-tokens extract-token unify-component extract-pattern
  normalize-hierarchy apply-type-scale tighten-rhythm simplify-density
  wire-empty-state wire-loading-state wire-error-state
  lift-contrast align-focus-ring unify-iconography normalize-motion
  expand-tap-target unify-cta-placement clarify-affordance normalize-surface
)

is_ui_design_sweep_verb() {
  local v="$1"
  local ok
  for ok in "${UI_DESIGN_SWEEP_VERBS[@]}"; do
    [[ "$v" == "$ok" ]] && return 0
  done
  return 1
}

check_frontend_evidence() {
  local file="$POLISH_DIR/_visual-decisions.md"
  if [[ ! -f "$file" ]]; then
    log_fail "frontend polish artifact MISSING at $file — frontend audit MUST emit visual decisions including baseline screenshots, a11y axe results, design-token comparisons."
    return 1
  fi

  local blocks=("Visual baseline evidence" "a11y audit evidence" "Design-token usage evidence" "Per-surface findings")
  local missing=()
  for block in "${blocks[@]}"; do
    grep -qF "$block" "$file" || missing+=("$block")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fail "frontend polish evidence blocks missing in $file: ${missing[*]}"
    return 1
  fi

  local cited
  cited=$(grep -cE '<[^>]+:[0-9]+>|`[^`]+:[0-9]+`' "$file" 2>/dev/null || echo 0)
  cited=${cited:-0}
  if [[ "$cited" -lt 1 ]]; then
    log_fail "frontend polish has no <path:line> citations in $file"
    return 1
  fi
  log_pass "frontend polish evidence: 4 blocks present, $cited citations"
  return 0
}

check_frontend_verb_vocabulary() {
  # Frontend polish findings under ai/polish/ledger.md (or _visual-decisions.md
  # inline rows) must use the ui-design-sweep closed verb set. Mirrors
  # validate-refactor-artifacts.sh's closure_verb gate.
  local ledger="$POLISH_DIR/ledger.md"
  local visual="$POLISH_DIR/_visual-decisions.md"
  local sources=()
  [[ -f "$ledger" ]] && sources+=("$ledger")
  [[ -f "$visual" ]] && sources+=("$visual")
  [[ ${#sources[@]} -eq 0 ]] && return 0

  local bad=()
  local total=0
  local f line verb
  for f in "${sources[@]}"; do
    while IFS= read -r line; do
      verb=$(echo "$line" | sed -E 's/.*closure_verb:[[:space:]]*//; s/[[:space:]#].*//; s/["'"'"']//g')
      [[ -z "$verb" ]] && continue
      total=$((total + 1))
      is_ui_design_sweep_verb "$verb" || bad+=("$f: $verb")
    done < <(grep -E 'closure_verb:' "$f" 2>/dev/null || true)
  done

  if [[ ${#bad[@]} -gt 0 ]]; then
    log_fail "frontend polish uses verbs outside ui-design-sweep closed vocabulary: ${bad[*]} (allowed: ${UI_DESIGN_SWEEP_VERBS[*]})"
    return 1
  fi
  if [[ $total -gt 0 ]]; then
    log_pass "frontend polish closure_verb vocabulary: $total/$total in ui-design-sweep set"
  fi
  return 0
}

check_backend_evidence() {
  local file="$POLISH_DIR/_api-decisions.md"
  if [[ ! -f "$file" ]]; then
    log_fail "backend polish artifact MISSING at $file — backend audit MUST emit API consistency decisions including OpenAPI snapshot diff, endpoint enumeration, response-shape comparisons."
    return 1
  fi

  local blocks=("Endpoint registry evidence" "OpenAPI coverage evidence" "Response-envelope evidence" "Error-contract evidence" "Per-endpoint findings")
  local missing=()
  for block in "${blocks[@]}"; do
    grep -qF "$block" "$file" || missing+=("$block")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fail "backend polish evidence blocks missing in $file: ${missing[*]}"
    return 1
  fi

  local endpoints
  endpoints=$(grep -cE '^[[:space:]]*(GET|POST|PUT|PATCH|DELETE)[[:space:]]+/' "$file" 2>/dev/null || echo 0)
  endpoints=${endpoints:-0}
  if [[ "$endpoints" -lt 1 ]]; then
    log_fail "backend polish lists zero endpoints in $file — Endpoint registry must enumerate every {method, path}."
    return 1
  fi
  log_pass "backend polish evidence: blocks present, $endpoints endpoints enumerated"
  return 0
}

check_data_evidence() {
  local file="$POLISH_DIR/_schema-decisions.md"
  if [[ ! -f "$file" ]]; then
    log_fail "data polish artifact MISSING at $file — data audit MUST emit schema consistency decisions including introspection snapshot, column-by-column comparison, migration history scan."
    return 1
  fi

  local blocks=("Schema introspection evidence" "Migration history evidence" "Column drift evidence" "Per-table findings")
  local missing=()
  for block in "${blocks[@]}"; do
    grep -qF "$block" "$file" || missing+=("$block")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fail "data polish evidence blocks missing in $file: ${missing[*]}"
    return 1
  fi

  local tables
  tables=$(grep -cE '^[[:space:]]*Table:[[:space:]]+\w+' "$file" 2>/dev/null || echo 0)
  tables=${tables:-0}
  if [[ "$tables" -lt 1 ]]; then
    log_fail "data polish lists zero tables in $file — Schema introspection must enumerate every table."
    return 1
  fi
  log_pass "data polish evidence: blocks present, $tables tables introspected"
  return 0
}

check_mobile_evidence() {
  local file="$POLISH_DIR/_platform-decisions.md"
  if [[ ! -f "$file" ]]; then
    log_fail "mobile polish artifact MISSING at $file"
    return 1
  fi

  local blocks=("Per-platform UI tree evidence" "iOS HIG conformance evidence" "Material 3 conformance evidence" "Per-screen findings")
  local missing=()
  for block in "${blocks[@]}"; do
    grep -qF "$block" "$file" || missing+=("$block")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fail "mobile polish evidence blocks missing in $file: ${missing[*]}"
    return 1
  fi

  log_pass "mobile polish evidence: blocks present"
  return 0
}

check_no_handwaves() {
  # Pick the right artifact based on PROJECT_KIND
  local file
  case "$PROJECT_KIND" in
    frontend-*) file="$POLISH_DIR/_visual-decisions.md" ;;
    backend-*)  file="$POLISH_DIR/_api-decisions.md" ;;
    data-*)     file="$POLISH_DIR/_schema-decisions.md" ;;
    mobile-*)   file="$POLISH_DIR/_platform-decisions.md" ;;
    *)          return 0 ;;
  esac
  [[ ! -f "$file" ]] && return 0

  local scrubbed handwaves
  scrubbed=$(mktemp -t polish-scrub.XXXXXX)
  awk '
    BEGIN { in_fence=0 }
    /^```/ { in_fence = 1 - in_fence; next }
    in_fence { next }
    { gsub(/`[^`]*`/, ""); print }
  ' "$file" > "$scrubbed"
  handwaves=$(grep -cE '\.\.\.[[:space:]]*$|, etc\.| etc\.\)|\b[0-9]+\+[[:space:]]+(surfaces?|endpoints?|tables?|screens?|fields?|tabs?)\b|\band so on\b|\bdeferred\b|\bby inspection\b' "$scrubbed" 2>/dev/null || echo 0)
  rm -f "$scrubbed"
  handwaves=${handwaves:-0}

  if [[ "$handwaves" -gt 0 ]]; then
    log_fail "polish has $handwaves hand-wave(s) in $file — enumerate explicitly per anti-Trusted-Summary discipline."
    return 1
  fi
  log_pass "no hand-wave language in polish artifact"
  return 0
}

main() {
  [[ $QUIET -eq 0 ]] && echo "validate-polish-artifacts.sh"
  [[ $QUIET -eq 0 ]] && echo "  PROJECT_KIND: $PROJECT_KIND"
  [[ $QUIET -eq 0 ]] && echo "  POLISH_DIR:   $POLISH_DIR"

  case "$PROJECT_KIND" in
    frontend-*) check_frontend_evidence || true; check_frontend_verb_vocabulary || true ;;
    backend-*)  check_backend_evidence  || true ;;
    data-*)     check_data_evidence     || true ;;
    mobile-*)   check_mobile_evidence || check_frontend_evidence || true; check_frontend_verb_vocabulary || true ;;
    *)
      log_fail "unknown PROJECT_KIND: $PROJECT_KIND — set in .claude/_extracted-codebase.md § Gold standards"
      ;;
  esac
  check_no_handwaves || true

  echo
  echo "── Summary ──"
  echo "  checks passed: $TOTAL_PASS"
  echo "  checks failed: $TOTAL_FAIL"

  if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo
    echo "Failures:"
    for f in "${FAILURES[@]}"; do echo "  - $f"; done
    exit 1
  fi
  exit 0
}

main "$@"
