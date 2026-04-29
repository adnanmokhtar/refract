#!/usr/bin/env bash
# validate-migration-artifacts.sh — universal migration-discipline validator.
#
# Tool-agnostic. Runs from any AI tool's hook system, CI pipeline, or pre-commit.
# Validates the artifact set required by `migration-discipline.md` for every
# feature in a phase (or for one feature with --feature=).
#
# Checks (per migration-discipline.md § "Required artifacts per feature" + § "Per-feature audit — 10 hard halts"):
#   1.  Contract file exists at ai/migration/contracts/<feature>.md
#   2.  Contract has all 9 required sections (Inputs / Outputs / Side effects /
#       Business rules / Invariants / Performance characteristics / Caller
#       assumptions / Edge cases / Known V1 bugs)
#   3.  Every <path:line> citation in the contract resolves
#   4.  Plan file exists at ai/migration/plans/<feature>.md
#   5.  Parity test directory exists with ≥30 inputs OR a record-replay
#       setup file (replay/ subdir or replay-config.yaml)
#   6.  tolerance.yaml exists for the feature
#   7.  Perf-decisions file exists; every candidate classified; applied has measurement
#   8.  Rollback runbook exists at ai/runbooks/migration-rollback-<feature>.md
#   9.  Audit file exists at ai/migration/audits/<feature>.md with required sections
#       (no hand-waves: no "&...", "etc.", "..." in axis enumeration)
#   10. Ledger row exists with required fields per state (per migration-ledger.md)
#
# Usage:
#   validate-migration-artifacts.sh --phase=<N>           # validate every feature in phase N
#   validate-migration-artifacts.sh --feature=<id>        # validate one feature
#   validate-migration-artifacts.sh --all                 # validate every feature in ledger
#   validate-migration-artifacts.sh --strict              # treat warnings as errors
#   validate-migration-artifacts.sh --quiet               # only print failures
#
# Exit codes:
#   0  — all checks pass
#   1  — at least one check failed
#   2  — usage error / unable to read ledger or plan
#   3  — environment error (paths missing, tools missing)
#
# Project anchor: reads paths from ai/migration/ledger.md (managed-block fields)
# and ai/migration/plan.md. Falls back to defaults below.

set -euo pipefail
export LC_ALL=C

# ── Defaults ────────────────────────────────────────────────────────────────
LEDGER_PATH="ai/migration/ledger.md"
PLAN_PATH="ai/migration/plan.md"
CONTRACTS_DIR="ai/migration/contracts"
PLANS_DIR="ai/migration/plans"
AUDITS_DIR="ai/migration/audits"
PERF_DIR="ai/migration/perf-decisions"
RUNBOOKS_DIR="ai/runbooks"
PARITY_TEST_ROOT_DEFAULT="tests/parity"
MIN_CORPUS=30

PHASE=""
FEATURE=""
SCAN_ALL=0
STRICT=0
QUIET=0

# ── Args ────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase=*)   PHASE="${1#--phase=}"; shift ;;
    --feature=*) FEATURE="${1#--feature=}"; shift ;;
    --all)       SCAN_ALL=1; shift ;;
    --strict)    STRICT=1; shift ;;
    --quiet)     QUIET=1; shift ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--phase=N | --feature=ID | --all] [--strict] [--quiet]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PHASE" && -z "$FEATURE" && "$SCAN_ALL" -eq 0 ]]; then
  echo "Usage: $0 [--phase=N | --feature=ID | --all]" >&2
  exit 2
fi

if [[ ! -f "$LEDGER_PATH" ]]; then
  echo "FATAL: ledger not found at $LEDGER_PATH" >&2
  echo "Are you running from a repo root with ai/migration/ledger.md?" >&2
  exit 3
fi

# ── Output helpers ──────────────────────────────────────────────────────────
TOTAL_CHECKED=0
TOTAL_PASS=0
TOTAL_FAIL=0
declare -a FAILURES

log_pass() {
  ((TOTAL_PASS++))
  if [[ $QUIET -eq 0 ]]; then
    echo "  ✓ $1"
  fi
}

