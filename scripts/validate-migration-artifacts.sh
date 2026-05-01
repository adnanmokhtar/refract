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
# These are SHARED defaults; actual values may be overridden by the project's
# ai/migration/_v2-anchors.md frontmatter (see load_project_anchors below).
LEDGER_PATH="ai/migration/ledger.md"
PLAN_PATH="ai/migration/plan.md"
CONTRACTS_DIR="ai/migration/contracts"
PLANS_DIR="ai/migration/plans"
AUDITS_DIR="ai/migration/audits"
PERF_DIR="ai/migration/perf-decisions"
RUNBOOKS_DIR="ai/runbooks"
PARITY_TEST_ROOT_DEFAULT="tests/parity"
MIN_CORPUS=30
PROJECT_KIND="frontend-vue3"      # frontend-vue3 | frontend-react | backend-nest | api-other
V2_ROOT="src/"
V1_ROOT=""
ANCHORS_FILE="ai/migration/_v2-anchors.md"
# Lifecycle / KeepAlive checks (frontend) — anchor these per project via _v2-anchors.md
KEEPALIVE_LAYOUT=""               # e.g. src/shared/layouts/MainLayout.vue (Vue) — empty = lifecycle check disabled
KEEPALIVE_EXCLUDE_VAR="noCache"   # variable name in the layout that holds the exclude list

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

