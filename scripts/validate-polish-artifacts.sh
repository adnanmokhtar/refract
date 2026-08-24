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

# ── --self-test ───────────────────────────────────────────────────────────────
# A GOOD fixture that must pass and a BAD one that must fail. Both are written under
# $repo_root/tmp/ and removed either way.
#
# This validator shipped without one for as long as it has existed, and six of the seven
# validate-*-artifacts.sh scripts were in the same state — the only tested one was
# validate-refactor. Writing these found three real defects in the untested five, each of
# which rejected a CORRECTLY WRITTEN artifact. See the notes at those sites.
run_polish_self_test() {
  local td repo_root rc me
  # Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
  # § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
  _ss="${BASH_SOURCE[0]}"
  while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
  repo_root="$(cd -P "$(dirname "$_ss")/.." && pwd)"
  me="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"; unset _ss _sd
  mkdir -p "$repo_root/tmp"
  td=$(mktemp -d "$repo_root/tmp/polish-selftest.XXXXXX")
  mkdir -p "$td/ai/polish" "$td/src"
  printf 'export const Button = 1\n' > "$td/src/Button.vue"
  cat > "$td/ai/polish/_visual-decisions.md" <<'FIX'
# Visual decisions

## Visual baseline evidence

Captured 1440x900 and 390x844 before/after. Baseline: `docs/polish/baseline-home.png`.

## a11y audit evidence

axe-core run, 0 critical. Contrast measured 8.9:1 at `src/Button.vue:1`.

## Design-token usage evidence

`src/Button.vue:1` uses the token scale; no raw hex remains.

## Per-surface findings

- `src/Button.vue:1` — focus ring restored.

closure_verb: align-focus-ring
FIX

  rc=0
  ( cd "$td" && POLISH_DIR="$td/ai/polish" PROJECT_KIND=frontend-vue bash "$me" >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: the GOOD fixture was rejected (exit $rc)" >&2
    exit 1
  fi

  # A verb outside the ui-design-sweep closed vocabulary. `parallelize` is a real verb in
  # the ALIGN set, which is the mistake worth catching: plausible, and from a sibling list.
  sed 's/align-focus-ring/parallelize/' "$td/ai/polish/_visual-decisions.md" > "$td/bad.md"
  mv "$td/bad.md" "$td/ai/polish/_visual-decisions.md"
  rc=0
  ( cd "$td" && POLISH_DIR="$td/ai/polish" PROJECT_KIND=frontend-vue bash "$me" >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -eq 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: a closure_verb outside the closed vocabulary was accepted" >&2
    exit 1
  fi

  rm -rf "$td"
  echo "validate-polish-artifacts.sh --self-test OK"
  exit 0
}

[[ "${1:-}" == "--self-test" ]] && run_polish_self_test

TOTAL_PASS=0
TOTAL_FAIL=0
FAILURES=()

log_pass() { TOTAL_PASS=$((TOTAL_PASS + 1)); [[ $QUIET -eq 0 ]] && echo "  ✓ $1" || true; }
log_fail() { TOTAL_FAIL=$((TOTAL_FAIL + 1)); FAILURES+=("$1"); echo "  ✗ $1" >&2; }

# Closed UI/UX closure-verb vocabulary from ui-design-sweep.md (19 verbs).
# Frontend polish findings MUST use one of these verbs (or no verb at all).
# Verbs not on this list = either (a) an architectural concern routed elsewhere,
# (b) a code-structure concern (refactoring-sweep), or (c) a 20th-verb invention
# the skill explicitly forbids. Rejecting them here mirrors the way
# validate-refactor-artifacts.sh enforces refactoring-sweep's 10-verb set.
# This array is the SOURCE OF TRUTH for the frontend verb count (19).
UI_DESIGN_SWEEP_VERBS=(
  consolidate-tokens extract-token unify-component extract-pattern
  normalize-hierarchy apply-type-scale tighten-rhythm simplify-density
  wire-empty-state wire-loading-state wire-error-state
  lift-contrast align-focus-ring unify-iconography normalize-motion
  expand-tap-target unify-cta-placement clarify-affordance normalize-surface
)

# Closed backend closure-verb vocabulary from commands/polish.md § Backend (15 verbs).
API_CONSISTENCY_VERBS=(
  unify-envelope unify-error-contract unify-naming unify-pagination
  unify-versioning unify-auth-header add-idempotency-key unify-rate-limit-headers
  unify-log-fields unify-metric-names unify-trace-spans unify-timeout-policy
  unify-retry-policy add-openapi-doc add-endpoint-example
)

# Closed data closure-verb vocabulary from commands/polish.md § Data (12 verbs).
SCHEMA_CONSISTENCY_VERBS=(
  unify-column-naming unify-type-choice unify-index-naming unify-fk-naming
  unify-migration-pattern unify-timestamp-cols add-soft-delete add-audit-fields
  unify-timezone unify-charset unify-collation unify-nullable
)

is_ui_design_sweep_verb() {
  local v="$1"
  local ok
  for ok in "${UI_DESIGN_SWEEP_VERBS[@]}"; do
    [[ "$v" == "$ok" ]] && return 0
  done
  return 1
}

is_api_consistency_verb() {
  local v="$1"
  local ok
  for ok in "${API_CONSISTENCY_VERBS[@]}"; do
    [[ "$v" == "$ok" ]] && return 0
  done
  return 1
}

is_schema_consistency_verb() {
  local v="$1"
  local ok
  for ok in "${SCHEMA_CONSISTENCY_VERBS[@]}"; do
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
  cited=$(printf '%s\n' "$cited" | tail -1)
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

check_backend_verb_vocabulary() {
  # Backend polish findings under ai/polish/ledger.md (or _api-decisions.md
  # inline rows) must use the api-consistency-audit closed 15-verb set.
  # Mirrors check_frontend_verb_vocabulary.
  local ledger="$POLISH_DIR/ledger.md"
  local api="$POLISH_DIR/_api-decisions.md"
  local sources=()
  [[ -f "$ledger" ]] && sources+=("$ledger")
  [[ -f "$api" ]] && sources+=("$api")
  [[ ${#sources[@]} -eq 0 ]] && return 0

  local bad=()
  local total=0
  local f line verb
  for f in "${sources[@]}"; do
    while IFS= read -r line; do
      verb=$(echo "$line" | sed -E 's/.*closure_verb:[[:space:]]*//; s/[[:space:]#].*//; s/["'"'"']//g')
      [[ -z "$verb" ]] && continue
      total=$((total + 1))
      is_api_consistency_verb "$verb" || bad+=("$f: $verb")
    done < <(grep -E 'closure_verb:' "$f" 2>/dev/null || true)
  done

  if [[ ${#bad[@]} -gt 0 ]]; then
    log_fail "backend polish uses verbs outside api-consistency-audit closed vocabulary: ${bad[*]} (allowed: ${API_CONSISTENCY_VERBS[*]})"
    return 1
  fi
  if [[ $total -gt 0 ]]; then
    log_pass "backend polish closure_verb vocabulary: $total/$total in api-consistency-audit set"
  fi
  return 0
}

check_data_verb_vocabulary() {
  # Data polish findings under ai/polish/ledger.md (or _schema-decisions.md
  # inline rows) must use the schema-consistency-audit closed 12-verb set.
  # Mirrors check_frontend_verb_vocabulary.
  local ledger="$POLISH_DIR/ledger.md"
  local schema="$POLISH_DIR/_schema-decisions.md"
  local sources=()
  [[ -f "$ledger" ]] && sources+=("$ledger")
  [[ -f "$schema" ]] && sources+=("$schema")
  [[ ${#sources[@]} -eq 0 ]] && return 0

  local bad=()
  local total=0
  local f line verb
  for f in "${sources[@]}"; do
    while IFS= read -r line; do
      verb=$(echo "$line" | sed -E 's/.*closure_verb:[[:space:]]*//; s/[[:space:]#].*//; s/["'"'"']//g')
      [[ -z "$verb" ]] && continue
      total=$((total + 1))
      is_schema_consistency_verb "$verb" || bad+=("$f: $verb")
    done < <(grep -E 'closure_verb:' "$f" 2>/dev/null || true)
  done

  if [[ ${#bad[@]} -gt 0 ]]; then
    log_fail "data polish uses verbs outside schema-consistency-audit closed vocabulary: ${bad[*]} (allowed: ${SCHEMA_CONSISTENCY_VERBS[*]})"
    return 1
  fi
  if [[ $total -gt 0 ]]; then
    log_pass "data polish closure_verb vocabulary: $total/$total in schema-consistency-audit set"
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
  endpoints=$(printf '%s\n' "$endpoints" | tail -1)
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
  tables=$(printf '%s\n' "$tables" | tail -1)
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
  # grep -c on no match prints "0" AND exits 1, so `|| echo 0` can append a
  # second line ("0\n0"); collapse to the last numeric token.
  handwaves=$(printf '%s\n' "$handwaves" | tail -1)
  handwaves=${handwaves:-0}

  if [[ "$handwaves" -gt 0 ]]; then
    log_fail "polish has $handwaves hand-wave(s) in $file — enumerate explicitly per anti-Trusted-Summary discipline."
    return 1
  fi
  log_pass "no hand-wave language in polish artifact"
  return 0
}

check_actionable_next_steps() {
  # Per templates/snippets/actionable-next-steps.md: if a final-report.md exists,
  # it MUST end with an `## Actionable next steps` section containing paste-ready
  # commands for every deferred / out-of-scope finding.
  local report="${1:-$POLISH_DIR/final-report.md}"
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

# --- Fenced-YAML ledger row parsing (mirrors migrate/align row parsing) -------
#
# The ledger is a series of ``` fenced blocks; each block that contains an `id:`
# line is one row. Each gate below runs a single self-contained awk pass that
# walks fences, collects the fields it needs per row, and prints one token per
# OFFENDING terminal row. Bash then inspects the offending tokens. Doing the
# field extraction inside awk (rather than bash subshells) avoids the
# lost-array pitfall of `while read` in a pipe and keeps the parser robust.
#
# A terminal row is one whose `status:` or `state:` is done / verified / fixed.

check_gaps_parity() {
  # Any terminal row MUST have gaps_in == gaps_closed. Mirrors migration/align.
  local ledger="$POLISH_DIR/ledger.md"
  [[ ! -f "$ledger" ]] && return 0

  local report checked bad
  report=$(awk '
    function val(key,  v) { v=line; sub("^[[:space:]]*" key ":[[:space:]]*","",v); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); gsub(/["\047]/,"",v); return v }
    function flush() {
      if (have_id) {
        terminal = (status ~ /^(done|verified|fixed)$/) || (state ~ /^(done|verified|fixed)$/)
        if (terminal && (gi != "" || gc != "")) {
          g_in = (gi == "" ? "0" : gi); g_cl = (gc == "" ? "0" : gc)
          checked++
          if (g_in != g_cl) bad = bad sprintf("%s(gaps_in=%s!=gaps_closed=%s) ", (id==""?"<no-id>":id), g_in, g_cl)
        }
      }
      have_id=0; id=""; status=""; state=""; gi=""; gc=""
    }
    /^[[:space:]]*```/ { flush(); next }
    { line=$0; sub(/[[:space:]]*#.*/,"",line) }
    line ~ /^[[:space:]]*id:/          { id=val("id"); have_id=1 }
    line ~ /^[[:space:]]*status:/      { status=val("status") }
    line ~ /^[[:space:]]*state:/       { state=val("state") }
    line ~ /^[[:space:]]*gaps_in:/     { gi=val("gaps_in") }
    line ~ /^[[:space:]]*gaps_closed:/ { gc=val("gaps_closed") }
    END { flush(); printf "%d\037%s", checked, bad }
  ' "$ledger")
  checked="${report%%$'\037'*}"
  bad="${report#*$'\037'}"

  if [[ -n "${bad// /}" ]]; then
    log_fail "polish terminal rows with unbalanced gaps (gaps_in != gaps_closed): ${bad% }"
    return 1
  fi
  [[ "${checked:-0}" -gt 0 ]] && log_pass "polish gaps parity: $checked terminal row(s) balanced (gaps_in == gaps_closed)"
  return 0
}

check_outcome_delta() {
  # A no-op polish (zero diff, identical a11y/OpenAPI/schema) must NOT be `done`.
  # Terminal rows must show a non-empty delta (a11y / OpenAPI / schema / commits /
  # diff) OR be classed `no-change`.
  local ledger="$POLISH_DIR/ledger.md"
  [[ ! -f "$ledger" ]] && return 0

  local bad
  bad=$(awk '
    function val(key,  v) { v=line; sub("^[[:space:]]*" key ":[[:space:]]*","",v); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); gsub(/["\047]/,"",v); return v }
    function nonzero(x) { return (x != "" && x != "0" && x != "none" && x != "+0 / -0") }
    function flush() {
      if (have_id) {
        terminal = (status ~ /^(done|verified|fixed)$/) || (state ~ /^(done|verified|fixed)$/)
        if (terminal && class != "no-change" && outcome != "no-change") {
          has = nonzero(a11y) || nonzero(openapi) || nonzero(schema) || nonzero(commits) || nonzero(diff)
          if (!has) bad = bad (id==""?"<no-id>":id) " "
        }
      }
      have_id=0; id=""; status=""; state=""; class=""; outcome=""
      a11y=""; openapi=""; schema=""; commits=""; diff=""
    }
    /^[[:space:]]*```/ { flush(); next }
    { line=$0; sub(/[[:space:]]*#.*/,"",line) }
    line ~ /^[[:space:]]*id:/            { id=val("id"); have_id=1 }
    line ~ /^[[:space:]]*status:/        { status=val("status") }
    line ~ /^[[:space:]]*state:/         { state=val("state") }
    line ~ /^[[:space:]]*class:/         { class=val("class") }
    line ~ /^[[:space:]]*outcome:/       { outcome=val("outcome") }
    line ~ /^[[:space:]]*a11y_delta:/    { a11y=val("a11y_delta") }
    line ~ /^[[:space:]]*openapi_delta:/ { openapi=val("openapi_delta") }
    line ~ /^[[:space:]]*schema_delta:/  { schema=val("schema_delta") }
    line ~ /^[[:space:]]*commits:/       { commits=val("commits") }
    line ~ /^[[:space:]]*diff:/          { diff=val("diff") }
    END { flush(); printf "%s", bad }
  ' "$ledger")

  if [[ -n "${bad// /}" ]]; then
    log_fail "polish terminal rows with no measurable outcome (zero diff / identical a11y / OpenAPI / schema) — class them 'no-change', not 'done': ${bad% }"
    return 1
  fi
  log_pass "polish outcome-delta: every terminal row shows a delta or is classed no-change"
  return 0
}

check_visual_baseline() {
  # Terminal FRONTEND rows must reference a visual baseline AND must not be
  # marked done while still `pending-review`. ui-design-sweep marks
  # no-visual-verify rows `pending-review` (not `done`) — enforce that here.
  case "$PROJECT_KIND" in
    frontend-*|mobile-*) ;;
    *) return 0 ;;
  esac
  local ledger="$POLISH_DIR/ledger.md"
  [[ ! -f "$ledger" ]] && return 0

  local bad
  bad=$(awk '
    function val(key,  v) { v=line; sub("^[[:space:]]*" key ":[[:space:]]*","",v); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); gsub(/["\047]/,"",v); return v }
    function flush() {
      if (have_id) {
        terminal = (status ~ /^(done|verified|fixed)$/) || (state ~ /^(done|verified|fixed)$/)
        if (terminal) {
          if (status == "pending-review" || state == "pending-review" || review == "pending")
            bad = bad (id==""?"<no-id>":id) "(pending-review-marked-terminal) "
          else {
            b = (baseline != "" ? baseline : vbaseline)
            if (b == "" || b == "none" || b == "missing")
              bad = bad (id==""?"<no-id>":id) "(no-baseline) "
          }
        }
      }
      have_id=0; id=""; status=""; state=""; review=""; baseline=""; vbaseline=""
    }
    /^[[:space:]]*```/ { flush(); next }
    { line=$0; sub(/[[:space:]]*#.*/,"",line) }
    line ~ /^[[:space:]]*id:/              { id=val("id"); have_id=1 }
    line ~ /^[[:space:]]*status:/          { status=val("status") }
    line ~ /^[[:space:]]*state:/           { state=val("state") }
    line ~ /^[[:space:]]*review:/          { review=val("review") }
    line ~ /^[[:space:]]*baseline:/        { baseline=val("baseline") }
    line ~ /^[[:space:]]*visual_baseline:/ { vbaseline=val("visual_baseline") }
    END { flush(); printf "%s", bad }
  ' "$ledger")

  if [[ -n "${bad// /}" ]]; then
    log_fail "polish terminal frontend rows missing a visual baseline OR marked done while pending-review: ${bad% }"
    return 1
  fi
  log_pass "polish visual-baseline: every terminal frontend row has a baseline and is not pending-review"
  return 0
}

main() {
  [[ $QUIET -eq 0 ]] && echo "validate-polish-artifacts.sh"
  [[ $QUIET -eq 0 ]] && echo "  PROJECT_KIND: $PROJECT_KIND"
  [[ $QUIET -eq 0 ]] && echo "  POLISH_DIR:   $POLISH_DIR"

  case "$PROJECT_KIND" in
    frontend-*) check_frontend_evidence || true; check_frontend_verb_vocabulary || true; check_visual_baseline || true ;;
    backend-*)  check_backend_evidence  || true; check_backend_verb_vocabulary || true ;;
    data-*)     check_data_evidence     || true; check_data_verb_vocabulary || true ;;
    mobile-*)   check_mobile_evidence || check_frontend_evidence || true; check_frontend_verb_vocabulary || true; check_visual_baseline || true ;;
    *)
      log_fail "unknown PROJECT_KIND: $PROJECT_KIND — set in .claude/_extracted-codebase.md § Gold standards"
      ;;
  esac
  check_no_handwaves || true
  check_gaps_parity || true
  check_outcome_delta || true
  check_actionable_next_steps || true

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