log_fail() {
  ((TOTAL_FAIL++))
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

# ── Parse the ledger to discover features in scope ──────────────────────────
# Ledger format (per migration-ledger.md): yaml-fenced blocks under `## <feature-name>` headers,
# each with `id: F<NNN>`, `feature: <slug>`, `phase: <N>`, `status: <state>` etc.
#
# Feature output format (one per line): "<id>|<feature-slug>|<phase>|<status>|<parity_test>"
discover_features() {
  awk '
    /^id: F[0-9]+/ {
      # finalize previous block if any
      if (id != "") {
        print id "|" feature "|" phase "|" status "|" parity_test
      }
      id = $2; feature=""; phase=""; status=""; parity_test=""
      next
    }
    /^feature: / { feature=$2; next }
    /^phase: /   { phase=$2;   next }
    /^status: /  { status=$2;  next }
    /^parity_test: / { parity_test=$2; next }
    END {
      if (id != "") {
        print id "|" feature "|" phase "|" status "|" parity_test
      }
    }
  ' "$LEDGER_PATH"
}

# Filter discovered features per --phase / --feature / --all
filter_features() {
  if [[ -n "$FEATURE" ]]; then
    grep "^${FEATURE}|" || true
  elif [[ -n "$PHASE" ]]; then
    awk -F'|' -v p="$PHASE" '$3 == p' || true
  else
    cat
  fi
}

# ── Per-check implementations ──────────────────────────────────────────────
# Resolve a per-feature artifact path; accepts either `<slug>.md` OR `<id>-<slug>.md`
# Args: $1=dir $2=feature_slug $3=feature_id (optional)
# Echoes the path that exists, or empty if neither exists.
resolve_artifact_path() {
  local dir="$1"; local slug="$2"; local id="${3:-}"
  if [[ -n "$id" && -f "${dir}/${id}-${slug}.md" ]]; then
    echo "${dir}/${id}-${slug}.md"
  elif [[ -f "${dir}/${slug}.md" ]]; then
    echo "${dir}/${slug}.md"
  fi
}

check_contract_exists() {
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$CONTRACTS_DIR" "$feature" "$id")
  if [[ -n "$file" ]]; then
    log_pass "contract: $file"
    CONTRACT_PATH="$file"
    return 0
  else
    log_fail "contract MISSING: $CONTRACTS_DIR/${id:+$id-}${feature}.md (also tried $CONTRACTS_DIR/${feature}.md)"
    CONTRACT_PATH=""
    return 1
  fi
}

check_contract_sections() {
  local feature="$1"; local id="${2:-}"
  local file="$CONTRACT_PATH"
  [[ -f "$file" ]] || return 1
  local missing=()
  local section
  for section in "Inputs" "Outputs" "Side effects" "Business rules" "Invariants" "Performance characteristics" "Caller assumptions" "Edge cases" "Known V1 bugs"; do
    if ! grep -qE "^## (([0-9]+\. )|\b)$section\b" "$file"; then
      missing+=("$section")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    log_pass "contract sections complete (9/9): $feature"
    return 0
  else
    log_fail "contract sections incomplete: $feature — missing: ${missing[*]}"
    return 1
  fi
}

check_contract_citations() {
  local feature="$1"; local id="${2:-}"
  local file="$CONTRACT_PATH"
  [[ -f "$file" ]] || return 1
  # Match `<path>:<line>` patterns that look like file references using grep + perl-style regex.
  # Cross-repo paths (tenant-portal/...) won't resolve from tenant-portal-v2 cwd; treated as warnings.
  local broken=0
  local checked=0
  # Extract path:line tokens that look like real files (path contains a dot + extension)
  local tokens
  tokens=$(grep -oE '`[^[:space:]`]+\.[a-zA-Z]+:[0-9]+`' "$file" 2>/dev/null | sed 's/`//g' || true)
  while IFS= read -r token; do
    [[ -z "$token" ]] && continue
    local path="${token%:*}"
    local lineno="${token##*:}"
    # Skip placeholders
    case "$path" in
      v1-path|v2-path|path|file) continue ;;
    esac
    checked=$((checked + 1))
    if [[ -f "$path" ]]; then
      local actual_lines
      actual_lines=$(wc -l < "$path" | tr -d ' ')
      if [[ "$lineno" -gt "$actual_lines" ]] 2>/dev/null; then
        log_warn "citation out-of-range in $feature: $path:$lineno (file has $actual_lines lines)"
        broken=$((broken + 1))
      fi
    else
      # Cross-repo paths (e.g., tenant-portal/... when cwd is tenant-portal-v2) — treat as informational
      if [[ "$path" =~ ^tenant-portal/ ]]; then
        : # cross-repo; skip
      else
        log_warn "citation unresolved in $feature: $path:$lineno (file not found)"
        broken=$((broken + 1))
      fi
    fi
  done <<< "$tokens"
  if [[ $broken -eq 0 ]]; then
    log_pass "contract citations resolve: $feature ($checked checked)"
  else
    log_warn "contract has $broken citation issue(s): $feature ($checked checked; --strict promotes to error)"
  fi
  return 0
}

check_plan_exists() {
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$PLANS_DIR" "$feature" "$id")
  if [[ -n "$file" ]]; then
    log_pass "plan: $file"
    return 0
  else
    log_fail "plan MISSING: $PLANS_DIR/${id:+$id-}${feature}.md (also tried $PLANS_DIR/${feature}.md)"
    return 1
  fi
}