# ── Parse the ledger to discover features in scope ──────────────────────────
# Ledger format (per migration-ledger.md): yaml-fenced blocks under `## <feature-name>` headers,
# each with `id: F<NNN>`, `feature: <slug>`, `phase: <N>`, `status: <state>` etc.
#
# Feature output format (one per line): "<id>|<feature-slug>|<phase>|<status>|<parity_test>"
discover_features() {
  # Parse ledger respecting yaml-block boundaries. A row starts at `id: FNNN[a-z]?`,
  # ends at the closing ``` fence (or the next id: line). Only accept field-setters
  # while in_block=1 — prevents cross-block leakage where superseded blocks contribute
  # `feature:` lines to a previous block.
  awk '
    /^id: F[0-9]+[a-z]?$/ {
      if (id != "") {
        print id "|" feature "|" phase "|" status "|" parity_test "|" tier
      }
      id = $2; feature=""; phase=""; status=""; parity_test=""; tier=""
      in_block = 1
      next
    }
    /```/ {
      # Match closing ``` whether on its own line OR appended to text (e.g. "...notes.```").
      # The yaml-block fence may be inline-terminated.
      if (in_block) {
        print id "|" feature "|" phase "|" status "|" parity_test "|" tier
        id=""; feature=""; phase=""; status=""; parity_test=""; tier=""
        in_block = 0
      }
      next
    }
    in_block && /^feature: / { feature=$2; next }
    in_block && /^phase: /   { phase=$2;   next }
    in_block && /^status: /  { status=$2;  next }
    in_block && /^tier: /    { tier=$2;    next }
    in_block && /^parity_test: / { parity_test=$2; next }
    END {
      if (id != "") {
        print id "|" feature "|" phase "|" status "|" parity_test "|" tier
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
    return
  elif [[ -f "${dir}/${slug}.md" ]]; then
    echo "${dir}/${slug}.md"
    return
  fi
  # Sub-feature fallback: if the row has `parent: FNNN` in its ledger block,
  # try resolving the parent's audit/contract/plan. Many sub-features (e.g.
  # F015a-product-edit-basic-data) are audited under the parent (F015) rather
  # than having their own file.
  if [[ -n "$id" ]]; then
    local parent
    parent=$(awk -v id="$id" '
      $0 ~ ("^id: " id "$") { in_block=1; next }
      in_block && /^parent:[[:space:]]/ { sub(/^parent:[[:space:]]*/, "", $0); print $0; exit }
      in_block && /^id:|^```/ { exit }
    ' "$LEDGER_PATH" 2>/dev/null | tr -d ' \r')
    if [[ -n "$parent" ]]; then
      # Try parent's <id>-*.md (any feature slug under the parent id)
      local parent_file
      parent_file=$(ls "${dir}/${parent}-"*.md 2>/dev/null | head -1)
      if [[ -n "$parent_file" ]] && [[ -f "$parent_file" ]]; then
        echo "$parent_file"
        return
      fi
    fi
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
  local tier="${3:-heavy}"
  local file="$CONTRACT_PATH"
  [[ -f "$file" ]] || return 1
  local missing=()
  local section
  # Tier-scoped section list per migration-discipline.md § Contract — required sections
  # Heavy: 9 sections. Standard: 3 sections (Inputs / Outputs / Known V1 bugs). Trivial: skipped (no contract required).
  local required_sections
  case "$tier" in
    standard) required_sections=("Inputs" "Outputs" "Known V1 bugs") ;;
    *)        required_sections=("Inputs" "Outputs" "Side effects" "Business rules" "Invariants" "Performance characteristics" "Caller assumptions" "Edge cases" "Known V1 bugs") ;;
  esac
  for section in "${required_sections[@]}"; do
    if ! grep -qE "^## (([0-9]+\. )|\b)$section\b" "$file"; then
      missing+=("$section")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    log_pass "contract sections complete (${#required_sections[@]}/${#required_sections[@]}, tier=$tier): $feature"
    return 0
  else
    log_fail "contract sections incomplete (tier=$tier): $feature — missing: ${missing[*]}"
    return 1
  fi
}

# Cache of V1 + V2 file basenames → first absolute path. Built once per validator run.
# Avoids per-citation `find` calls (which made phase-7 + phase-8 runs hang for minutes).
V1_BASENAME_INDEX_BUILT=0
V1_BASENAME_INDEX_FILE=""
V2_BASENAME_INDEX_BUILT=0
V2_BASENAME_INDEX_FILE=""
build_v1_basename_index() {
  [[ $V1_BASENAME_INDEX_BUILT -eq 1 ]] && return 0
  V1_BASENAME_INDEX_BUILT=1
  if [[ -z "$V1_ROOT" ]] || [[ ! -d "$V1_ROOT" ]]; then return 0; fi
  V1_BASENAME_INDEX_FILE=$(mktemp -t v1-bn-idx.XXXXXX)
  find "$V1_ROOT" \( -name node_modules -o -name dist -o -name build_output.txt -o -name .git \) -prune -o \
    -type f \( -name '*.vue' -o -name '*.ts' -o -name '*.js' \) -print 2>/dev/null \
    | awk -F/ '{print $NF "\t" $0}' > "$V1_BASENAME_INDEX_FILE" 2>/dev/null
}
v1_basename_lookup() {
  local bn="$1"
  [[ -z "$V1_BASENAME_INDEX_FILE" ]] || [[ ! -f "$V1_BASENAME_INDEX_FILE" ]] && return 1
  awk -F'\t' -v bn="$bn" '$1 == bn { print $2; exit }' "$V1_BASENAME_INDEX_FILE"
}
build_v2_basename_index() {
  [[ $V2_BASENAME_INDEX_BUILT -eq 1 ]] && return 0
  V2_BASENAME_INDEX_BUILT=1
  local v2dir="${V2_ROOT:-src/}"
  [[ ! -d "$v2dir" ]] && return 0
  V2_BASENAME_INDEX_FILE=$(mktemp -t v2-bn-idx.XXXXXX)
  find "$v2dir" \( -name node_modules -o -name dist -o -name .git \) -prune -o \
    -type f \( -name '*.vue' -o -name '*.ts' -o -name '*.js' -o -name '*.tsx' -o -name '*.jsx' \) -print 2>/dev/null \
    | awk -F/ '{print $NF "\t" $0}' > "$V2_BASENAME_INDEX_FILE" 2>/dev/null
}
v2_basename_lookup() {
  local bn="$1"
  [[ -z "$V2_BASENAME_INDEX_FILE" ]] || [[ ! -f "$V2_BASENAME_INDEX_FILE" ]] && return 1
  awk -F'\t' -v bn="$bn" '$1 == bn { print $2; exit }' "$V2_BASENAME_INDEX_FILE"
}

check_contract_citations() {
  local feature="$1"; local id="${2:-}"
  local file="$CONTRACT_PATH"
  [[ -f "$file" ]] || return 1
  build_v1_basename_index
  build_v2_basename_index
  # Match `<path>:<line>` patterns that look like file references using grep + perl-style regex.
  # Cross-repo paths (<frontend-v1>/...) won't resolve from <frontend-v2> cwd; treated as warnings.
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
    # Try resolving the path in this order (project-agnostic):
    # 1. As-is (cwd-relative — for full-path V2 citations like src/modules/...)
    # 2. Under V1_ROOT, after stripping the V1_ROOT's basename prefix if present
    #    (e.g. V1_ROOT="../legacy-app/" → strip "legacy-app/" from a citation)
    # 3. As a basename anywhere under V1_ROOT (for unprefixed V1 cites)
    # 4. As a basename anywhere under V2_ROOT (for unprefixed V2 cites)
    local resolved=""
    if [[ -f "$path" ]]; then
      resolved="$path"
    elif [[ -n "$V1_ROOT" ]] && [[ -d "$V1_ROOT" ]]; then
      # Strip the V1_ROOT directory's basename if the citation includes it
      local v1_basename rel_v1
      v1_basename=$(basename "${V1_ROOT%/}")
      rel_v1="${path#${v1_basename}/}"
      if [[ -f "$V1_ROOT/$rel_v1" ]]; then
        resolved="$V1_ROOT/$rel_v1"
      fi
    fi
    if [[ -z "$resolved" ]] && [[ "$path" != *"/"* ]]; then
      # Bare filename (no slashes) — try V1 basename index, then V2 basename index
      local found
      found=$(v1_basename_lookup "$path")
      [[ -z "$found" ]] && found=$(v2_basename_lookup "$path")
      [[ -n "$found" ]] && resolved="$found"
    fi
    if [[ -n "$resolved" ]]; then
      local actual_lines
      actual_lines=$(wc -l < "$resolved" | tr -d ' ')
      if [[ "$lineno" -gt "$actual_lines" ]] 2>/dev/null; then
        log_warn "citation out-of-range in $feature: $path:$lineno (file has $actual_lines lines)"
        broken=$((broken + 1))
      fi
    else
      log_warn "citation unresolved in $feature: $path:$lineno (file not found in V2 or V1_ROOT)"
      broken=$((broken + 1))
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
  local feature="$1"; local id="${2:-}"; local tier="${3:-heavy}"
  # Tier-scoped minimum corpus per migration-discipline.md § Required artifacts per feature
  # Heavy: ≥30 fixtures. Standard: ≥10 fixtures. Trivial: skipped.
  local min_corpus="$MIN_CORPUS"
  case "$tier" in
    standard) min_corpus=10 ;;
  esac
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
  if [[ $input_count -ge $min_corpus ]]; then
    log_pass "parity corpus ≥${min_corpus} (tier=$tier): $feature ($input_count inputs)"
  elif [[ $has_replay -eq 1 ]]; then
    log_pass "parity record-replay setup: $feature ($input_count inputs + replay corpus)"
  else
    log_fail "parity corpus thin (tier=$tier): $feature — $input_count inputs (need ≥$min_corpus or record-replay setup)"
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

check_corpus_distribution() {
  # D1 — Corpus all-happy-path detection.
  # Filename-prefix convention: 001-099 = happy path, 100-199 = error, 200-299 = edge,
  # 300-399 = business-rule. Or category prefix words: happy-/error-/edge-/rule-/empty-/i18n-/ui-.
  # If any category is < 1, log_warn (project might genuinely lack a category).
  local feature="$1"; local id="${2:-}"
  local roots=("$PARITY_TEST_ROOT_DEFAULT" "tests/parity" "src/__tests__/parity")
  local feature_dir=""
  for r in "${roots[@]}"; do
    if [[ -d "$r/$feature" ]]; then feature_dir="$r/$feature"; break; fi
    if [[ -n "$id" && -d "$r/${id}-${feature}" ]]; then feature_dir="$r/${id}-${feature}"; break; fi
  done
  [[ -z "$feature_dir" ]] && return 0
  [[ ! -d "$feature_dir/inputs" ]] && return 0
  # Count by inspecting JSON 'category' field OR filename prefix
  local total=0 happy=0 error=0 edge=0 rule=0 ui=0 empty=0 i18n=0
  while IFS= read -r f; do
    total=$((total + 1))
    # Try JSON 'category' field
    local cat
    cat=$(grep -m1 -oE '"category"\s*:\s*"[^"]+"' "$f" 2>/dev/null | sed 's/.*"category":[[:space:]]*"\([^"]*\)".*/\1/')
    if [[ -z "$cat" ]]; then
      # Fallback: filename prefix
      local fname
      fname=$(basename "$f")
      case "$fname" in
        *happy*|0[0-4][0-9]-*|0[5-9][0-9]-*) cat="happy_path" ;;
        *error*|1[0-9][0-9]-*) cat="error_path" ;;
        *edge*|2[0-9][0-9]-*) cat="edge_case" ;;
        *rule*|3[0-9][0-9]-*) cat="business_rule" ;;
        *ui*|*affordance*) cat="ui_affordance" ;;
        *empty*) cat="empty_state" ;;
        *i18n*) cat="i18n" ;;
        *) cat="" ;;
      esac
    fi
    case "$cat" in
      happy_path|happy) happy=$((happy + 1)) ;;
      error_path|error) error=$((error + 1)) ;;
      edge_case|edge) edge=$((edge + 1)) ;;
      business_rule|rule) rule=$((rule + 1)) ;;
      ui_affordance|ui) ui=$((ui + 1)) ;;
      empty_state|empty) empty=$((empty + 1)) ;;
      i18n) i18n=$((i18n + 1)) ;;
    esac
  done < <(find "$feature_dir/inputs" -type f \( -name '*.json' -o -name '*.yaml' \) 2>/dev/null)

  if [[ $total -eq 0 ]]; then return 0; fi
  local missing=()
  [[ $error -eq 0 ]] && missing+=("error_path")
  [[ $edge -eq 0 ]] && missing+=("edge_case")
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "corpus distribution thin in $feature: total=$total happy=$happy error=$error edge=$edge rule=$rule ui=$ui — missing categories: ${missing[*]}. Add inputs covering these branches per migration-discipline.md § halt #2 'no entry exists per documented happy path / error path / business rule / edge case'."
  else
    log_pass "corpus distribution: $feature (happy=$happy error=$error edge=$edge rule=$rule ui=$ui i18n=$i18n)"
  fi
  return 0
}

check_tolerance_coverage() {
  # D2 — tolerance.yaml does not cover every contract Outputs field.
  # Parse contract's `## 2. Outputs` section, extract field names,
  # cross-check against tolerance.yaml top-level keys.
  local feature="$1"; local id="${2:-}"
  local contract_file
  contract_file=$(resolve_artifact_path "$CONTRACTS_DIR" "$feature" "$id")
  [[ -z "$contract_file" ]] && return 0
  local roots=("$PARITY_TEST_ROOT_DEFAULT" "tests/parity")
  local tol_file=""
  for r in "${roots[@]}"; do
    if [[ -f "$r/$feature/tolerance.yaml" ]]; then tol_file="$r/$feature/tolerance.yaml"; break; fi
    if [[ -n "$id" && -f "$r/${id}-${feature}/tolerance.yaml" ]]; then tol_file="$r/${id}-${feature}/tolerance.yaml"; break; fi
  done
  [[ -z "$tol_file" ]] && return 0
  # Extract contract output field names: lines under `## 2. Outputs` matching `field:` or `- *field*` or `**field**`.
  # Simple heuristic: grep field-shape patterns inside Outputs section.
  local contract_fields tol_fields
  contract_fields=$(awk '/^## 2\. Outputs/,/^## 3\./' "$contract_file" 2>/dev/null \
    | grep -oE '`[a-z_][a-z0-9_]*`' \
    | tr -d '`' | sort -u)
  tol_fields=$(grep -E '^[a-z_][a-z0-9_]*:' "$tol_file" 2>/dev/null | sed 's/:.*//' | sort -u)
  if [[ -z "$contract_fields" ]] || [[ -z "$tol_fields" ]]; then return 0; fi
  local missing=()
  while IFS= read -r f; do
    if ! echo "$tol_fields" | grep -qx "$f"; then
      missing+=("$f")
    fi
  done <<< "$contract_fields"
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "tolerance.yaml in $feature missing entries for ${#missing[@]} contract Output field(s): ${missing[*]:0:5}${missing[5]:+ ...}. Each contract Output must have a tolerance entry (exact / structural / numeric_tolerance / order_insensitive / ignore). See migration-discipline.md § D2."
  else
    log_pass "tolerance covers contract Outputs: $feature"
  fi
  return 0
}

check_parity_run_v1_commit() {
  # D4 — V1 commit pinned in ledger ≠ commit parity tests ran against.
  # Cross-check ledger's v1_commit_pinned against parity_runs[].v1_commit (latest entry).
  local feature="$1"; local id="${2:-}"
  local ledger_block
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  local pinned latest_run_commit
  pinned=$(echo "$ledger_block" | grep -m1 '^v1_commit_pinned:' | sed 's/^v1_commit_pinned:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  latest_run_commit=$(echo "$ledger_block" | grep -m1 '    v1_commit:' | sed 's/.*v1_commit:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  [[ -z "$pinned" ]] || [[ "$pinned" == "null" ]] && return 0
  [[ -z "$latest_run_commit" ]] && return 0
  # Compare with substring tolerance (full SHA vs short SHA OK)
  if [[ "$pinned" == "$latest_run_commit"* ]] || [[ "$latest_run_commit" == "$pinned"* ]]; then
    log_pass "parity_runs commit matches v1_commit_pinned: $feature"
  else
    log_fail "v1_commit_pinned ($pinned) ≠ latest parity_runs.v1_commit ($latest_run_commit) for $feature — oracle drifted. Re-run parity tests against the pinned commit OR update v1_commit_pinned. See migration-discipline.md § D4."
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

  # Provenance check — F039 + F030 + F032 lesson: prove the audit was produced by an agent,
  # not echoed by an inline executor reading prior summaries. The migration-phase command
  # MANDATES dispatching the parity-auditor agent (or rule-only-mode equivalent for tools
  # without dispatch). The agent's run ID lands in the audit's frontmatter as proof.
  #
  # Accepted forms:
  #   auditor_agent_id: <hex/alphanumeric run ID>             # full-dispatch tools
  #   auditor_agent_id: rule-only-mode/<tool>/<UTC ISO>       # rule-only tools (Aider, Codex, Gemini)
  #
  # Rejected:
  #   missing or empty value
  #   auditor_agent_id: TODO / pending / inline / executor / unknown
  local provenance_line
  provenance_line=$(grep -m1 -E '^auditor_agent_id:' "$file" 2>/dev/null || echo "")
  if [[ -z "$provenance_line" ]]; then
    log_fail "audit missing 'auditor_agent_id' frontmatter field in $file — every audit MUST declare its provenance. See migration-phase.md § 4b. Add: auditor_agent_id: <Agent run ID> OR auditor_agent_id: rule-only-mode/<tool>/<UTC>. Empty/missing = inline-executor verdict (the F039 / Phase-6 trigger) — REFUSED."
    return 1
  fi
  local provenance_value
  provenance_value="${provenance_line#auditor_agent_id:}"
  provenance_value="$(echo "$provenance_value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']*//' -e 's/["'\'']*$//')"
  case "$provenance_value" in
    ""|"TODO"|"todo"|"pending"|"inline"|"executor"|"unknown"|"<"*">")
      log_fail "audit has placeholder 'auditor_agent_id' in $file (value: '$provenance_value') — must be a real agent run ID OR 'rule-only-mode/<tool>/<UTC>'. See migration-phase.md § 4b."
      return 1
      ;;
    *)
      log_pass "audit provenance: $feature ($provenance_value)"
      ;;
  esac
  # Hand-wave detection — F039 + F030 + F032 lesson: "Trusted Summary" anti-pattern
  # Strict patterns that MUST fail the gate (not warn):
  #   - "&..." or trailing "..." in axis tables (hand-waved query params)
  #   - "etc." anywhere in axis tables (incomplete enumeration)
  #   - "20+ filters", "N+ buttons", etc. (count without enumeration)
  #   - "and so on" (the lazy enumerator's fingerprint)
  #   - "deferred to port-phase parity test author" (audit declining to enumerate)
  #   - "by audit-by-inspection" (vibe verdict, not source-line verdict)
  # Hand-wave grep on a SCRUBBED version of the audit:
  # - Strip out fenced code blocks (```...```) — code samples often contain `...`
  # - Strip out inline backtick code spans (`...`) — same reason
  # - Strip out lines containing only the word `None` / `not found` markers
  # This avoids false positives on legitimate code excerpts like
  #   `<FormField :label="$t('...')">`, `style="..."`, `{name: 'builder'...}`.
  local scrubbed_file handwaves
  scrubbed_file=$(mktemp -t audit-scrub.XXXXXX)
  awk '
    BEGIN { in_fence=0 }
    /^```/ { in_fence = 1 - in_fence; next }
    in_fence { next }
    {
      # Drop everything inside backticks: `...` (greedy is fine — single-line)
      gsub(/`[^`]*`/, "")
      print
    }
  ' "$file" > "$scrubbed_file"
  handwaves=$(grep -cE '&\.\.\.|^[[:space:]]*\|.*&\.\.\.|, etc\.| etc\.\)|\.\.\.[[:space:]]*\||\b[0-9]+\+[[:space:]]+(filters?|buttons?|fields?|params?|columns?)\b|\band so on\b|\bdeferred to (port-phase|future) parity\b|\bby audit-by-inspection\b' "$scrubbed_file" 2>/dev/null || echo 0)
  rm -f "$scrubbed_file"
  handwaves=${handwaves:-0}
  [[ "$handwaves" =~ ^[0-9]+$ ]] || handwaves=0
  if [[ $handwaves -gt 0 ]]; then
    log_fail "audit has $handwaves hand-wave(s) in $file — enumerate explicitly per migration-discipline.md anti-pattern \"The Trusted Summary\". Patterns flagged: trailing \"...\", \"&...\", \"etc.\", \"N+ filters/buttons/fields/params\", \"and so on\", \"deferred to port-phase parity author\", \"by audit-by-inspection\". Read V1 source line-by-line and list every item in the axis table."
    return 1
  else
    log_pass "audit enumerates explicitly: $feature"
  fi
  return 0
}