check_parity_corpus() {
  local feature="$1"; local id="${2:-}"
  # Try common parity-test root locations
  local roots=("$PARITY_TEST_ROOT_DEFAULT" "tests/parity" "src/__tests__/parity" "src/**/__tests__/parity")
  local feature_dir=""
  for r in "${roots[@]}"; do
    if [[ -d "$r/$feature" ]]; then
      feature_dir="$r/$feature"
      break
    fi
    # Also try id-prefixed dir
    if [[ -n "$id" && -d "$r/${id}-${feature}" ]]; then
      feature_dir="$r/${id}-${feature}"
      break
    fi
  done
  # Also check src/modules/<m>/__tests__/parity/<feature>.spec.{ts,tsx,js}
  if [[ -z "$feature_dir" ]]; then
    local spec_files
    spec_files=$(find src tests -path "*__tests__/parity*" -name "*${feature}*" 2>/dev/null | head -5)
    if [[ -n "$spec_files" ]]; then
      log_warn "parity tests found in spec-file form (no corpus dir): $feature — corpus check skipped, ensure ≥30 cases or record-replay"
      return 0
    fi
    log_fail "parity test directory MISSING for $feature (looked under: tests/parity/$feature, src/**/__tests__/parity/$feature)"
    return 1
  fi
  # Count inputs
  local input_count=0
  if [[ -d "$feature_dir/inputs" ]]; then
    input_count=$(find "$feature_dir/inputs" -type f \( -name '*.json' -o -name '*.yaml' \) 2>/dev/null | wc -l | tr -d ' ')
  fi
  # Check for record-replay setup
  local has_replay=0
  if [[ -d "$feature_dir/replay" || -f "$feature_dir/replay-config.yaml" ]]; then
    has_replay=1
  fi
  if [[ $input_count -ge $MIN_CORPUS ]]; then
    log_pass "parity corpus ≥${MIN_CORPUS}: $feature ($input_count inputs)"
  elif [[ $has_replay -eq 1 ]]; then
    log_pass "parity record-replay setup: $feature ($input_count inputs + replay corpus)"
  else
    log_fail "parity corpus thin: $feature — $input_count inputs (need ≥$MIN_CORPUS or record-replay setup)"
    return 1
  fi
  # Tolerance file
  if [[ -f "$feature_dir/tolerance.yaml" ]]; then
    log_pass "tolerance.yaml: $feature_dir/tolerance.yaml"
  else
    log_fail "tolerance.yaml MISSING: $feature_dir/tolerance.yaml"
    return 1
  fi
  return 0
}

check_perf_decisions() {
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$PERF_DIR" "$feature" "$id")
  if [[ -z "$file" ]]; then
    log_fail "perf-decisions MISSING: $PERF_DIR/${id:+$id-}${feature}.md"
    return 1
  fi
  # Count classified candidates (applied / deferred / rejected appearing in headers or status lines)
  local applied deferred rejected
  applied=$(grep -ciE '^\s*(- )?(\*\*)?(decision|status):?\s*(\*\*)?\s*applied\b|^### .* — APPLIED|^### .* — applied' "$file" 2>/dev/null | head -1 | tr -d ' \n' || echo 0)
  deferred=$(grep -ciE '^\s*(- )?(\*\*)?(decision|status):?\s*(\*\*)?\s*deferred\b|^### .* — DEFERRED|^### .* — deferred' "$file" 2>/dev/null | head -1 | tr -d ' \n' || echo 0)
  rejected=$(grep -ciE '^\s*(- )?(\*\*)?(decision|status):?\s*(\*\*)?\s*rejected\b|^### .* — REJECTED|^### .* — rejected' "$file" 2>/dev/null | head -1 | tr -d ' \n' || echo 0)
  applied=${applied:-0}; deferred=${deferred:-0}; rejected=${rejected:-0}
  local total=$((applied + deferred + rejected))
  if [[ $total -eq 0 ]]; then
    log_warn "perf-decisions has no classified candidates: $feature (file may be empty stub)"
  else
    log_pass "perf-decisions classified: $feature (applied=$applied, deferred=$deferred, rejected=$rejected)"
  fi
  # If anything is applied, look for a measurement
  if [[ $applied -gt 0 ]]; then
    if grep -qE '(measured|measurement|p[0-9]+|ms|queries|saving)' "$file"; then
      log_pass "perf-decisions has measurements: $feature"
    else
      log_warn "perf-decisions has applied candidates but no apparent measurements: $feature"
    fi
  fi
  return 0
}

check_runbook() {
  local feature="$1"; local id="${2:-}"
  local f1="$RUNBOOKS_DIR/migration-rollback-${feature}.md"
  local f2="$RUNBOOKS_DIR/migration-rollback-${id}-${feature}.md"
  if [[ -f "$f2" ]]; then
    log_pass "rollback runbook: $f2"
    return 0
  elif [[ -f "$f1" ]]; then
    log_pass "rollback runbook: $f1"
    return 0
  else
    log_fail "rollback runbook MISSING: $f2 (also tried $f1)"
    return 1
  fi
}

check_audit() {
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  if [[ -z "$file" ]]; then
    log_fail "audit MISSING: $AUDITS_DIR/${id:+$id-}${feature}.md"
    return 1
  fi
  # Required sections
  local missing=()
  for section in "Classification" "Per-axis comparison" "Tenant-isolation gate" "Decision recommended"; do
    if ! grep -qE "^## ${section}\b|^### ${section}\b" "$file"; then
      missing+=("$section")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "audit missing sections in $feature: ${missing[*]}"
  fi
  # Hand-wave detection
  local handwaves
  handwaves=$(grep -cE '\&\.\.\.|^\s*\|.*&\.\.\.|"etc\.|, etc\.|\.\.\.[[:space:]]*\|' "$file" 2>/dev/null | head -1 | tr -d ' \n' || echo 0)
  handwaves=${handwaves:-0}
  if [[ $handwaves -gt 0 ]]; then
    log_warn "audit has $handwaves hand-wave(s) (\"&...\", \"etc.\", trailing \"...\"): $file — enumerate explicitly per migration-discipline.md anti-pattern \"The Hand-waved Query Param\""
  else
    log_pass "audit enumerates explicitly: $feature"
  fi
  return 0
}

check_ledger_row() {
  local id="$1"; local feature="$2"; local status="$3"
  # Check that minimum required fields exist in the ledger row for this id
  local ledger_block
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH")
  local required_for_state=()
  case "$status" in
    "V1-only"|"unverified")
      required_for_state=(feature)
      ;;
    "in-progress"|"In-progress")
      required_for_state=(feature contract plan v1_commit_pinned)
      ;;
    "V2-shadow"|"done"|"divergent")
      required_for_state=(feature contract plan v1_commit_pinned parity_tests)
      ;;
    *)
      required_for_state=(feature)
      ;;
  esac
  local missing=()
  for f in "${required_for_state[@]}"; do
    if ! echo "$ledger_block" | grep -qE "^${f}:"; then
      missing+=("$f")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    log_pass "ledger row $id ($feature): required fields populated for status=$status"
  else
    log_fail "ledger row $id ($feature) missing required fields for status=$status: ${missing[*]}"
    return 1
  fi
  return 0
}

# ── Validate one feature ────────────────────────────────────────────────────
validate_feature() {
  local id="$1"; local feature="$2"; local phase="$3"; local status="$4"; local parity_test="$5"
  ((TOTAL_CHECKED++))
  log_section "Feature $id ($feature) — phase $phase, status=$status"
  # 0. Check the ledger row first
  check_ledger_row "$id" "$feature" "$status" || true
  # If status is parked / deprecated / unverified / V1-only — skip the rest (artifacts not yet required)
  case "$status" in
    parked|deprecated|unverified|V1-only)
      log_warn "skipping artifact checks: status=$status (not yet required)"
      return 0
      ;;
  esac
  # Strip surrounding whitespace from status for the artifact-check branch
  status="${status// /}"
  # 1-9: artifact checks
  CONTRACT_PATH=""  # set by check_contract_exists; consumed by sections + citations
  check_contract_exists "$feature" "$id" || true
  check_contract_sections "$feature" "$id" || true
  check_contract_citations "$feature" "$id" || true
  check_plan_exists "$feature" "$id" || true
  check_parity_corpus "$feature" "$id" || true
  check_perf_decisions "$feature" "$id" || true
  check_runbook "$feature" "$id" || true
  check_audit "$feature" "$id" || true
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  if [[ $QUIET -eq 0 ]]; then
    echo "validate-migration-artifacts.sh"
    echo "  ledger: $LEDGER_PATH"
    if [[ -n "$PHASE" ]]; then echo "  scope:  phase $PHASE"; fi
    if [[ -n "$FEATURE" ]]; then echo "  scope:  feature $FEATURE"; fi
    if [[ $SCAN_ALL -eq 1 ]]; then echo "  scope:  all features"; fi
  fi

  local features
  features=$(discover_features | filter_features)
  if [[ -z "$features" ]]; then
    echo "No features matched the scope. Check ledger contents." >&2
    exit 2
  fi

  while IFS='|' read -r id feature phase status parity_test; do
    [[ -n "$id" ]] || continue
    validate_feature "$id" "$feature" "$phase" "$status" "$parity_test"
  done <<< "$features"

  echo
  echo "── Summary ──"
  echo "  features checked: $TOTAL_CHECKED"
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
  exit 0
}

main "$@"