check_audit_freshness() {
  # A4 — Stale audit / oracle drift.
  # If audit_date is older than the most-recent V2 file change, the audit is stale; re-audit required.
  # 7-day SLA: audit must be at most 7 days older than the v2_path's last commit.
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0
  local audit_date
  audit_date=$(grep -m1 -E '^audit_date:' "$file" 2>/dev/null | sed 's/^audit_date:[[:space:]]*//' | tr -d '"' | tr -d "'")
  if [[ -z "$audit_date" ]]; then
    log_warn "audit missing 'audit_date' frontmatter in $feature — cannot check freshness"
    return 0
  fi
  # Read v2_path from ledger
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  # If v2_path contains a glob (`*` / `?`), expand to the parent dir for `git log`
  local glob_path="$v2_path"
  if [[ "$v2_path" == *'*'* ]] || [[ "$v2_path" == *'?'* ]]; then
    glob_path="${v2_path%/*}"
  fi
  # Get last git commit time for v2_path
  local v2_last_commit
  if [[ -f "$glob_path" ]] || [[ -d "$glob_path" ]]; then
    v2_last_commit=$(git log -1 --format=%aI -- "$glob_path" 2>/dev/null || echo "")
  fi
  if [[ -z "$v2_last_commit" ]]; then
    # Informational — git log unreadable for this path is not a quality regression
    [[ $QUIET -eq 0 ]] && echo "  ▸ git log unreadable for $v2_path — skipping freshness check"
    return 0
  fi
  # Compare audit_date to v2_last_commit (epoch seconds)
  # macOS `date -j -f %z` wants `+0000` not `+00:00`; git log returns the colon form.
  local audit_epoch v2_epoch diff_days
  local audit_norm v2_norm
  audit_norm="${audit_date%+*}"
  audit_norm="${audit_norm/Z/}"
  v2_norm="${v2_last_commit/Z/+0000}"
  # Strip colon from timezone offset (last 6 chars: +HH:MM → +HHMM)
  if [[ "$v2_norm" =~ [+-][0-9]{2}:[0-9]{2}$ ]]; then
    v2_norm="${v2_norm:0:${#v2_norm}-3}${v2_norm: -2}"
  fi
  audit_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$audit_norm" +%s 2>/dev/null || date -d "$audit_date" +%s 2>/dev/null || echo 0)
  v2_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$v2_norm" +%s 2>/dev/null || date -d "$v2_last_commit" +%s 2>/dev/null || echo 0)
  if [[ $audit_epoch -eq 0 ]] || [[ $v2_epoch -eq 0 ]]; then
    log_warn "could not parse audit_date or v2 commit time — skipping freshness check"
    return 0
  fi
  if [[ $v2_epoch -gt $audit_epoch ]]; then
    diff_days=$(( (v2_epoch - audit_epoch) / 86400 ))
    if [[ $diff_days -gt 7 ]]; then
      log_fail "audit STALE in $feature: audit_date=$audit_date but $v2_path was last modified $diff_days days later. Re-audit required (7-day SLA per migration-discipline.md § A4 Stale Audit)."
      return 1
    fi
    # Within 7-day SLA — informational only, not a failure (audit was followed by code edits in the same window, expected during active porting)
  fi
  log_pass "audit fresh: $feature"
  return 0
}

check_audit_body_consistency() {
  # A10 — "PASS with caveats" verdict.
  # If audit's Classification declares parity-clean / PASS but body lists open P0/P1/HALT/missing
  # gaps, the verdict contradicts the gaps. This is the F033 first-audit shape.
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0
  # Find Classification line and value
  local classification
  classification=$(awk '/^## Classification/{found=1; next} found && NF{print; exit}' "$file" 2>/dev/null | tr -d '*' | sed 's/^[[:space:]]*//')
  if [[ -z "$classification" ]]; then return 0; fi
  # Only check when classification claims clean
  if ! echo "$classification" | grep -qiE 'parity-?clean|^PASS\b|^pass$'; then
    return 0
  fi
  # Scan body for contradicting gap mentions
  local gap_lines
  gap_lines=$(grep -nE '^\|.*\b(P0|P1)\b|^- *\*?\*?(P0|P1)\b|^### (Gap|G[0-9]+)|HALT|silent[ -]break|missing affordance|missing in v2|silent regression|MISSING\s|\*\*Severity\*\*:[[:space:]]*P[01]' "$file" 2>/dev/null | head -10)
  if [[ -n "$gap_lines" ]]; then
    # Allow if classification explicitly says "after fix" / "post-fix" / "→ parity-clean" / mentions remediation
    if echo "$classification" | grep -qiE 'after fix|after fixes|post-fix|\(post-fix\)|RESOLVED|\(resolved\)|all .* gaps closed|→[[:space:]]*parity-clean'; then
      log_pass "audit body consistent: $feature (classification acknowledges remediation)"
      return 0
    fi
    log_fail "audit BODY CONTRADICTS verdict in $feature: classification='$classification' but body lists open gaps:
$(echo "$gap_lines" | head -5 | sed 's/^/    /')
Either downgrade the classification to 'divergent'/'failed' OR close the gaps OR mark as 'after fix' once resolved. See migration-discipline.md § A10 PASS-with-caveats."
    return 1
  fi
  log_pass "audit body consistent: $feature"
  return 0
}

check_intentional_break_adr() {
  # A9 — Audit silently classifies as "intentional-break" without ADR.
  # If classification mentions "intentional-break", an ADR-NNN reference must exist and resolve.
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0
  # Match positive declarations only ("Classification: intentional-break"), not negations like
  # "No intentional breaks" or "no intentional-break detected"
  if ! grep -qiE '(classification|verdict|status|decision)[^a-z]*intentional[- ]break|^.*intentional[- ]break.*\(ADR-' "$file"; then return 0; fi
  # Skip if every match is preceded by "no " or "not "
  if grep -iE 'intentional[- ]break' "$file" | grep -qvE '^[[:space:]]*[Nn]o[ts]?\b|negation|absent|missing'; then
    : # at least one match is a positive declaration — proceed to ADR check
  else
    return 0
  fi
  # Find ADR-NNN references
  local adr_refs
  adr_refs=$(grep -oE 'ADR-[0-9]{3,4}' "$file" 2>/dev/null | sort -u)
  if [[ -z "$adr_refs" ]]; then
    log_fail "audit declares intentional-break in $feature but no ADR-NNN reference present. Author the ADR under ai/decisions/ and cite it. See migration-discipline.md § A9."
    return 1
  fi
  # Verify each ADR exists
  local missing_adrs=()
  for adr in $adr_refs; do
    local adr_file adr_num
    # Strip "ADR-" prefix to get the bare number (e.g. ADR-002 → 002).
    # ADR files are typically named NNN-<slug>.md (no ADR- prefix in filename).
    adr_num="${adr#ADR-}"
    adr_file=$(find ai/decisions -maxdepth 2 -type f \( -name "${adr}-*.md" -o -name "${adr_num}-*.md" \) 2>/dev/null | head -1)
    if [[ -z "$adr_file" ]]; then missing_adrs+=("$adr"); fi
  done
  if [[ ${#missing_adrs[@]} -gt 0 ]]; then
    log_fail "audit cites missing ADR(s) in $feature: ${missing_adrs[*]} — files not found under ai/decisions/"
    return 1
  fi
  log_pass "intentional-break ADR resolves: $feature ($adr_refs)"
  return 0
}

check_v1_path_drift_acknowledged() {
  # F054-class — audit body self-flags that v1_path is wrong but the row advanced anyway.
  # If the audit contains markers like "v1_path must be corrected" / "ledger-drift" /
  # "wrong V1 oracle" / "Halt 7 (v1_path drift)" without a paired RESOLVED / CORRECTED /
  # re-audit marker, the row cannot legitimately be `done` — the comparison was made
  # against the wrong V1 source.
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0
  # Markers that flag v1_path drift
  local drift_markers='v1_path must be corrected|ledger-drift finding|wrong V1 oracle|audited the wrong V1|Halt [0-9]+ \(v1_path|v1_path[[:space:]]+lists.*dead'
  if ! grep -qiE "$drift_markers" "$file"; then
    return 0
  fi
  # Drift is acknowledged. Now check for a paired resolution marker.
  local resolution_markers='RESOLVED|CORRECTED|re-audited|re-audit (against|completed)|v1_path[[:space:]]+now[[:space:]]+correct|drift[[:space:]]+resolved|Halt [0-9]+.*RESOLVED'
  if grep -qiE "$resolution_markers" "$file"; then
    log_pass "v1_path drift acknowledged + resolved: $feature"
    return 0
  fi
  log_fail "audit in $feature self-acknowledges v1_path drift but no resolution marker present. The audit was run against the wrong V1 source. Re-audit against the corrected v1_path before the row can advance to done. (Markers: 'RESOLVED' / 'CORRECTED' / 're-audited' must appear once the re-audit completes.)"
  return 1
}

check_porter_vs_auditor() {
  # A5 — Audit author = port author (no second-eyes).
  # Ledger row's porter_agent_id must differ from audit's auditor_agent_id.
  # Currently a soft warn until porter_agent_id is uniformly populated.
  local feature="$1"; local id="${2:-}"
  local audit_file
  audit_file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$audit_file" ]] && return 0
  local auditor_id porter_id
  auditor_id=$(grep -m1 -E '^auditor_agent_id:' "$audit_file" | sed 's/^auditor_agent_id:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  local ledger_block
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  porter_id=$(echo "$ledger_block" | grep -m1 '^porter_agent_id:' | sed 's/^porter_agent_id:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  if [[ -z "$porter_id" ]]; then
    # Soft warn until ledger field is widely populated
    return 0
  fi
  if [[ "$auditor_id" == "$porter_id" ]]; then
    log_fail "audit/port author identity collision in $feature: porter_agent_id == auditor_agent_id ($porter_id) — second-eyes required. Dispatch a different agent for the audit step."
    return 1
  fi
  log_pass "audit/port second-eyes: $feature"
  return 0
}

check_v2_structure() {
  # Anti-Transposition-Trap check (per migration-discipline.md § Anti-patterns).
  # The port must follow V2's NEW structure, not lift V1 verbatim. This function greps
  # the feature's V2 implementation files for known V1-copy-paste fingerprints and HALTs
  # if any are found.
  #
  # Reads the ledger row's `v2_path:` field to know where to scan. If multiple V2 files,
  # globs the directory. Skips if v2_path is missing/null.
  local feature="$1"; local id="${2:-}"
  local ledger_block
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  local v2_path
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//')
  if [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]]; then
    log_warn "v2_path not declared in ledger for $feature — skipping V2 structure check"
    return 0
  fi
  # v2_path may have descriptive parens: take the first path token
  v2_path=$(echo "$v2_path" | awk '{print $1}')
  # Resolve the file or directory; if it's a single .vue/.ts file, scan it directly;
  # if it's a directory or a path with " + " annotations, scan the parent module dir.
  local scan_targets=()
  if [[ -f "$v2_path" ]]; then
    scan_targets=("$v2_path")
  elif [[ -d "$v2_path" ]]; then
    while IFS= read -r f; do scan_targets+=("$f"); done < <(find "$v2_path" -type f \( -name '*.vue' -o -name '*.ts' \) 2>/dev/null)
  else
    # Try parent module dir as fallback
    local parent
    parent="$(dirname "$v2_path")"
    if [[ -d "$parent" ]]; then
      while IFS= read -r f; do scan_targets+=("$f"); done < <(find "$parent" -maxdepth 2 -type f \( -name '*.vue' -o -name '*.ts' \) 2>/dev/null)
    fi
  fi
  if [[ ${#scan_targets[@]} -eq 0 ]]; then
    log_warn "no V2 files found at $v2_path for $feature — skipping V2 structure check"
    return 0
  fi

  # Forbidden V1-pattern fingerprints. Each is a "transposition" tell: the executor
  # copy-pasted V1 instead of using the V2 shared-component / convention.
  #
  # Stack-conditional dispatch — frontend fingerprints don't run on backend code (and vice versa).
  # PROJECT_KIND is set by load_project_anchors() from ai/migration/_v2-anchors.md.
  #
  # Pattern format: "regex|severity|message"
  local fingerprints=()
  case "$PROJECT_KIND" in
    frontend-vue3|frontend-react|frontend-svelte|frontend-nuxt)
      fingerprints+=(
        # Raw PrimeVue / framework components in pages — V2 has wrappers
        '<Dialog\b|fail|raw <Dialog> in V2 — use <BaseModal> per .claude/rules/components.md'
    '<Paginator\b|fail|raw <Paginator> in V2 — use <CrudPaginator>'
    '<Calendar\b|warn|raw <Calendar> in V2 — prefer <DatePicker> wrapper'
    # FormField label double-translation (the OrderEditDialog bug) — handled by check_form_field_label_t below; keep here as no-op marker
    '__SKIP__formfield_label_t|warn|placeholder — see check_form_field_label_t awk pass'
    # Wrapper col around FormField (the OrderEditDialog grid-break bug)
    '<div class="col-(md|sm|lg|xl)-[0-9]+[^>]*>\s*<FormField|fail|wrapper <div class="col-*"> around <FormField> — FormField has its own col-class prop, no wrapper needed'
    # Hand-rolled phone field (the OrderEditDialog phone-row bug)
    'phone-row|warn|hand-rolled phone-row container — use shared <PhoneInput> with code-readonly mode'
    # Tenant leak: token + raw localStorage outside secureStorage
    'localStorage\.(get|set)Item.*[Tt]oken|fail|tenant leak: localStorage for token — use @/core/utils/secureStorage'
    # axios.create outside the canonical clients
    'axios\.create\(|fail|axios.create — only ONE authenticated client (apiClient); never per-feature'
    # Inline style attribute (negative-leading-char to skip Vue's :style="{...}" reactive binding which is legitimate)
    '(^|[^:])style="[^"]+"|warn|inline style — use scoped SCSS + design tokens'
    # console.log left in production code
    'console\.(log|debug)\(|fail|console.log/debug in production code — ESLint forbids'
    # Manual Authorization headers (bypasses interceptor + refresh queue)
    "Authorization.*Bearer|fail|manual Authorization header — apiClient interceptor injects token"
    # Raw <form> outside BaseForm in dialog/page contexts
    '<form\s+[^>]*@submit|warn|raw <form> with @submit — use <BaseForm> wrapper'
    # B4 — Layering: page imports apiClient directly (route through services)
    "from\\s+['\"]@/core/api/apiClient['\"]|fail|page/component imports apiClient directly — clean-architecture violation. Route through a service under modules/<m>/services/."
    # B4 — Layering: composable imports a Vue component
    "from\\s+['\"][./]+(components|pages)/[A-Z][^'\"]+\\.vue['\"]|fail|composable imports a Vue component — composables stay framework-agnostic; reverse the dependency."
    # C8 — RTL: physical margin/padding-(left|right) properties
    "(margin|padding)-(left|right):[[:space:]]*[0-9]|fail|physical margin/padding-(left|right) — RTL break risk; use logical properties (margin-inline-start/end) or RTL mixins."
    # E2 — localStorage.setItem outside secureStorage (warns; non-token are easy false positives)
    "localStorage\\.setItem\\(|warn|localStorage.setItem — if storing tenant-scoped data, use secureStorage; if not, document in an allow-list. Survives logout otherwise."
    # ─── Phase 7 lessons (<frontend-v2> themes F054/F055/F056) ───────────────
    # I18N-1: Hardcoded { en: '', ar: '' } translation literal — assumes 2 languages forever
    "\\{[[:space:]]*en:[[:space:]]*['\"][^'\"]*['\"][[:space:]]*,[[:space:]]*ar:[[:space:]]*['\"]|fail|hardcoded { en, ar } translation literal — use useLanguages().buildEmptyTranslations(); tenants can enable any language"
    "\\{[[:space:]]*ar:[[:space:]]*['\"][^'\"]*['\"][[:space:]]*,[[:space:]]*en:[[:space:]]*['\"]|fail|hardcoded { ar, en } translation literal — use useLanguages().buildEmptyTranslations(); tenants can enable any language"
    # I18N-2: locale.value === 'en' ? 'en' : 'ar' ternary — reduces N languages to 2
    "locale\\.value[[:space:]]*===[[:space:]]*['\"]en['\"][[:space:]]*\\?[[:space:]]*['\"]en['\"][[:space:]]*:[[:space:]]*['\"]ar['\"]|fail|locale.value === 'en' ? 'en' : 'ar' ternary — use ref(locale.value) directly; supports any tenant language"
    # I18N-3: Flat name_ar/name_en/description_ar/description_en reactive fields — V1 transposition
    "(name|description|title|label)_(ar|en):[[:space:]]*['\"]['\"]|fail|flat *_ar / *_en field — use Translations (Record<string,string>) + useLanguages().buildEmptyTranslations()"
    # UI-1: Raw <input type="file"> in pages — should use ImageUploader
    '<input[^>]+type="file"|warn|raw <input type="file"> — use <ImageUploader> wrapper for image uploads'
    # UI-2: Raw <InputSwitch> in dialog forms (table-cell usage is fine; this catches dialogs/forms)
    # Heuristic: <InputSwitch> in same file as <BaseModal> or <Dialog>
    # Handled by check_status_switch_in_form awk pass below
    # ─── Phase 9 lessons (<frontend-v2> themes May 2026) ─────────────────────
    # UI-3: Silent catch swallow — hides API failures, makes empty UI indistinguishable from errors
    "catch[[:space:]]*\\{[[:space:]]*/[/*][^/]*(silent|ignore|fail[[:space:]]+silent)|fail|silent catch — surface errors via handleApiError(); empty UI must be distinguishable from API failure"
    "catch[[:space:]]*\\{[[:space:]]*\\}|warn|empty catch block — at minimum log; prefer handleApiError(err) so failures don't disappear"
    # UI-4: PriceInput reinvention — custom currency-symbol CSS in a file that doesn't import PriceInput
    "p-inputgroup-addon|warn|p-inputgroup-addon for currency — use <PriceInput> wrapper which handles tenant currency from token summary"
    "(price-currency|currency-symbol|currency-prefix|currency-addon):[[:space:]]*\\{|warn|custom currency-symbol CSS class — use <PriceInput> shared component"
    # UI-5: <StatusSwitch> nested inside <FormField> — StatusSwitch has its own label, causes double-label
    # Handled by check_status_switch_nested_in_form_field awk pass below
    "__SKIP__statusswitch_in_formfield|warn|placeholder — see check_status_switch_nested_in_form_field awk pass"
    # UI-6: Hand-rolled language toggle (segmented control) instead of <TranslatedInput> + <DialogLanguageSwitcher>
    "(segmented-control|premium-segmented-control|lang-toggle-btn|name-lang-toggle):[[:space:]]*\\{|fail|hand-rolled language toggle — use <TranslatedInput> (delegates to <DialogLanguageSwitcher>) which builds buttons from useLanguages()"
    # UI-7: !important on Button background/color — fragile specificity war with PrimeVue
    'background[^;]*!important|warn|!important on background — scoped CSS does not pierce PrimeVue Button host; use plain <button> or :deep(.p-button-label) for the inner span'
    # UI-8: scoped :deep() on host class — descendant selector that never matches the host element
    ':deep\([^)]+\.p-button\)|warn|:deep(.foo.p-button) is a descendant selector and cannot match the Button host. Use plain <button>, or :deep(.p-button-label) for inner spans only.'
      )
      ;;
    backend-nest|backend-laravel|backend-python|api-other)
      fingerprints+=(
        # B7 — Backend hexagonal: @Injectable() in domain/ — domain must be framework-free
        "@Injectable\\(\\)|fail|@Injectable() in a domain/ file — domain layer must be framework-agnostic. Move to application/ or infrastructure/."
        # B7 — Backend: application service imports from infrastructure (boundary violation)
        "from\\s+['\"][^'\"]*infrastructure/[^'\"]+['\"]|fail|application-layer file imports from infrastructure/ — hexagonal boundary violation. Use a port (interface) and let DI inject the adapter."
        # B7 — Backend: controller imports repository directly (should go through application service)
        "from\\s+['\"][^'\"]*\\.repository['\"]|warn|controller imports repository directly — should route through application service / command handler."
        # E5 — Backend: console.log left in production code
        'console\.(log|debug)\(|fail|console.log/debug in backend code — use the project logger.'
        # B8 — Backend transaction-script: long methods with await chain in service files
        # (Heuristic only; covered by manual review for now)
        # B9 — DTO drift: Response shape declared without test coverage
        # (Covered by parity test contract assertions)
      )
      ;;
    *)
      # Unknown project kind — no fingerprints; rely on universal checks.
      :
      ;;
  esac

  local file_failures=0 file_warnings=0
  for file in "${scan_targets[@]}"; do
    # Allowlist: the canonical HTTP client + tokenProvider are EXEMPT from the
    # `axios.create` and `Authorization: Bearer` fingerprints — they are the
    # source-of-truth implementations those fingerprints point developers AWAY from
    # using elsewhere. Per .claude/rules/api-types.md "HTTP clients (single source)".
    local is_canonical_client=0
    local is_html_emitter=0
    local is_canonical_consumer=0
    case "$file" in
      */core/api/apiClient.ts|*/core/api/publicClient.ts|*/core/api/tokenProvider.ts|*/core/utils/secureStorage.ts)
        is_canonical_client=1
        ;;
      */helpers/sections/*.ts|*/helpers/HTMLThemes/*.ts|*/helper/sections/*.ts|*/helper/HTMLThemes/*.ts|*/helpers/sections/html/*.ts|*/helper/builder/sections/*.ts|*/helper/builder/HTMLThemes/*.ts)
        # HTML-emitter helper files: these legitimately produce HTML strings
        # with style="..." attributes for GrapesJS / page-builder consumption.
        # The "inline style" smell does not apply — they are not Vue components.
        is_html_emitter=1
        ;;
      */core/services/BaseCrudService.ts|*/store/modules/*.ts|*/stores/modules/*.ts|*/store/*.ts)
        # Canonical apiClient consumers — exempt from the page/component layering check.
        # BaseCrudService IS the canonical CRUD service (it MUST import apiClient).
        # Pinia stores (auth/appConfig/permissions) are exempt because the architecture's
        # Pinia-store layer is a legitimate apiClient consumer for global app state
        # (maintenance mode, languages, currencies, themes, permissions).
        is_canonical_consumer=1
        ;;
    esac
    for fp in "${fingerprints[@]}"; do
      IFS='|' read -r pattern severity message <<< "$fp"
      # Skip placeholder fingerprints handled by dedicated awk passes below
      if [[ "$pattern" == __SKIP__* ]]; then continue; fi
      # Allowlist exemptions for the canonical client
      if [[ $is_canonical_client -eq 1 ]]; then
        case "$pattern" in
          *axios*create*|*Authorization*Bearer*|*localStorage*) continue ;;
        esac
      fi
      # Allowlist exemption for HTML-emitter helpers (page-builder sections + themes)
      if [[ $is_html_emitter -eq 1 ]]; then
        case "$pattern" in
          *style*) continue ;;
        esac
      fi
      # Allowlist exemption for canonical apiClient consumers (BaseCrudService + Pinia stores)
      if [[ $is_canonical_consumer -eq 1 ]]; then
        case "$pattern" in
          *apiClient*) continue ;;
        esac
      fi
      local hits
      hits=$(grep -cE "$pattern" "$file" 2>/dev/null | head -1 | tr -d ' \n' || echo 0)
      hits=${hits:-0}
      if [[ $hits -gt 0 ]]; then
        if [[ "$severity" == "fail" ]]; then
          log_fail "V2-structure violation in $file ($hits): $message"
          file_failures=$((file_failures + 1))
        else
          log_warn "V2-structure smell in $file ($hits): $message"
          file_warnings=$((file_warnings + 1))
        fi
      fi
    done
    # Multi-line check: FormField/TranslatedInput with :label="$t(...)" — double-translation bug.
    # Awk state machine: when we enter a <FormField or <TranslatedInput tag, watch the next
    # ~10 lines (until we hit the closing > of the opening tag) for :label="$t(.
    local form_label_hits
    form_label_hits=$(awk '
      BEGIN { in_tag = 0; hits = 0 }
      /<(FormField|TranslatedInput)\b/ { in_tag = 1 }
      in_tag && /:label="\$t\(/ { hits++ }
      in_tag && /\/?>[[:space:]]*$/ { in_tag = 0 }
      END { print hits }
    ' "$file" 2>/dev/null)
    form_label_hits=${form_label_hits:-0}
    if [[ $form_label_hits -gt 0 ]]; then
      log_fail "V2-structure violation in $file ($form_label_hits): <FormField>/<TranslatedInput> :label=\"\$t(...)\" — FormField calls \$t internally; pass bare key string (per CLAUDE.md \"Label Conventions\")"
      file_failures=$((file_failures + 1))
    fi
    # Phase 9 multi-line check: <StatusSwitch> nested inside <FormField> — double-label bug.
    # StatusSwitch renders its own label internally; wrapping in FormField (which also renders one)
    # produces "Status [toggle]" inside "Free" → both labels visible at once.
    local statusswitch_in_ff
    statusswitch_in_ff=$(awk '
      BEGIN { depth = 0; hits = 0 }
      /<FormField\b/ { depth++ }
      depth > 0 && /<StatusSwitch\b/ { hits++ }
      /<\/FormField>/ { if (depth > 0) depth-- }
      END { print hits }
    ' "$file" 2>/dev/null)
    statusswitch_in_ff=${statusswitch_in_ff:-0}
    if [[ $statusswitch_in_ff -gt 0 ]]; then
      log_fail "V2-structure violation in $file ($statusswitch_in_ff): <StatusSwitch> nested inside <FormField> — StatusSwitch has its own label; either pass label prop directly to StatusSwitch or use raw <InputSwitch> inside FormField"
      file_failures=$((file_failures + 1))
    fi
    # Phase 9 multi-line check: nested-child component using onActivated() WITHOUT onMounted().
    # onActivated() only fires for components inside <KeepAlive>; nested children rendered via v-if/v-for
    # in a parent are NOT inside KeepAlive directly, so onActivated never fires → dead code, no fetch.
    # Exempts page-level components (file matches *Page.vue) which ARE the keep-alived route component.
    case "$file" in
      */pages/*Page.vue|*/pages/*.vue)
        # Page-level — onActivated alone is correct
        ;;
      *)
        local on_act on_mount
        on_act=$(grep -c 'onActivated\s*(' "$file" 2>/dev/null | head -1 | tr -d ' \n')
        on_mount=$(grep -c 'onMounted\s*(' "$file" 2>/dev/null | head -1 | tr -d ' \n')
        on_act=${on_act:-0}; on_mount=${on_mount:-0}
        if [[ $on_act -gt 0 ]] && [[ $on_mount -eq 0 ]]; then
          log_fail "V2-structure violation in $file: nested-child component uses onActivated() without onMounted() — onActivated does not fire for non-route components. Use onMounted (CLAUDE.md: 'nested children use BOTH onMounted AND onActivated')"
          file_failures=$((file_failures + 1))
        fi
        ;;
    esac
  done
  if [[ $file_failures -eq 0 ]] && [[ $file_warnings -eq 0 ]]; then
    log_pass "V2 structure clean: $feature (${#scan_targets[@]} file(s) scanned)"
  fi
  if [[ $file_failures -gt 0 ]]; then
    return 1
  fi
  return 0
}

check_composable_reuse() {
  # B2 — Composable reuse miss: V2 page hand-rolls list/pagination/filter state instead of using useCrud.
  # Heuristic: any *Page.vue with reactive({ ... items: [] ... } + page: 1 + perPage: ... + total: ...)
  # without an `import.*useCrud` line.
  local feature="$1"; local id="${2:-}"
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  # Find pages/*.vue files
  local page_files=()
  if [[ -f "$v2_path" ]] && [[ "$v2_path" == *Page.vue ]]; then
    page_files=("$v2_path")
  elif [[ -d "$(dirname "$v2_path")" ]]; then
    while IFS= read -r f; do page_files+=("$f"); done < <(find "$(dirname "$v2_path")" -name '*Page.vue' 2>/dev/null)
  fi
  [[ ${#page_files[@]} -eq 0 ]] && return 0
  for file in "${page_files[@]}"; do
    [[ -f "$file" ]] || continue
    if grep -qE 'items:\s*\[\]' "$file" 2>/dev/null && \
       grep -qE 'page:\s*1' "$file" 2>/dev/null && \
       ! grep -qE "import.*\\b(useCrud|useTable)\\b" "$file" 2>/dev/null; then
      log_warn "composable reuse miss in $file: open-coded list/pagination state without useCrud/useTable import. See ai/patterns/composables.md."
    fi
  done
  return 0
}

check_service_shape() {
  # B3 — Service shape: services/index.ts should use BaseCrudService for standard CRUD.
  # Heuristic: services/index.ts that has multiple async functions calling apiClient.get/.post/.put/.delete
  # for the SAME url group, but no `new BaseCrudService` instantiation, signals a hand-rolled CRUD service.
  local feature="$1"; local id="${2:-}"
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  # Find module's services/index.ts
  local module_dir
  if [[ -f "$v2_path" ]]; then
    module_dir=$(dirname "$(dirname "$v2_path")")
  else
    module_dir="$v2_path"
  fi
  local svc_file="$module_dir/services/index.ts"
  [[ ! -f "$svc_file" ]] && return 0
  local crud_count base_count
  crud_count=$(grep -cE 'apiClient\.(get|post|put|delete|patch)' "$svc_file" 2>/dev/null | head -1 | tr -d ' \n')
  crud_count=${crud_count:-0}
  base_count=$(grep -cE 'new BaseCrudService' "$svc_file" 2>/dev/null | head -1 | tr -d ' \n')
  base_count=${base_count:-0}
  # Exempt: services with explicit non-CRUD comment marker
  if grep -qE '^//[[:space:]]*validator-exempt:[[:space:]]*non-crud-service' "$svc_file" 2>/dev/null; then
    return 0
  fi
  # Exempt: services where the dominant call shape is non-CRUD (e.g. specialized endpoints
  # like purchase, marketplace ops, builder integration that don't fit BaseCrudService<T,Create,Update>).
  # Heuristic: if the service has standard CRUD method names (create/update/delete/getById/getAll
  # exported from the service object), suggest BaseCrudService. Otherwise the service is intentionally
  # custom-shaped and the warning is noise.
  local has_crud_names
  has_crud_names=$(grep -cE '^[[:space:]]*async (create|update|delete|getById|getAll)\b' "$svc_file" 2>/dev/null | head -1 | tr -d ' \n')
  has_crud_names=${has_crud_names:-0}
  if [[ $crud_count -gt 4 ]] && [[ $base_count -eq 0 ]] && [[ $has_crud_names -gt 0 ]]; then
    log_warn "service shape in $svc_file: $crud_count direct apiClient calls, 0 BaseCrudService instances — likely hand-rolled CRUD that BaseCrudService<T,Create,Update> would replace. See ai/decisions/002-base-crud-service.md."
  fi
  return 0
}

check_cross_module_import() {
  # B5 — Cross-module import: src/modules/A/* imports from src/modules/B/*.
  local feature="$1"; local id="${2:-}"
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  # Determine THIS module name from v2_path
  local this_module
  this_module=$(echo "$v2_path" | sed -nE 's|.*src/modules/([^/]+)/.*|\1|p')
  [[ -z "$this_module" ]] && return 0
  local module_dir="src/modules/$this_module"
  [[ ! -d "$module_dir" ]] && return 0
  # Find any import from another module.
  # NOTE: BSD grep -E does NOT support Perl negative lookahead `(?!...)`. We match
  # ANY cross-module import then filter out same-module hits in awk — portable
  # across BSD (macOS) and GNU greps.
  local violations
  violations=$(grep -rEn "from[[:space:]]+['\"]@?/?(src/)?modules/[a-zA-Z0-9_-]+" "$module_dir" --include='*.vue' --include='*.ts' 2>/dev/null \
    | awk -v this="$this_module" -F"modules/" '{ split($2, a, /[\/'"'"'"\b]/); if (a[1] != this) print }' \
    | head -5)
  if [[ -n "$violations" ]]; then
    log_warn "cross-module import in $this_module:
$(echo "$violations" | sed 's/^/    /')
Move shared code to src/shared/ per .claude/rules/clean-architecture.md § Cross-Module Rules."
  fi
  return 0
}

check_i18n_locale_parity() {
  # B6 — i18n: every key in en.ts must exist in ar.ts (and any other declared locale).
  # Scoped to module's locales/ directory (per-module, not global).
  local feature="$1"; local id="${2:-}"
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  local this_module
  this_module=$(echo "$v2_path" | sed -nE 's|.*src/modules/([^/]+)/.*|\1|p')
  [[ -z "$this_module" ]] && return 0
  local locales_dir="src/modules/$this_module/locales"
  [[ ! -d "$locales_dir" ]] && return 0
  local en_file="$locales_dir/en.ts" ar_file="$locales_dir/ar.ts"
  [[ ! -f "$en_file" ]] || [[ ! -f "$ar_file" ]] && return 0
  # Extract leaf keys (lines like `    keyName:` or `    'key.name':`) — leaf identifier match
  local en_keys ar_keys
  en_keys=$(grep -oE '^\s*[a-zA-Z_][a-zA-Z0-9_]*:' "$en_file" 2>/dev/null | sed 's/[: ]//g' | sort -u)
  ar_keys=$(grep -oE '^\s*[a-zA-Z_][a-zA-Z0-9_]*:' "$ar_file" 2>/dev/null | sed 's/[: ]//g' | sort -u)
  local en_count ar_count diff_count
  en_count=$(echo "$en_keys" | wc -l | tr -d ' ')
  ar_count=$(echo "$ar_keys" | wc -l | tr -d ' ')
  diff_count=$(comm -23 <(echo "$en_keys") <(echo "$ar_keys") | wc -l | tr -d ' ')
  if [[ $diff_count -gt 0 ]]; then
    local sample
    sample=$(comm -23 <(echo "$en_keys") <(echo "$ar_keys") | head -3 | tr '\n' ',' | sed 's/,$//')
    log_warn "i18n drift in $this_module: $diff_count key(s) in en.ts missing from ar.ts (sample: $sample). Run /i18n-audit."
  fi
  return 0
}

check_lifecycle_keepalive() {
  # C6 — Reactive lifecycle: pages cached under <KeepAlive> must use onActivated, not onMounted.
  # Skip pages on the noCache exclude list.
  local feature="$1"; local id="${2:-}"
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  # Skip the whole check if the project hasn't anchored a KeepAlive layout
  # (i.e., the project doesn't use KeepAlive, OR the anchor was never set)
  if [[ -z "$KEEPALIVE_LAYOUT" ]] || [[ ! -f "$KEEPALIVE_LAYOUT" ]]; then
    return 0
  fi
  # Extract the exclude list (e.g. `noCache = ['BuilderPage', 'OtherPage']`) from the layout file
  local exclude_var="${KEEPALIVE_EXCLUDE_VAR:-noCache}"
  local nocache_list
  nocache_list=$(grep -oE "${exclude_var}[[:space:]]*=[[:space:]]*\[[^]]+\]" "$KEEPALIVE_LAYOUT" | grep -oE "'[A-Z][^']+'" | tr -d "'")
  [[ "${DEBUG_VALIDATOR:-0}" -eq 1 ]] && echo "DEBUG nocache_list=[$nocache_list] layout=$KEEPALIVE_LAYOUT" >&2
  local page_files=()
  if [[ -f "$v2_path" ]] && [[ "$v2_path" == *Page.vue ]]; then
    page_files=("$v2_path")
  elif [[ -d "$(dirname "$v2_path")" ]]; then
    while IFS= read -r f; do page_files+=("$f"); done < <(find "$(dirname "$v2_path")" -name '*Page.vue' 2>/dev/null)
  fi
  [[ ${#page_files[@]} -eq 0 ]] && return 0
  for file in "${page_files[@]}"; do
    [[ -f "$file" ]] || continue
    local fname
    fname=$(basename "$file" .vue)
    # Skip if in noCache list
    if echo "$nocache_list" | grep -qx "$fname"; then continue; fi
    # Page must use onActivated for data-fetch on entry; onMounted alone is the bug.
    local has_mounted has_activated
    has_mounted=$(grep -cE '\bonMounted\(' "$file" 2>/dev/null | head -1 | tr -d ' \n')
    has_activated=$(grep -cE '\bonActivated\(' "$file" 2>/dev/null | head -1 | tr -d ' \n')
    has_mounted=${has_mounted:-0}; has_activated=${has_activated:-0}
    if [[ $has_mounted -gt 0 ]] && [[ $has_activated -eq 0 ]]; then
      log_warn "lifecycle in $file: uses onMounted but not onActivated. KeepAlive caches this page; data goes stale on tab return / tenant switch. Use onActivated for data fetch (or both for nested children). See <frontend-v2>/CLAUDE.md § Lifecycle."
    fi
  done
  return 0
}

check_permission_gate_divergence() {
  # C2 — Permission-gate divergence: if audit's frontend-axes table contains a
  # "Per-button permission gates" row whose verdict says match/Match/MATCH but the cells
  # show V1 ungated and V2 gated (or vice versa), halt — verdict contradicts cells.
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0
  # Extract lines from the Frontend axes section (or Per-axis comparison) that look like
  # | Per-button permission gate | V1 ... | V2 ... | match |
  local rows
  rows=$(grep -niE '^\|[^|]*\bpermission\b[^|]*gate[^|]*\|' "$file" 2>/dev/null)
  [[ -z "$rows" ]] && return 0
  # For each row, compare V1 cell vs V2 cell. If verdict says match but contents differ on "ungated"/"none" vs "hasPermission", flag.
  local violations=0
  while IFS= read -r row; do
    # Remove leading line number
    local line="${row#*:}"
    # Split by |
    IFS='|' read -ra cells <<< "$line"
    [[ ${#cells[@]} -lt 4 ]] && continue
    local v1="${cells[2]}" v2="${cells[3]}"
    local verdict="${cells[4]:-${cells[3]}}"
    # Heuristic: V1 says "none"/"ungated"/"no" and V2 says "hasPermission"/"v-if" (or vice versa)
    local v1_ungated=0 v2_ungated=0
    if echo "$v1" | grep -qiE '\bnone\b|\bno\b|\bungated\b|0 gate|zero gate'; then v1_ungated=1; fi
    if echo "$v2" | grep -qiE '\bnone\b|\bno\b|\bungated\b|0 gate|zero gate'; then v2_ungated=1; fi
    local v1_gated=0 v2_gated=0
    if echo "$v1" | grep -qiE 'hasPermission|v-if=|orders\.[a-z]+'; then v1_gated=1; fi
    if echo "$v2" | grep -qiE 'hasPermission|v-if=|orders\.[a-z]+'; then v2_gated=1; fi
    if [[ $((v1_ungated + v2_gated)) -eq 2 ]] || [[ $((v1_gated + v2_ungated)) -eq 2 ]]; then
      if echo "$verdict" | grep -qiE 'match'; then
        log_fail "permission-gate divergence in $file: row '$row' — V1 cell='$(echo "$v1" | xargs)' V2 cell='$(echo "$v2" | xargs)' verdict says 'match' but gates differ. Either downgrade verdict OR document divergence as ADR-cited intentional break. See migration-discipline.md § C2."
        violations=$((violations + 1))
      fi
    fi
  done <<< "$rows"
  if [[ $violations -gt 0 ]]; then return 1; fi
  log_pass "permission gates consistent: $feature"
  return 0
}

check_api_response_sample() {
  # Phase 9 lesson (<frontend-v2> themes May 2026 — F045-F056): the V2 type
  # was authored from V1 caller code (which read response fields untyped); when V1's
  # API silently returned `{ id, label }` while V2 typed `{ id, name }`, the dropdown
  # rendered 22 empty rows. The audit had no way to catch this — there was no
  # captured API response sample to validate the type against.
  #
  # Required artifact: ai/migration/api-samples/<feature>.json (or .ndjson for streams)
  # — a real captured response from the V1 endpoint, used to derive AND validate the V2 type.
  # Required for any feature whose v2_path includes a /services/ file (i.e., the port
  # touches an API call). Skipped for pure-UI ports (page-only changes, no service edits).
  local feature="$1"; local id="${2:-}"
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  # Heuristic: only require API sample if the port touches a service file.
  local touches_service=0
  if [[ -d "$v2_path" ]]; then
    if find "$v2_path" -name "*.ts" -path "*/services/*" 2>/dev/null | grep -q .; then
      touches_service=1
    fi
  elif [[ -f "$v2_path" ]] && [[ "$v2_path" == */services/* ]]; then
    touches_service=1
  fi
  [[ $touches_service -eq 0 ]] && return 0
  # Sample dir lives under a configurable path; default ai/migration/api-samples/<feature>/
  local samples_dir="ai/migration/api-samples/${feature}"
  if [[ ! -d "$samples_dir" ]]; then
    log_fail "missing API response samples for $feature: expected ${samples_dir}/ with at least one .json capture per endpoint the service calls. Required because the port touches a /services/ file. See migration-discipline.md § The Guessed Type."
    return 1
  fi
  local sample_count
  sample_count=$(find "$samples_dir" -type f \( -name "*.json" -o -name "*.ndjson" \) 2>/dev/null | wc -l | tr -d ' ')
  if [[ $sample_count -eq 0 ]]; then
    log_fail "API samples dir exists but is empty for $feature ($samples_dir/) — capture at least one real response per endpoint to derive the V2 type from."
    return 1
  fi
  log_pass "API response samples present: $feature ($sample_count file(s))"
  return 0
}

check_v2_mapping_doc() {
  # Phase 9 lesson + user-suggested rule #1: every port produces a mapping document
  # (V1 X → V2 Y) before any code is written. Without this, the executor reads V1 and
  # writes "by analogy to V1" — Phase 7's Transposition Trap recurrence pattern.
  #
  # Required artifact at every tier: ai/migration/mapping/<feature>.md
  # Minimum content: a 2-column table (V1 file/symbol → V2 file/symbol/wrapper).
  # Heavy tier additionally requires per-row "wrapper used" + "behaviour delta" columns.
  local feature="$1"; local id="${2:-}"; local tier="${3:-trivial}"
  local mapping_path="ai/migration/mapping/${feature}.md"
  if [[ ! -f "$mapping_path" ]]; then
    log_fail "missing V1→V2 mapping doc for $feature: expected $mapping_path. Required at every tier so the porter writes by analogy to V2's gold standard, not V1's shape. See migration-discipline.md § Reuse-Before-Create."
    return 1
  fi
  # Minimum: a markdown table with at least 1 mapping row (so the file isn't empty boilerplate)
  local row_count
  row_count=$(grep -cE '^\|[^|]+\|[^|]+\|' "$mapping_path" 2>/dev/null | head -1 | tr -d ' \n')
  row_count=${row_count:-0}
  if [[ $row_count -lt 2 ]]; then
    # 2 = header row + at least one mapping row
    log_fail "mapping doc $mapping_path is empty or has no mapping rows — needs at least one V1→V2 row in the table"
    return 1
  fi
  log_pass "V1→V2 mapping doc present: $feature ($((row_count - 1)) row(s))"
  return 0
}

check_gap_count_parity() {
  # Mechanical gate added 2026-04-30 with the find-and-fix RE-DETECT step.
  # The auditor's DETECT pass returns N gaps; the FIX step closes them; the RE-DETECT
  # pass confirms each is closed. The ledger row records gaps_in and gaps_closed —
  # they MUST be equal before the row advances. Inequality means at least one gap
  # shipped unclosed (the partial-fix failure mode). Missing fields means the row
  # was advanced without RE-DETECT running at all.
  local feature="$1"; local id="${2:-}"
  local ledger_block
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  local gaps_in gaps_closed
  gaps_in=$(echo "$ledger_block" | grep -m1 '^gaps_in:' | sed 's/^gaps_in:[[:space:]]*//' | tr -d ' "')
  gaps_closed=$(echo "$ledger_block" | grep -m1 '^gaps_closed:' | sed 's/^gaps_closed:[[:space:]]*//' | tr -d ' "')
  if [[ -z "$gaps_in" ]] || [[ -z "$gaps_closed" ]]; then
    log_fail "ledger row $id ($feature) missing gaps_in / gaps_closed fields — find-and-fix RE-DETECT step did not run, or ran and did not record. See find-and-fix.md § 3.5."
    return 1
  fi
  if ! [[ "$gaps_in" =~ ^[0-9]+$ ]] || ! [[ "$gaps_closed" =~ ^[0-9]+$ ]]; then
    log_fail "ledger row $id ($feature) has non-numeric gap counts (gaps_in='$gaps_in' gaps_closed='$gaps_closed')."
    return 1
  fi
  if [[ "$gaps_in" != "$gaps_closed" ]]; then
    log_fail "ledger row $id ($feature) gap-count mismatch: gaps_in=$gaps_in gaps_closed=$gaps_closed — partial fix shipped. Re-run /find-and-fix $feature OR escalate via /port-feature $feature --heavy."
    return 1
  fi
  log_pass "gap-count parity: $feature ($gaps_in gaps in, $gaps_closed closed)"
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
  local id="$1"; local feature="$2"; local phase="$3"; local status="$4"; local parity_test="$5"; local tier="${6:-}"
  TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
  # Default tier to trivial when unset (per migration-discipline.md § Required artifacts per feature — tiered floor)
  [[ -z "$tier" ]] && tier="trivial"
  log_section "Feature $id ($feature) — phase $phase, status=$status, tier=$tier"
  # 0. Check the ledger row first
  check_ledger_row "$id" "$feature" "$status" || true
  # If status is parked / deprecated / unverified / V1-only — skip the rest (artifacts not yet required)
  case "$status" in
    parked|deprecated|unverified|V1-only)
      # Informational skip — not a warning. Artifacts are not yet required at these states.
      [[ $QUIET -eq 0 ]] && echo "  ▸ skipping artifact checks: status=$status (not yet required)"
      return 0
      ;;
  esac
  # Strip surrounding whitespace from status for the artifact-check branch
  status="${status// /}"
  # ── Tier-scoped artifact checks (per migration-discipline.md) ──
  # trivial = audit + ledger row only (gap-count parity still required)
  # standard = +contract(3-section) + plan + ≥10-fixture parity + tolerance
  # heavy = +perf-decisions + runbook + 9-section contract + ≥30-fixture parity
  CONTRACT_PATH=""  # set by check_contract_exists; consumed by sections + citations
  case "$tier" in
    standard|heavy)
      check_contract_exists "$feature" "$id" || true
      check_contract_sections "$feature" "$id" "$tier" || true
      check_contract_citations "$feature" "$id" || true
      check_plan_exists "$feature" "$id" || true
      check_parity_corpus "$feature" "$id" "$tier" || true
      # Corpus-distribution + parity-run checks are heavy-only (require deeper test infra)
      if [[ "$tier" == "heavy" ]]; then
        check_corpus_distribution "$feature" "$id" || true
        check_parity_run_v1_commit "$feature" "$id" || true
      fi
      check_tolerance_coverage "$feature" "$id" "$tier" || true
      ;;
  esac
  case "$tier" in
    heavy)
      check_perf_decisions "$feature" "$id" || true
      check_runbook "$feature" "$id" || true
      ;;
  esac
  # Audit + structure + i18n + lifecycle apply at every tier (these are quality gates, not artifact existence)
  check_audit "$feature" "$id" || true
  check_audit_freshness "$feature" "$id" || true
  check_audit_body_consistency "$feature" "$id" || true
  check_intentional_break_adr "$feature" "$id" || true
  check_v1_path_drift_acknowledged "$feature" "$id" || true
  check_porter_vs_auditor "$feature" "$id" || true
  check_v2_structure "$feature" "$id" || true
  check_composable_reuse "$feature" "$id" || true
  check_service_shape "$feature" "$id" || true
  check_cross_module_import "$feature" "$id" || true
  check_i18n_locale_parity "$feature" "$id" || true
  check_lifecycle_keepalive "$feature" "$id" || true
  check_permission_gate_divergence "$feature" "$id" || true
  check_gap_count_parity "$feature" "$id" || true
  # Phase 9 additions (May 2026 — themes port lessons): every-tier artifact gates
  check_v2_mapping_doc "$feature" "$id" "$tier" || true
  check_api_response_sample "$feature" "$id" || true
}

# ── Project anchors ─────────────────────────────────────────────────────────
# Read ai/migration/_v2-anchors.md frontmatter (if present) to override defaults.
# Schema: see _v2-anchors-schema.md in the migration pack templates.
load_project_anchors() {
  if [[ ! -f "$ANCHORS_FILE" ]]; then
    if [[ $QUIET -eq 0 ]]; then
      echo "  anchors: (none — using defaults; run /setup-project to create _v2-anchors.md)"
    fi
    return 0
  fi
  # Parse YAML frontmatter (between leading --- and next ---)
  local fm
  fm=$(awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$ANCHORS_FILE")
  [[ -z "$fm" ]] && return 0
  local pk v1r v2r ptr ledger contracts plans audits perf runbooks ka_layout ka_var
  pk=$(echo "$fm" | grep -m1 '^project_kind:' | sed 's/^project_kind:[[:space:]]*//' | tr -d '"' | tr -d "'")
  v1r=$(echo "$fm" | grep -m1 '^v1_root:' | sed 's/^v1_root:[[:space:]]*//' | tr -d '"' | tr -d "'")
  v2r=$(echo "$fm" | grep -m1 '^v2_root:' | sed 's/^v2_root:[[:space:]]*//' | tr -d '"' | tr -d "'")
  ptr=$(echo "$fm" | grep -m1 '^parity_test_root:' | sed 's/^parity_test_root:[[:space:]]*//' | tr -d '"' | tr -d "'")
  ledger=$(echo "$fm" | grep -m1 '^ledger_path:' | sed 's/^ledger_path:[[:space:]]*//' | tr -d '"' | tr -d "'")
  contracts=$(echo "$fm" | grep -m1 '^contracts_dir:' | sed 's/^contracts_dir:[[:space:]]*//' | tr -d '"' | tr -d "'")
  plans=$(echo "$fm" | grep -m1 '^plans_dir:' | sed 's/^plans_dir:[[:space:]]*//' | tr -d '"' | tr -d "'")
  audits=$(echo "$fm" | grep -m1 '^audits_dir:' | sed 's/^audits_dir:[[:space:]]*//' | tr -d '"' | tr -d "'")
  perf=$(echo "$fm" | grep -m1 '^perf_dir:' | sed 's/^perf_dir:[[:space:]]*//' | tr -d '"' | tr -d "'")
  runbooks=$(echo "$fm" | grep -m1 '^runbooks_dir:' | sed 's/^runbooks_dir:[[:space:]]*//' | tr -d '"' | tr -d "'")
  ka_layout=$(echo "$fm" | grep -m1 '^keepalive_layout:' | sed 's/^keepalive_layout:[[:space:]]*//' | tr -d '"' | tr -d "'")
  ka_var=$(echo "$fm" | grep -m1 '^keepalive_exclude_var:' | sed 's/^keepalive_exclude_var:[[:space:]]*//' | tr -d '"' | tr -d "'")
  # Apply (override defaults only if the field was set)
  [[ -n "$pk" ]]       && PROJECT_KIND="$pk"
  [[ -n "$v1r" ]]      && V1_ROOT="$v1r"
  [[ -n "$v2r" ]]      && V2_ROOT="$v2r"
  [[ -n "$ptr" ]]      && PARITY_TEST_ROOT_DEFAULT="$ptr"
  [[ -n "$ledger" ]]   && LEDGER_PATH="$ledger"
  [[ -n "$contracts" ]] && CONTRACTS_DIR="$contracts"
  [[ -n "$plans" ]]    && PLANS_DIR="$plans"
  [[ -n "$audits" ]]   && AUDITS_DIR="$audits"
  [[ -n "$perf" ]]     && PERF_DIR="$perf"
  [[ -n "$runbooks" ]] && RUNBOOKS_DIR="$runbooks"
  [[ -n "$ka_layout" ]] && KEEPALIVE_LAYOUT="$ka_layout"
  [[ -n "$ka_var" ]]    && KEEPALIVE_EXCLUDE_VAR="$ka_var"
  if [[ $QUIET -eq 0 ]]; then
    echo "  anchors: $ANCHORS_FILE (project_kind=$PROJECT_KIND, v2_root=$V2_ROOT)"
  fi
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  load_project_anchors
  if [[ $QUIET -eq 0 ]]; then
    echo "validate-migration-artifacts.sh"
    echo "  ledger: $LEDGER_PATH"
    if [[ -n "$PHASE" ]]; then echo "  scope:  phase $PHASE"; fi
    if [[ -n "$FEATURE" ]]; then echo "  scope:  feature $FEATURE"; fi
    if [[ $SCAN_ALL -eq 1 ]]; then echo "  scope:  all features"; fi
  fi

  # Pre-check: detect duplicate IDs in the ledger (data-integrity issue).
  # Two rows with the same `id:` cause the validator + reports to skip-or-overwrite each other.
  local dupe_ids
  dupe_ids=$(grep -oE '^id: F[0-9]+[a-z]?$' "$LEDGER_PATH" 2>/dev/null | sort | uniq -d)
  if [[ -n "$dupe_ids" ]]; then
    echo "FATAL: duplicate ledger IDs detected (data-integrity issue):" >&2
    echo "$dupe_ids" | sed 's/^/  /' >&2
    echo "  Each id must be unique across the ledger. Resolve duplicates before re-running." >&2
    exit 4
  fi

  local features
  features=$(discover_features | filter_features)
  if [[ -z "$features" ]]; then
    echo "No features matched the scope. Check ledger contents." >&2
    exit 2
  fi

  while IFS='|' read -r id feature phase status parity_test tier; do
    [[ -n "$id" ]] || continue
    validate_feature "$id" "$feature" "$phase" "$status" "$parity_test" "$tier"
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
