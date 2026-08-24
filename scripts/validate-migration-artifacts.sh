#!/usr/bin/env bash
# validate-migration-artifacts.sh — universal migration-discipline validator.
#
# Tool-agnostic. Runs from any AI tool's hook system, CI pipeline, or pre-commit.
# Validates the artifact set required by `migration-discipline.md` for every
# feature in a phase (or for one feature with --feature=).
#
# Checks (per migration-discipline.md § "Required artifacts per feature" + § "Per-feature audit — 13 hard halts"):
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
#   11. Section 0 navigation inventory evidence (frontend-* / mixed) — check_section_0_evidence
#   12. 6-axis reachability doc — check_migration_reachability_axes
#   13. Cutover JSON evidence when status is V2-shadow | V2-canary | V2-only
#   14. tolerance.yaml git drift vs ADR citation; PR scope vs v2_path (warnings)
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
PARITY_RUNS_DIR="ai/migration/parity-runs"
MIN_CORPUS=30
PROJECT_KIND="frontend-vue3"      # frontend-vue3 | frontend-react | backend-nest | api-other
V2_ROOT="src/"
V1_ROOT=""
ANCHORS_FILE="ai/migration/_v2-anchors.md"
# Project-specific V2-structure fingerprints, parsed from the `forbidden_patterns:` list in
# _v2-anchors.md (#13). When non-empty, check_v2_structure uses THESE instead of the frozen
# built-in reference set hardcoded in the script — making the Transposition-Trap /
# Reinvented-Wrapper detection portable to any project.
declare -a PROJECT_FINGERPRINTS=()
# Lifecycle / KeepAlive checks (frontend) — anchor these per project via _v2-anchors.md
KEEPALIVE_LAYOUT=""               # e.g. src/shared/layouts/MainLayout.vue (Vue) — empty = lifecycle check disabled
KEEPALIVE_EXCLUDE_VAR="noCache"   # variable name in the layout that holds the exclude list

PHASE=""
FEATURE=""
SCAN_ALL=0
STRICT=0
QUIET=0

# ── Args ────────────────────────────────────────────────────────────────────
# ── --self-test ───────────────────────────────────────────────────────────────
# A GOOD fixture that must pass and a BAD one that must fail, both under $repo_root/tmp/.
#
# Writing this one found the ledger-row extractor bug: it matched `^id: <id>$` while the
# documented row is `  - id: F001` with indented fields, so the row was DISCOVERED and then
# read as having no fields at all. See the note at check_ledger_row.
run_migration_self_test() {
  local td repo_root rc me
  # Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
  # § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
  _ss="${BASH_SOURCE[0]}"
  while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
  repo_root="$(cd -P "$(dirname "$_ss")/.." && pwd)"
  me="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"; unset _ss _sd
  mkdir -p "$repo_root/tmp"
  td=$(mktemp -d "$repo_root/tmp/migration-selftest.XXXXXX")
  mkdir -p "$td/ai/migration/contracts" "$td/src"
  printf 'export function reportOrders() { return 1 }\n' > "$td/src/legacy.ts"
  # Indented list form, exactly as migration-ledger.md specifies it.
  cat > "$td/ai/migration/ledger.md" <<'FIX'
# Migration ledger

```yaml
# ai/migration/ledger.md — features:
  - id: F001
    feature: report-orders
    state: V1-only
    phase: 1
    owner: unassigned
    v1_path: src/legacy.ts:1
```
FIX

  rc=0
  ( cd "$td" && bash "$me" --all >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: the GOOD fixture was rejected (exit $rc)" >&2
    exit 1
  fi

  # Advance the state without adding what that state requires. `in-progress` demands
  # contract, plan and v1_commit_pinned — a row claiming progress it cannot evidence is
  # precisely what the per-state field table exists to refuse.
  sed 's/state: V1-only/state: in-progress/' "$td/ai/migration/ledger.md" > "$td/bad.md"
  mv "$td/bad.md" "$td/ai/migration/ledger.md"
  rc=0
  ( cd "$td" && bash "$me" --all >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -eq 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: an in-progress row with no contract/plan/v1_commit_pinned was accepted" >&2
    exit 1
  fi

  rm -rf "$td"
  echo "validate-migration-artifacts.sh --self-test OK"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase=*)   PHASE="${1#--phase=}"; shift ;;
    --feature=*) FEATURE="${1#--feature=}"; shift ;;
    --all)       SCAN_ALL=1; shift ;;
    --strict)    STRICT=1; shift ;;
    --quiet)     QUIET=1; shift ;;
    --self-test) run_migration_self_test ;;
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
# Ledger format (per migration-ledger.md): indented YAML-list rows, each row a
# `- id: F<NNN>` item with indented `feature: <slug>`, `phase: <N>`, `status: <state>` etc.
#
# Feature output format (one per line): "<id>|<feature-slug>|<phase>|<status>|<parity_test>"
discover_features() {
  # Parse ledger respecting yaml-row boundaries. A row starts at an (optionally `- `-prefixed,
  # optionally indented) `id: FNNN[a-z]?` line, ends at the closing ``` fence (or the next id:
  # line). Only accept field-setters while in_block=1 — prevents cross-block leakage where
  # superseded blocks contribute `feature:` lines to a previous block. Field values are taken
  # from $2 (indented `key: value` → $1=key:, $2=value); the id is sub()-stripped so a leading
  # "- " and any indentation are ignored.
  awk '
    /^[[:space:]]*(- )?id: F[0-9]+[a-z]?[[:space:]]*$/ {
      if (id != "") {
        print id "|" feature "|" phase "|" status "|" parity_test "|" tier
      }
      id = $0
      sub(/^[[:space:]]*(- )?id:[[:space:]]*/, "", id)
      sub(/[[:space:]]+$/, "", id)
      feature=""; phase=""; status=""; parity_test=""; tier=""
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
    in_block && /^[[:space:]]*feature: / { feature=$2; next }
    in_block && /^[[:space:]]*phase: /   { phase=$2;   next }
    in_block && /^[[:space:]]*status: /  { status=$2;  next }
    in_block && /^[[:space:]]*state: /   { if (status == "") status=$2; next }
    in_block && /^[[:space:]]*tier: /    { tier=$2;    next }
    in_block && /^[[:space:]]*parity_test: / { parity_test=$2; next }
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
  # `FNNN<letter>-<sub-area-slug>`) are audited under the parent (FNNN) rather
  # than having their own file.
  if [[ -n "$id" ]]; then
    local parent
    parent=$(awk -v id="$id" '
      $0 ~ ("^[[:space:]]*(- )?id: " id "$") { in_block=1; next }
      in_block && /^[[:space:]]*parent:[[:space:]]/ { sub(/^[[:space:]]*parent:[[:space:]]*/, "", $0); print $0; exit }
      in_block && /^[[:space:]]*(- )?id:|^```/ { exit }
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
  # NOTE: this checks the parity-test CORPUS (fixtures + tolerance.yaml exist). It does NOT
  # assert the tests passed — that is check_parity_run_report's job (which reads a recorded
  # run-report artifact and verifies result=pass against the pinned V1 commit; it never runs
  # the suite). Corpus presence is necessary but not sufficient: a fat corpus with no recorded
  # passing run is still an unverified parity claim.
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
      if [[ $STRICT -eq 1 ]]; then
        log_fail "[strict] parity tests are spec-file only (no tests/parity/$feature/inputs/) — standard/heavy tiers require a corpus dir + tolerance.yaml"
        return 1
      fi
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
    $0 ~ ("^[[:space:]]*(- )?id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  local pinned latest_run_commit
  pinned=$(echo "$ledger_block" | grep -m1 -E '^[[:space:]]*v1_commit_pinned:' | sed 's/.*v1_commit_pinned:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
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

first_parity_run_file() {
  # Echo the first parity-run report file for a feature (or nothing). Tolerates non-matching
  # globs (unlike `ls a b c`, which returns nonzero if ANY arg is missing). Order: id-prefixed
  # variants first, then bare-feature variants.
  local feature="$1"; local id="${2:-}"
  [[ -d "$PARITY_RUNS_DIR" ]] || return 0
  local f
  for f in \
    "$PARITY_RUNS_DIR/${id}-${feature}-"*.md \
    "$PARITY_RUNS_DIR/${id}-${feature}.md" \
    "$PARITY_RUNS_DIR/${feature}-"*.md \
    "$PARITY_RUNS_DIR/${feature}.md"; do
    # Skip id-prefixed patterns when id is empty (they'd be literal "-<feature>-*.md").
    [[ -z "$id" && "$f" == "$PARITY_RUNS_DIR/-"* ]] && continue
    if [[ -f "$f" ]]; then
      echo "$f"
      return 0
    fi
  done
  return 0
}

check_parity_run_report() {
  # PARITY PARITY-ASSERTION (artifact-only — this function NEVER executes a test suite).
  # For a row that claims parity is green (status=done AND parity_test: passing), REQUIRE
  # a recorded run-report artifact backing that claim:
  #   (A) a `parity_runs:` entry in the ledger row with `result: pass` + `v1_commit: <sha>`, OR
  #   (B) a file at `ai/migration/parity-runs/<feature>-<run-id>.md` (or `<id>-<feature>-*.md`)
  #       whose frontmatter/body declares `result: pass` + `v1_commit: <sha>`.
  # The recorded run's v1_commit MUST match the ledger's v1_commit_pinned. Absent or
  # mismatched → FAIL. We do NOT run tests; we read the asserted artifact.
  local feature="$1"; local id="${2:-}"; local status="$3"; local parity_test="${4:-}"
  # Only enforce when the row asserts a passing parity test on a done-class row.
  case "$status" in
    done|V2-shadow|divergent) ;;
    *) return 0 ;;
  esac
  # Normalise the parity_test claim (bash 3.2 has no ${x,,}; use tr)
  local pt
  pt=$(printf '%s' "$parity_test" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
  [[ "$pt" != "passing" && "$pt" != "pass" && "$pt" != "green" ]] && return 0

  # Pull the ledger row block + the pinned commit.
  local ledger_block pinned
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^[[:space:]]*(- )?id: " id "$") { in_block=1 }
    in_block { print }
    in_block && /^```/ { exit }
  ' "$LEDGER_PATH" 2>/dev/null)
  pinned=$(echo "$ledger_block" | grep -m1 -E '^[[:space:]]*v1_commit_pinned:' | sed 's/.*v1_commit_pinned:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  if [[ -z "$pinned" || "$pinned" == "null" ]]; then
    log_fail "parity-run report unverifiable for $feature: status=$status claims parity_test=passing but ledger has no v1_commit_pinned to check the recorded run against. Pin V1 first. See migration-discipline.md § halt #3 / D4."
    return 1
  fi

  # (A) Ledger parity_runs[] entry — find an indented `result:` / `v1_commit:` line under the
  # parity_runs block. Tolerate the optional `- ` list-item prefix and any leading indentation.
  local run_result run_commit
  run_result=$(echo "$ledger_block" | grep -m1 -E '^[[:space:]]+(- )?result:' | sed 's/.*result:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  run_commit=$(echo "$ledger_block" | grep -m1 -E '^[[:space:]]+(- )?v1_commit:' | sed 's/.*v1_commit:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')

  # (B) Standalone run-report file fallback.
  local run_file=""
  run_file=$(first_parity_run_file "$feature" "$id")
  if [[ -z "$run_result" && -n "$run_file" && -f "$run_file" ]]; then
    run_result=$(grep -m1 -iE '^[[:space:]]*result:[[:space:]]' "$run_file" 2>/dev/null | sed 's/.*[Rr]esult:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
    run_commit=$(grep -m1 -iE '^[[:space:]]*v1_commit:[[:space:]]' "$run_file" 2>/dev/null | sed 's/.*[Vv]1_commit:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  fi

  # No recorded run anywhere → FAIL (the passing claim is a Trusted Summary).
  if [[ -z "$run_result" ]]; then
    log_fail "parity-run report MISSING for $feature: status=$status claims parity_test=passing but no recorded run backs it — need a ledger parity_runs[] entry (result: pass + v1_commit) OR a file at $PARITY_RUNS_DIR/${id:+$id-}${feature}-<run-id>.md. A 'passing' claim with no run-report artifact is unverifiable. See migration-discipline.md § halt #3."
    return 1
  fi

  # Recorded run must declare pass.
  local rr
  rr=$(printf '%s' "$run_result" | tr '[:upper:]' '[:lower:]')
  if [[ "$rr" != "pass" && "$rr" != "passing" && "$rr" != "green" ]]; then
    log_fail "parity-run report for $feature records result='$run_result' (not pass) but the ledger claims parity_test=passing — reconcile the recorded run with the row claim. See migration-discipline.md § halt #3."
    return 1
  fi

  # Recorded run's v1_commit must match the pinned oracle commit (substring-tolerant: short vs full SHA).
  if [[ -z "$run_commit" ]]; then
    log_fail "parity-run report for $feature records result=pass but no v1_commit — cannot prove the run executed against the pinned oracle ($pinned). Record the commit the run ran against. See migration-discipline.md § D4."
    return 1
  fi
  if [[ "$pinned" == "$run_commit"* ]] || [[ "$run_commit" == "$pinned"* ]]; then
    log_pass "parity-run report backs passing claim: $feature (result=pass @ $run_commit == pinned $pinned)"
  else
    log_fail "parity-run report for $feature ran against v1_commit '$run_commit' but the ledger pins v1_commit_pinned='$pinned' — the recorded pass is against a DIFFERENT V1 oracle. Re-run parity against the pinned commit OR re-pin. See migration-discipline.md § D4 / halt #3."
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
  # If anything is applied, REQUIRE a numeric before/after measurement.
  # An `applied` perf candidate with no number is noise (migration-discipline.md § halt #5,
  # parity-auditor.md § "Approving without measurements"). This is a HARD FAIL, not a warning:
  # the whole point of capturing a migration-time perf win is the measured delta.
  if [[ $applied -gt 0 ]]; then
    # A numeric measurement = a latency/throughput/count figure with a unit, a percentile,
    # or an explicit before→after / N→M numeric pair.
    local has_numeric=0
    if grep -qE '\bp(50|75|90|95|99)\b|\b[0-9][0-9.]* ?(ms|s|µs|us|ns|MB|KB|GB|rows?|queries|req/s|qps|ops/s)\b|[0-9][0-9.]*[[:space:]]*(→|->|to)[[:space:]]*[0-9]|\b(before|after)\b[^0-9]{0,40}[0-9]' "$file"; then
      has_numeric=1
    fi
    if [[ $has_numeric -eq 1 ]]; then
      log_pass "perf-decisions has numeric before/after measurements: $feature"
    else
      log_fail "perf-decisions has $applied applied candidate(s) with NO numeric before/after measurement: $feature — every applied perf change MUST cite a measured delta (e.g., 'p95 420ms → 110ms', '14 queries → 1', 'before 1.2s / after 0.3s'). An applied candidate with no number is unverifiable. See migration-discipline.md § halt #5."
      return 1
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

# #36 — extracted from check_audit so the name cited across migration-gate / parity-auditor /
# port-feature / migration-phase / migration-fast resolves to a REAL function (was prose inside
# check_audit, so the "(new) check_audit_provenance" claim was un-locatable). F039/F030/F032:
# prove the audit came from a parity-auditor agent dispatch, not an inline-executor echo.
check_audit_provenance() {
  local file="$1" feature="${2:-}"
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
  return 0
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
  check_audit_provenance "$file" "$feature" || return 1
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

check_section_0_evidence() {
  # Halt #13 enforcement: every audit on a frontend feature OR a multi-tab / module / settings-shell
  # scope MUST emit Layer A (route extraction) AND Layer B (per-leaf template grep) evidence in the
  # audit body. The validator parses the evidence headers and refuses the gate if Layer B is missing
  # OR present-but-empty (Layer-A-only scan recurrence — the canonical F039 / advanced/purchase tab
  # drift failure mode).
  #
  # Bypass (rare): audit explicitly declares non-UI scope at the top with `audit_scope: backend-only`
  # in frontmatter. Frontend project_kind without that bypass = required.
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0  # check_audit will have already failed; no need to double-fail

  # Bypass: explicit backend-only scope
  if grep -qE '^audit_scope:[[:space:]]*backend-only' "$file" 2>/dev/null; then
    log_pass "section-0 evidence: $feature (skipped — audit_scope: backend-only)"
    return 0
  fi

  # Only enforce when project_kind is frontend-* or mixed (hybrid UI surface)
  case "$PROJECT_KIND" in
    frontend-*|mixed) ;;
    *) return 0 ;;
  esac

  # Require a Section 0 header. Any of these acceptable:
  #   ## Section 0 — Navigation Inventory
  #   ## Section 0 — Layer A — V1 routes
  #   ### Section 0 — ...
  if ! grep -qE '^#{2,4}[[:space:]]+Section 0\b' "$file"; then
    log_fail "audit MISSING Section 0 — Navigation Inventory in $file. Halt #13 mandates this section for every frontend audit. Auditor MUST emit Layer A (route extraction) + Layer B (per-leaf template grep) before any per-axis enumeration. See parity-auditor.md § \"Section 0 MUST emit machine-verifiable evidence\"."
    return 1
  fi

  # Require Layer A evidence — at least one route entry on each side
  local layer_a_v1 layer_a_v2
  layer_a_v1=$(awk '/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*Layer A[[:space:]]*[-—][[:space:]]*V1/,/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*Layer/' "$file" 2>/dev/null | grep -cE '^[[:space:]]*/.+→.+\.(vue|tsx?|jsx?|svelte|html)' || echo 0)
  layer_a_v2=$(awk '/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*Layer A[[:space:]]*[-—][[:space:]]*V2/,/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*Layer/' "$file" 2>/dev/null | grep -cE '^[[:space:]]*/.+→.+\.(vue|tsx?|jsx?|svelte|html)' || echo 0)
  layer_a_v1=${layer_a_v1:-0}
  layer_a_v2=${layer_a_v2:-0}
  if [[ "$layer_a_v1" -lt 1 || "$layer_a_v2" -lt 1 ]]; then
    log_fail "audit Section 0 Layer A is empty in $file (V1 routes: $layer_a_v1, V2 routes: $layer_a_v2). Auditor MUST list every route + leaf component path on both sides. See parity-auditor.md § \"Section 0 MUST emit machine-verifiable evidence\" — Layer A block."
    return 1
  fi

  # Require Layer B evidence — at least one grep command output OR explicit "no matches" annotation per side
  local layer_b_v1 layer_b_v2
  layer_b_v1=$(awk '/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*Layer B[[:space:]]*[-—][[:space:]]*V1/,/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*(Layer|Leaf)/' "$file" 2>/dev/null | grep -cE 'Command:|Matches:|no matches|TabView|TabMenu|v-tabs|v-tab|tabs\.map|v-for.*tab|router-view|role="tab"' || echo 0)
  layer_b_v2=$(awk '/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*Layer B[[:space:]]*[-—][[:space:]]*V2/,/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*(Leaf|Section)/' "$file" 2>/dev/null | grep -cE 'Command:|Matches:|no matches|TabView|TabMenu|v-tabs|v-tab|tabs\.map|v-for.*tab|router-view|role="tab"' || echo 0)
  layer_b_v1=${layer_b_v1:-0}
  layer_b_v2=${layer_b_v2:-0}
  if [[ "$layer_b_v1" -lt 1 || "$layer_b_v2" -lt 1 ]]; then
    log_fail "audit Section 0 Layer B is empty in $file (V1 grep evidence: $layer_b_v1 lines, V2: $layer_b_v2 lines). Auditor MUST open EACH leaf component on both sides + paste grep command + matches (or 'no matches' annotation). Layer-A-only scan = HALT per migration-discipline.md Halt #13. The canonical failure mode that missed advanced/purchase sub-tab drift in inventory."
    return 1
  fi

  # Require Leaf-set diff table — at least one row indicating both sides were enumerated
  local diff_rows
  diff_rows=$(awk '/^#{2,4}[[:space:]]+Section 0[[:space:]]*[-—][[:space:]]*Leaf[- ]?set diff/,/^#{2,4}/' "$file" 2>/dev/null | grep -cE '^\|.+\|.+\|.+\|.+\|' || echo 0)
  diff_rows=${diff_rows:-0}
  if [[ "$diff_rows" -lt 2 ]]; then  # 2 = header row + ≥1 data row
    log_fail "audit Section 0 Leaf-set diff table is missing or empty in $file (rows: $diff_rows). Auditor MUST emit a 4-column table: V1 leaf | V2 leaf | Verdict | Closure verb. One row per leaf on either side. See parity-auditor.md § \"Section 0 — Leaf-set diff\"."
    return 1
  fi

  # Multi-route surfaces: require deeper Layer-B evidence (per-leaf grep signals, not Layer-A-only).
  if [[ "${layer_a_v1:-0}" -ge 2 ]] || [[ "${layer_a_v2:-0}" -ge 2 ]]; then
    if [[ "${layer_b_v1:-0}" -lt 3 ]] || [[ "${layer_b_v2:-0}" -lt 3 ]]; then
      log_fail "audit Section 0: multiple Layer-A routes detected (V1=$layer_a_v1 V2=$layer_a_v2) but Layer-B grep depth looks shallow (V1=$layer_b_v1 V2=$layer_b_v2). Each route leaf must be opened and grep'd for tab/sub-tab patterns (Halt #13 / #13a). See parity-auditor.md § Section 0."
      return 1
    fi
  fi

  log_pass "section-0 evidence: $feature (Layer A: V1=$layer_a_v1, V2=$layer_a_v2; Layer B: V1=$layer_b_v1, V2=$layer_b_v2; Diff rows: $diff_rows)"
  return 0
}

check_per_axis_enumeration() {
  # Failure mode this guards against: an audit declares all 7 frontend axes "PARITY"
  # via single-line verdicts under each "### N. <axis>" heading — yet V2's file is a
  # small fraction of V1's size (entire form-content section missing). The hand-wave
  # grep in check_audit doesn't fire because the audit didn't use "etc." / "...".
  # This check parses the 7 frontend-axis sections, applies a density rule per axis
  # on PARITY-claimed UI-leaf rows, and halts on shallow PARITY claims.
  #
  # Bypass: audit_scope: backend-only frontmatter (consistent with check_section_0_evidence).
  local feature="$1"; local id="${2:-}"; local tier="${3:-trivial}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0  # check_audit will have already failed

  # Bypass: explicit backend-only scope
  if grep -qE '^audit_scope:[[:space:]]*backend-only' "$file" 2>/dev/null; then
    log_pass "per-axis enumeration: $feature (skipped — audit_scope: backend-only)"
    return 0
  fi
  # Only enforce when project_kind is frontend-* or mixed
  case "$PROJECT_KIND" in
    frontend-*|mixed) ;;
    *) return 0 ;;
  esac

  # Determine if this audit's row points at a UI leaf. Read v1_path / v2_path lines
  # from the audit's header block (first ~25 lines, before the body). Audits often
  # cite multiple V1/V2 files via `+`-separated paths or continuation lines; we
  # collect ALL UI-extension matches and pick the largest by LOC as the
  # representative leaf (the smallest is usually a tab-shell, the largest is the
  # forms-bearing leaf).
  local header_block
  header_block=$(awk 'NR<=25; NR>25 { exit }' "$file" 2>/dev/null)
  local all_v1_files all_v2_files
  all_v1_files=$(echo "$header_block" | awk '
    /^>?[[:space:]]*[Vv]1 path:/ { capture=1 }
    capture && /^>?[[:space:]]*[Vv]2 path:/ { capture=0 }
    capture { print }
  ' | grep -oE '[A-Za-z_./-]+\.(vue|tsx?|jsx?|svelte|html)' | sort -u)
  all_v2_files=$(echo "$header_block" | awk '
    /^>?[[:space:]]*[Vv]2 path:/ { capture=1 }
    capture && /^>?[[:space:]]*(ADR|v1_commit|Tier|Verdict|##)/ { capture=0 }
    capture { print }
  ' | grep -oE '[A-Za-z_./-]+\.(vue|tsx?|jsx?|svelte|html)' | sort -u)

  # Pick representative file: largest LOC among the matches
  pick_largest_file() {
    local candidates="$1" root_hint="$2"
    local best="" best_loc=0
    local cand full_path loc
    while IFS= read -r cand; do
      [[ -z "$cand" ]] && continue
      full_path=""
      if [[ -f "$cand" ]]; then
        full_path="$cand"
      elif [[ -n "$root_hint" && -f "${root_hint}/${cand}" ]]; then
        full_path="${root_hint}/${cand}"
      else
        local bn="${cand##*/}"
        if [[ "$root_hint" == "$V1_ROOT" ]]; then
          build_v1_basename_index
          full_path=$(v1_basename_lookup "$bn" 2>/dev/null || echo "")
        else
          build_v2_basename_index
          full_path=$(v2_basename_lookup "$bn" 2>/dev/null || echo "")
        fi
      fi
      [[ -z "$full_path" || ! -f "$full_path" ]] && continue
      loc=$(wc -l < "$full_path" 2>/dev/null | tr -d ' ' || echo 0)
      [[ "$loc" =~ ^[0-9]+$ ]] || loc=0
      if [[ $loc -gt $best_loc ]]; then
        best_loc=$loc
        best="$full_path|$cand"
      fi
    done <<< "$candidates"
    echo "$best"
  }

  local v1_pick v2_pick
  v1_pick=$(pick_largest_file "$all_v1_files" "$V1_ROOT")
  v2_pick=$(pick_largest_file "$all_v2_files" "$V2_ROOT")

  local v1_full v1_file v2_full v2_file
  v1_full="${v1_pick%|*}"; v1_file="${v1_pick#*|}"
  v2_full="${v2_pick%|*}"; v2_file="${v2_pick#*|}"
  # Handle empty pick (no `|` separator means it's empty)
  [[ "$v1_pick" != *"|"* ]] && { v1_full=""; v1_file=""; }
  [[ "$v2_pick" != *"|"* ]] && { v2_full=""; v2_file=""; }

  # If neither V1 nor V2 path is a UI leaf, this isn't a UI audit — skip
  if [[ -z "$v1_file" && -z "$v2_file" ]]; then
    return 0
  fi

  # Read overall verdict from frontmatter (`> Verdict: ...`)
  local verdict
  verdict=$(awk '/^>?[[:space:]]*[Vv]erdict:/ {sub(/^>?[[:space:]]*[Vv]erdict:[[:space:]]*/, ""); print; exit}' "$file" 2>/dev/null | head -1)
  # If the overall verdict isn't PARITY-claiming, the density rule doesn't apply
  # (DRIFT / V2-EXTRA-KEEP / PORT verdicts are expected to surface gaps).
  local is_parity=0
  if echo "$verdict" | grep -qiE '^PARITY\b|^parity-?clean\b|\bPASS\b'; then
    is_parity=1
  fi

  # LOC counts (already resolved above via pick_largest_file)
  local v1_loc=0 v2_loc=0
  [[ -n "$v1_full" && -f "$v1_full" ]] && v1_loc=$(wc -l < "$v1_full" 2>/dev/null | tr -d ' ' || echo 0)
  [[ -n "$v2_full" && -f "$v2_full" ]] && v2_loc=$(wc -l < "$v2_full" 2>/dev/null | tr -d ' ' || echo 0)
  v1_loc=${v1_loc:-0}; v2_loc=${v2_loc:-0}

  # LOC-ratio backup signal: V2 < 35% of V1 LOC + PARITY verdict + V1 LOC ≥ 400 → warn.
  # Tightened from 50%/200LOC → 35%/400LOC because primitive-count check
  # (check_inventory_primitives_match) is now the primary auto-promote trigger.
  # LOC catches edge cases primitives miss: V1 with mostly comments / large helper
  # functions that don't surface as v-models. We warn here so the primitive check
  # gets first crack at halting; this only fires when the file is unusually small
  # AND no primitive-class flagged it.
  if [[ $is_parity -eq 1 && $v1_loc -ge 400 && $v2_loc -gt 0 ]]; then
    local ratio_pct=$(( v2_loc * 100 / v1_loc ))
    if [[ $ratio_pct -lt 35 ]]; then
      log_warn "per-axis enumeration (LOC backup signal): V2 is ${ratio_pct}% the size of V1 (V2=${v2_loc} LOC, V1=${v1_loc} LOC) on PARITY verdict in $file. If primitive-count check passed, the gap may be in non-form code (helpers, computed properties); review manually. v1_path=$v1_file v2_path=$v2_file"
    fi
  fi

  # Forms-bearing test on V1 — aggregate ≥ 5 form-element matches across ALL cited V1 paths
  # (tab shell + leaf components), not only the LOC-largest file.
  local forms_bearing=0
  local form_hits_total=0
  build_v1_basename_index 2>/dev/null || true
  while IFS= read -r cand_v1; do
    [[ -z "$cand_v1" ]] && continue
    local vf_res=""
    if [[ -f "$cand_v1" ]]; then
      vf_res="$cand_v1"
    elif [[ -n "${V1_ROOT:-}" && -f "${V1_ROOT%/}/$cand_v1" ]]; then
      vf_res="${V1_ROOT%/}/$cand_v1"
    else
      vf_res=$(v1_basename_lookup "${cand_v1##*/}" 2>/dev/null || echo "")
    fi
    [[ -z "$vf_res" || ! -f "$vf_res" ]] && continue
    local form_hits
    form_hits=$(grep -cE '<input\b|<v-text-field|v-model=|<InputText\b|<InputSwitch\b|<InputNumber\b|<Dropdown\b|<TranslatedInput\b|<FormField\b|<Textarea\b|<Select\b|<Checkbox\b' "$vf_res" 2>/dev/null || echo 0)
    form_hits=${form_hits:-0}
    [[ "$form_hits" =~ ^[0-9]+$ ]] || form_hits=0
    form_hits_total=$((form_hits_total + form_hits))
  done <<< "$(echo "$all_v1_files" | sort -u)"
  [[ $form_hits_total -ge 5 ]] && forms_bearing=1

  # Reads-query test on V2 — does the V2 file read route.query / useSearchParams?
  local v2_reads_query=0
  if [[ -n "$v2_full" && -f "$v2_full" ]]; then
    if grep -qE '\broute\.query\b|useSearchParams|\$route\.query|searchParams' "$v2_full" 2>/dev/null; then
      v2_reads_query=1
    fi
  fi

  # Per-axis density check. Only fires when verdict is PARITY (overall) AND axis
  # is not explicitly DRIFT-classified inline. We extract each axis section body
  # and count: table-data-rows, path:line citations, total words.
  local axes=(
    "1\\. Form fields"
    "2\\. UI affordances"
    "3\\. Templated query params"
    "4\\. Event handlers"
    "5\\. Per-button permission gates"
    "6\\. a11y"
    "7\\. Reactive lifecycle"
  )
  local axis_names=(
    "Form fields"
    "UI affordances"
    "Templated query params"
    "Event handlers"
    "Per-button permission gates"
    "a11y"
    "Reactive lifecycle"
  )
  # Forms-/affordance-/handler-/gate- axes share the strict density rule
  local strict_axes=(0 1 3 4)
  # a11y + lifecycle: lower bar — at least 1 citation OR ≥ 15 words
  local lenient_axes=(5 6)
  # Query-params axis: only required if V2 reads query
  local query_axis_idx=2

  local violations=0
  local i
  for i in "${!axes[@]}"; do
    local axis_pat="${axes[$i]}"
    local axis_name="${axis_names[$i]}"
    # Extract axis body: from "### N. <name>" until the next "### " or "## "
    local body
    body=$(awk -v pat="^#{3,4}[[:space:]]+${axis_pat}" '
      $0 ~ pat { capture=1; next }
      capture && /^#{2,4}[[:space:]]/ { exit }
      capture { print }
    ' "$file" 2>/dev/null)

    if [[ -z "$body" ]]; then
      # Section missing entirely. UI-leaf rows: halt for strict + query (if reads_query). Lenient: warn.
      local is_strict=0
      for s in "${strict_axes[@]}"; do [[ $i -eq $s ]] && is_strict=1; done
      if [[ $is_strict -eq 1 ]]; then
        log_fail "per-axis enumeration: axis '$axis_name' MISSING from audit body in $file. UI-leaf audits MUST emit all 7 frontend axes. See migration-discipline.md § \"Per-axis enumeration is required wherever a gap exists.\""
        violations=$((violations + 1))
      elif [[ $i -eq $query_axis_idx && $v2_reads_query -eq 1 ]]; then
        log_warn "per-axis enumeration: axis '$axis_name' MISSING in $file but V2 reads route.query — auditor SHOULD enumerate query params."
      fi
      continue
    fi

    # Inline DRIFT? Skip density rule (the auditor flagged drift; gaps_in/closed will cover it)
    if echo "$body" | grep -qiE '\bDRIFT\b|\bMISSING\b|^[[:space:]]*-[[:space:]]*GAP-|gap_count|gaps_in:[[:space:]]*[1-9]'; then
      continue
    fi

    # Density signals
    local table_rows path_citations word_count
    # Data rows: lines starting with `|` AFTER a `|---|` separator line
    table_rows=$(echo "$body" | awk '
      /^\|[[:space:]]*-+[[:space:]]*\|/ { sep=1; next }
      sep && /^\|/ { count++ }
      END { print count+0 }
    ')
    path_citations=$(echo "$body" | grep -oE '[A-Za-z_./-]+\.(vue|tsx?|jsx?|svelte|html|js):[0-9]+' | wc -l | tr -d ' ')
    word_count=$(echo "$body" | wc -w | tr -d ' ')
    table_rows=${table_rows:-0}; path_citations=${path_citations:-0}; word_count=${word_count:-0}

    # Decide if this axis only has PARITY-claim ("clean", "match", "PARITY") — apply density rule then
    local axis_claims_parity=0
    if echo "$body" | grep -qiE '^\s*clean\b|\bmatch\b|^\s*PARITY\b|\bidentical\b|\bok\b|^\s*✅'; then
      axis_claims_parity=1
    fi
    # If axis body has neither PARITY claim nor DRIFT marker AND is non-empty, treat as "narrative" — skip density (avoids false positives on mixed audits).
    [[ $axis_claims_parity -eq 0 ]] && continue

    # Strict axes (Form fields, UI affordances, Event handlers, Permission gates):
    # overall PARITY verdict + forms-bearing UI-leaf + per-axis PARITY claim +
    # (< 3 table rows AND < 5 citations) → halt
    local is_strict=0
    for s in "${strict_axes[@]}"; do [[ $i -eq $s ]] && is_strict=1; done
    if [[ $is_strict -eq 1 && $is_parity -eq 1 && $forms_bearing -eq 1 ]]; then
      if [[ $table_rows -lt 3 && $path_citations -lt 5 ]]; then
        # Tier softening: trivial + V1 < 100 LOC → warn instead of halt
        if [[ "$tier" == "trivial" && $v1_loc -gt 0 && $v1_loc -lt 100 ]]; then
          log_warn "per-axis enumeration: axis '$axis_name' on PARITY-claimed UI-leaf has insufficient enumeration (table_rows=$table_rows, citations=$path_citations) in $file (trivial tier + V1 < 100 LOC = warn)."
        else
          log_fail "per-axis enumeration: axis '$axis_name' on PARITY-claimed UI-leaf has insufficient enumeration (table_rows=$table_rows, citations=$path_citations) in $file. Per discipline rule \"The Optimistic Form Field Match\", auditor must enumerate every V1 input/affordance/handler/gate with V1+V2 path:line citations OR re-classify as DRIFT. v1_path=$v1_file v2_path=$v2_file"
          violations=$((violations + 1))
        fi
      fi
    fi

    # Query-params axis: only require ≥1 citation when V2 reads query AND overall PARITY
    if [[ $i -eq $query_axis_idx && $v2_reads_query -eq 1 && $is_parity -eq 1 ]]; then
      if [[ $path_citations -lt 1 ]]; then
        log_fail "per-axis enumeration: axis '$axis_name' on PARITY-claimed UI-leaf has 0 path:line citations in $file but V2 reads route.query. Auditor must enumerate which params V1 reads + V2 reads or re-classify."
        violations=$((violations + 1))
      fi
    fi

    # Lenient axes (a11y, lifecycle): completely empty (<3 words) AND no citation → halt.
    # "clean — shared wrappers." (4 words) is acceptable; "clean." (1 word) alone is not.
    local is_lenient=0
    for s in "${lenient_axes[@]}"; do [[ $i -eq $s ]] && is_lenient=1; done
    if [[ $is_lenient -eq 1 ]]; then
      if [[ $word_count -lt 3 && $path_citations -lt 1 ]]; then
        log_fail "per-axis enumeration: axis '$axis_name' is essentially empty in $file (words=$word_count, citations=$path_citations). At minimum, name the V2 wrapper used OR cite a path:line."
        violations=$((violations + 1))
      fi
    fi
  done

  if [[ $violations -gt 0 ]]; then
    return 1
  fi
  log_pass "per-axis enumeration: $feature (forms_bearing=$forms_bearing, v1_loc=$v1_loc, v2_loc=$v2_loc)"
  return 0
}

# ── Stack-aware structural primitive extractor ──────────────────────────────
# Replaces LOC-ratio as the PRIMARY auto-promote signal. LOC ratio is noisy
# (V1 may be verbose markup; V2 may be compact via shared wrappers). Counting
# meaningful primitives per stack is more accurate.
#
# Output format (one per line, key=count):
#   v_model=47
#   dropdown=8
#   button=5
#   ...
#
# Args: $1=file_path  $2=project_kind
# Stdout: lines of "<primitive>=<count>". Empty / 0 if file doesn't exist.
extract_inventory_primitives() {
  local file="$1"
  local pk="$2"
  if [[ -z "$file" || ! -f "$file" ]]; then
    return 0
  fi

  # Determine the stack family from PROJECT_KIND. Within a family, regex
  # patterns are mostly portable (Vue / React / Svelte / Angular all share
  # similar primitive concepts for the frontend family).
  local family=""
  case "$pk" in
    frontend-*|mixed) family="frontend" ;;
    backend-*)  family="backend"  ;;
    data-*)     family="data"     ;;
    mobile-*)   family="mobile"   ;;
    *)
      echo "extract_inventory_primitives: ERROR unknown project_kind='$pk' (run passes validate_project_kind_strict first)" >&2
      family="frontend"
      ;;
  esac

  case "$family" in
    frontend)
      # v_model — two-way form binding across major frameworks.
      # Vue: v-model / v-model:slot=. Svelte: bind:value / bind:checked / bind:group.
      # Angular: [(ngModel)]=. React/Solid don't have a true two-way primitive —
      # we proxy via useState (form-state hook) PLUS controlled-input pairs
      # (value={...} adjacent to onChange={...}).
      local v_model react_state svelte_bind ng_model
      v_model=$(grep -oE 'v-model(:[a-zA-Z-]+)?="[^"]+"' "$file" 2>/dev/null | sort -u | wc -l | tr -d ' ')
      v_model=${v_model:-0}
      svelte_bind=$(grep -oE 'bind:(value|checked|group|files|this|innerHTML|textContent)=' "$file" 2>/dev/null | wc -l | tr -d ' ')
      svelte_bind=${svelte_bind:-0}
      ng_model=$(grep -oE '\[\(ngModel\)\]=' "$file" 2>/dev/null | wc -l | tr -d ' ')
      ng_model=${ng_model:-0}
      # React useState calls — strong proxy for form fields when this is a React/Solid file
      react_state=$(grep -oE '\buseState[[:space:]]*(<[^>]+>)?[[:space:]]*\(' "$file" 2>/dev/null | wc -l | tr -d ' ')
      react_state=${react_state:-0}
      v_model=$(( v_model + svelte_bind + ng_model + react_state ))

      # dropdown / select-shaped components — Vue + PrimeVue + Vuetify + React (MUI/Antd/Mantine/Chakra/shadcn) + Angular Material + native
      local dropdown
      dropdown=$(grep -oE '<Dropdown\b|<MultiSelect\b|<BaseDropdown\b|<v-select\b|<TranslatedInput\b|<Select\b|<Combobox\b|<Listbox\b|<MenuItem\b|<mat-select\b|<select\b|<NativeSelect\b' "$file" 2>/dev/null | wc -l | tr -d ' ')
      dropdown=${dropdown:-0}

      # button-shaped affordances — Vue + Vuetify + React (incl. MUI IconButton) + Angular Material + native
      local button
      button=$(grep -oE '<Button\b|<button\b|<v-btn\b|<AppButton\b|<IconButton\b|<LoadingButton\b|<mat-button\b|<mat-raised-button\b|<mat-icon-button\b|mat-raised-button\b|mat-stroked-button\b' "$file" 2>/dev/null | wc -l | tr -d ' ')
      button=${button:-0}

      # click / submit handlers — Vue (@click / v-on:click) + Svelte (on:click) + Angular ((click)) + React/Solid (onClick / onSubmit / onChange)
      local click_handler
      click_handler=$(grep -oE '@click(\.[a-zA-Z]+)?=|@submit(\.[a-zA-Z]+)?=|v-on:(click|submit)=|on:(click|submit)=|\(click\)=|\(submit\)=|\(ngSubmit\)=|onClick[[:space:]]*=[[:space:]]*\{|onSubmit[[:space:]]*=[[:space:]]*\{|onChange[[:space:]]*=[[:space:]]*\{' "$file" 2>/dev/null | wc -l | tr -d ' ')
      click_handler=${click_handler:-0}

      # permission-gate sites — security axis across Vue/React/Svelte/Angular idioms
      local permission_gate
      permission_gate=$(grep -oE 'hasPermission[[:space:]]*\(|meta\.permission|v-permission|v-can=|<RequirePerm\b|<RequirePermission\b|<ProtectedRoute\b|<Can\b|<auth-gate\b|user\.can[[:space:]]*\(|usePermissions[[:space:]]*\(|useAuth[[:space:]]*\(|permissionStore\.has[[:space:]]*\(|canAccess\b|\*ngIf="canAccess|@PreAuthorize[[:space:]]*\(' "$file" 2>/dev/null | wc -l | tr -d ' ')
      permission_gate=${permission_gate:-0}

      # in-template tabs — Vue + React + Svelte + Angular Material
      local tabs
      tabs=$(grep -oE '<v-tabs\b|<TabView\b|<TabMenu\b|<Tabs\b|<Tab\b|<v-tab\b|<TabList\b|<TabPanel\b|<TabPanels\b|<mat-tab-group\b|<mat-tab\b|role="tab"|nav-tabs\b|nav_tabs\b|RouteTabs\b|InnerTabs\b' "$file" 2>/dev/null | wc -l | tr -d ' ')
      tabs=${tabs:-0}

      # route_def — only counted on router-shaped files OR file-based-routing (pages/, routes/, +page.svelte)
      local route_def=0
      local fb_pages_file=0
      case "$file" in
        */pages/*|*/routes/*|*+page.svelte|*+layout.svelte|*+page.ts|*+page.js)
          fb_pages_file=1
          ;;
      esac
      case "$file" in
        *routes*.ts|*routes*.js|*routes*.tsx|*routes*.jsx|*router*.ts|*router*.js|*-routing.module.ts|*App.tsx|*App.jsx)
          # Vue Router / generic config: path: / name:
          # React Router: <Route path=...> / { path: '...' } objects
          # Angular Router: path: ... in Routes array
          route_def=$(grep -oE "path:[[:space:]]*['\"\`]|name:[[:space:]]*['\"\`].*['\"\`][[:space:]]*,|<Route\b|component:[[:space:]]*[A-Z][A-Za-z0-9_]*|loadChildren:[[:space:]]*" "$file" 2>/dev/null | wc -l | tr -d ' ')
          route_def=${route_def:-0}
          ;;
      esac
      # File-based routing frameworks (Next/Nuxt/SvelteKit/Astro) — each leaf file counts as 1 route
      if [[ $fb_pages_file -eq 1 && $route_def -eq 0 ]]; then
        route_def=1
      fi

      # raw input/textarea/InputText — across PrimeVue, Vuetify, MUI, Antd, Mantine, Chakra, native HTML
      local input_html
      input_html=$(grep -oE '<input\b|<textarea\b|<InputText\b|<InputNumber\b|<InputSwitch\b|<v-text-field\b|<v-textarea\b|<TextField\b|<TextareaAutosize\b|<TextInput\b|<Textarea\b|<NumberInput\b|<Input\b|<Input\.TextArea\b' "$file" 2>/dev/null | wc -l | tr -d ' ')
      input_html=${input_html:-0}

      # conditional render branches — Vue (v-if/v-show/v-else-if), Svelte ({#if/{:else if}), Angular (*ngIf), React (&& JSX, ternary in JSX)
      local conditional_render
      conditional_render=$(grep -oE '\bv-if=|\bv-show=|\bv-else-if=|\{#if[[:space:]]|\{:else[[:space:]]+if[[:space:]]|\*ngIf=|\{[^}]*&&[[:space:]]*<|\{[^}]*\?[[:space:]]*<' "$file" 2>/dev/null | wc -l | tr -d ' ')
      conditional_render=${conditional_render:-0}

      # form_state_field — fields declared in `type FormValues = { ... }` or
      # `interface FormValues { ... }`. The canonical V2 idiom for typed
      # form-state ports (vee-validate / react-hook-form / formik / generic
      # `useForm<FormValues>(...)` shapes). V1-style files using direct
      # `v-model="formData.<name>"` continue to register under v_model;
      # V2-style files using <FormField> wrappers + a typed FormValues record
      # would otherwise count zero. Brace-tracking awk handles nested types.
      local form_state_field
      form_state_field=$(awk '
        /^(type|interface)[ \t]+FormValues[ \t]*[={]/ { in_block=1; brace=0 }
        in_block {
          n = gsub(/\{/, "&"); m = gsub(/\}/, "&"); brace += n - m
          print
          if (brace <= 0 && /\}/ && NR > 1) { in_block=0 }
        }
      ' "$file" 2>/dev/null | grep -cE '^[[:space:]]+[a-zA-Z_][a-zA-Z_0-9]*\??[[:space:]]*:' | tr -d ' ')
      form_state_field=${form_state_field:-0}

      # form_state_field_children — depth-1 aggregation. A page that delegates
      # its form to a child component (`<v2-feature-form>`, `<x-form-dialog>`,
      # `<modal-form>`, drawer variants, etc.) registers 0 form fields itself
      # while the child file holds them all. Resolve relative imports +
      # alias-prefixed imports (`@/` mapped to V2_ROOT) and recurse one level.
      local form_state_field_children=0
      local file_dir child_imports child_path child_rel child_v_model child_form_state
      file_dir=$(dirname "$file")
      child_imports=$(grep -oE "import[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(Form|Dialog|Modal|Drawer|Tabs|TabView|TabPanel|Panel)[[:space:]]+from[[:space:]]+['\"][^'\"]+['\"]" "$file" 2>/dev/null \
        | grep -oE "['\"][^'\"]+['\"]" | tr -d "'\"" | sort -u)
      while IFS= read -r child_rel; do
        [[ -z "$child_rel" ]] && continue
        child_path=""
        case "$child_rel" in
          ./*|../*) child_path="${file_dir}/${child_rel}" ;;
          @/*)      child_path="${V2_ROOT%/}/${child_rel#@/}" ;;
          /*)       child_path="$child_rel" ;;
          *)        continue ;;  # bare-module imports skipped (node_modules)
        esac
        # Try the literal path; if missing, try common Vue/TS/JSX extensions.
        if [[ ! -f "$child_path" ]]; then
          for ext in .vue .tsx .ts .jsx .js; do
            [[ -f "${child_path}${ext}" ]] && { child_path="${child_path}${ext}"; break; }
            [[ -f "${child_path%.*}${ext}" ]] && { child_path="${child_path%.*}${ext}"; break; }
          done
        fi
        [[ ! -f "$child_path" ]] && continue
        # Re-extract v_model + form_state from the child (single-level only).
        child_v_model=$(grep -oE 'v-model(:[a-zA-Z-]+)?="[^"]+"' "$child_path" 2>/dev/null | sort -u | wc -l | tr -d ' ')
        child_v_model=${child_v_model:-0}
        child_form_state=$(awk '
          /^(type|interface)[ \t]+FormValues[ \t]*[={]/ { in_block=1; brace=0 }
          in_block {
            n = gsub(/\{/, "&"); m = gsub(/\}/, "&"); brace += n - m
            print
            if (brace <= 0 && /\}/ && NR > 1) { in_block=0 }
          }
        ' "$child_path" 2>/dev/null | grep -cE '^[[:space:]]+[a-zA-Z_][a-zA-Z_0-9]*\??[[:space:]]*:' | tr -d ' ')
        child_form_state=${child_form_state:-0}
        # Use whichever form-state idiom dominates in the child.
        if [[ $child_form_state -gt $child_v_model ]]; then
          form_state_field_children=$(( form_state_field_children + child_form_state ))
        else
          form_state_field_children=$(( form_state_field_children + child_v_model ))
        fi
      done <<< "$child_imports"

      # form_total — the comparator the match check should consume for the
      # form-field axis. max(v_model, form_state_field) picks whichever idiom
      # the file actually uses; child counts are additive on top.
      local form_total=$v_model
      [[ $form_state_field -gt $form_total ]] && form_total=$form_state_field
      form_total=$(( form_total + form_state_field_children ))

      echo "v_model=$v_model"
      echo "form_state_field=$form_state_field"
      echo "form_state_field_children=$form_state_field_children"
      echo "form_total=$form_total"
      echo "dropdown=$dropdown"
      echo "button=$button"
      echo "click_handler=$click_handler"
      echo "permission_gate=$permission_gate"
      echo "tabs=$tabs"
      echo "route_def=$route_def"
      echo "input_html=$input_html"
      echo "conditional_render=$conditional_render"
      ;;
    backend)
      # route_handler — request entry points across NestJS, Express, Fastify, Laravel,
      # Django, FastAPI, Flask, Rails, Sinatra, Spring, Go (gin/echo), Phoenix, ASP.NET.
      local route_handler
      route_handler=$(grep -oE \
"@(Get|Post|Put|Delete|Patch|All)[[:space:]]*\(|\
@(Get|Post|Put|Delete|Patch)Mapping[[:space:]]*\(|\
@RequestMapping[[:space:]]*\(|\
\bapp\.(get|post|put|delete|patch|all)[[:space:]]*\(|\
\brouter\.(get|post|put|delete|patch|all)[[:space:]]*\(|\
\bfastify\.(get|post|put|delete|patch)[[:space:]]*\(|\
Route::(get|post|put|delete|patch|any|match)[[:space:]]*\(|\
@app\.(get|post|put|delete|patch|route)[[:space:]]*\(|\
@router\.(get|post|put|delete|patch)[[:space:]]*\(|\
@blueprint\.route[[:space:]]*\(|\
\bpath[[:space:]]*\([\"\\']|\
\bre_path[[:space:]]*\([\"\\']|\
\burl[[:space:]]*\([\"\\']|\
^[[:space:]]*(get|post|put|delete|patch)[[:space:]]+[\"\\']/|\
\.(GET|POST|PUT|DELETE|PATCH)[[:space:]]*\(|\
\[Http(Get|Post|Put|Delete|Patch)\]|\
\bbefore[[:space:]]+[\"\\']/" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      route_handler=${route_handler:-0}

      # dto_class — request / response / schema shapes across major language idioms.
      # TS/JS classes & interfaces, Pydantic BaseModel, DRF Serializer, Java/Spring DTOs,
      # Ruby form objects, Go structs, C# DTOs, Phoenix/Ecto schemas, @dataclass.
      local dto_class
      dto_class=$(grep -oE \
"^[[:space:]]*(export[[:space:]]+|public[[:space:]]+|private[[:space:]]+|internal[[:space:]]+|sealed[[:space:]]+|abstract[[:space:]]+)*(class|interface)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(Dto|Request|Response|Schema|Serializer|Resource|Form|VO|Bean|ViewModel)\b|\
^[[:space:]]*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([[:space:]]*BaseModel[[:space:]]*\)|\
^[[:space:]]*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*Serializer[[:space:]]*\(|\
^@dataclass\b|\
^[[:space:]]*type[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(Request|Response|Dto)[[:space:]]+struct\b|\
^[[:space:]]*defmodule[[:space:]]+[A-Za-z_.][A-Za-z0-9_.]*(Schema|Request|Response)\b" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      dto_class=${dto_class:-0}

      # auth_guard — auth/permission enforcement across frameworks.
      local auth_guard
      auth_guard=$(grep -oE \
"@UseGuards[[:space:]]*\(|\
@AuthGuard[[:space:]]*\(|\
@(Pre|Post)Authorize[[:space:]]*\(|\
@Secured[[:space:]]*\(|\
@RolesAllowed[[:space:]]*\(|\
@login_required\b|\
@permission_required\b|\
@require_auth\b|\
LoginRequiredMixin\b|\
PermissionRequiredMixin\b|\
\bDepends[[:space:]]*\([[:space:]]*get_current_user\b|\
\bDepends[[:space:]]*\([[:space:]]*verify_token\b|\
\bauth\.login_required\b|\
\bbefore_action[[:space:]]+:authenticate|\
\bbefore_filter[[:space:]]+:authenticate|\
\bauthenticate_user!|\
\bmiddleware[[:space:]]*\([[:space:]]*[\"\\']auth|\
->middleware[[:space:]]*\(|\
\bplug[[:space:]]+:authenticate\b|\
\bplug[[:space:]]+Auth\b|\
\[Authorize\]|\[Authorize\(|\
\bRequireAuth[[:space:]]*\(|\
\.use[[:space:]]*\([[:space:]]*[\"\\']auth|\
passport\.authenticate[[:space:]]*\(" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      auth_guard=${auth_guard:-0}

      # validator — per-field validation decorators / schema declarations across stacks.
      # TS class-validator, Joi/Yup/Zod, Pydantic Field/validator, DRF fields,
      # Java Bean Validation, Rails validates, Laravel rule strings, Go struct tags, ASP.NET attrs.
      local validator
      validator=$(grep -oE \
"@(IsString|IsNumber|IsBoolean|IsEmail|IsOptional|IsNotEmpty|MinLength|MaxLength|IsEnum|ValidateNested|Min|Max|IsInt|IsDate|IsArray|IsUUID|IsUrl|Matches)[[:space:]]*\(|\
\bJoi\.(object|string|number|boolean|array|date)[[:space:]]*\(|\
\byup\.(object|string|number|boolean|array|date)[[:space:]]*\(|\
\bz\.(object|string|number|boolean|array|date|enum|union)[[:space:]]*\(|\
\bField[[:space:]]*\(|\
\bvalidator[[:space:]]*\(|\
[A-Za-z_]+Field[[:space:]]*\(|\
^[[:space:]]*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*Schema\b|\
@(NotNull|NotBlank|Size|Email|Pattern|Valid)\b|\
^[[:space:]]*validates[[:space:]]+:[a-z_]+|\
[\"\\'](required|email|min|max|nullable|integer|numeric)[\"\\']|\
\bvalidate:\"|\
\[(Required|MaxLength|MinLength|EmailAddress|StringLength|RegularExpression|Range)\]" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      validator=${validator:-0}

      # service_method — only counted when filename matches a service/handler shape.
      # Match public methods across language idioms (TS/JS, Python def, Go func, Ruby def, Java/C# methods).
      local service_method=0
      case "$file" in
        *service.ts|*Service.ts|*_service.py|*service.js|*Service.js|*service.go|*service.rb|*Service.java|*Service.cs|*service.ex|*service.exs|*service.kt|*Service.kt)
          service_method=$(grep -oE \
"^[[:space:]]*(public|private|protected|async)?[[:space:]]*(async[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([^)]*\)[[:space:]]*[:{]|\
^[[:space:]]*def[[:space:]]+[a-z_][a-zA-Z0-9_]*[[:space:]]*\(|\
^[[:space:]]*func[[:space:]]+(\([^)]+\)[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(|\
^[[:space:]]*fn[[:space:]]+[a-z_][a-zA-Z0-9_]*[[:space:]]*\(|\
^[[:space:]]*(public|private|protected|internal)[[:space:]]+[A-Za-z_<>][A-Za-z0-9_<>,[:space:]]*[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
          service_method=${service_method:-0}
          ;;
      esac

      # exception_throw — error contract surface across languages.
      local exception_throw
      exception_throw=$(grep -oE \
"throw[[:space:]]+new[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(Error|Exception)\b|\
raise[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(Error|Exception)\b|\
abort[[:space:]]*\(|\
\berrors\.New[[:space:]]*\(|\
\bfmt\.Errorf[[:space:]]*\(|\
\{:error,|\
panic[[:space:]]*\(" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      exception_throw=${exception_throw:-0}

      # db_query — write/read sites across ORMs and raw SQL.
      # Generic ORM verbs, Eloquent ::, Active Record .where, SQLAlchemy .query/.filter,
      # Django ORM objects.filter/get, Ecto Repo.X, raw SQL keywords.
      local db_query
      db_query=$(grep -oEi \
"\.findOne[[:space:]]*\(|\
\.findAll[[:space:]]*\(|\
\.findMany[[:space:]]*\(|\
\.find[[:space:]]*\(|\
\.findBy[a-zA-Z]*[[:space:]]*\(|\
\.find_by[[:space:]]*\(|\
\.create[[:space:]]*\(|\
\.update[[:space:]]*\(|\
\.delete[[:space:]]*\(|\
\.save[[:space:]]*\(|\
\.insert[[:space:]]*\(|\
\.select[[:space:]]*\(|\
\.where[[:space:]]*\(|\
\.join[[:space:]]*\(|\
::where[[:space:]]*\(|\
::find[[:space:]]*\(|\
::create[[:space:]]*\(|\
\bobjects\.(filter|get|create|all|exclude)[[:space:]]*\(|\
\bdb\.session\.query[[:space:]]*\(|\
\bRepo\.(get|all|insert|update|delete|one)\b|\
\bSELECT\b|\bINSERT[[:space:]]+INTO\b|\bUPDATE\b|\bDELETE[[:space:]]+FROM\b" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      db_query=${db_query:-0}

      # event_emit — pub/sub surface across stacks.
      local event_emit
      event_emit=$(grep -oE \
"\.emit[[:space:]]*\(|\
\.publish[[:space:]]*\(|\
\.broadcast[[:space:]]*\(|\
\bdispatch[[:space:]]*\(|\
@OnEvent[[:space:]]*\(|\
@EventListener[[:space:]]*\(|\
\bsignals\.[a-zA-Z_][a-zA-Z0-9_]*\.send[[:space:]]*\(|\
applicationEventPublisher\.publishEvent[[:space:]]*\(|\
Phoenix\.PubSub\.broadcast[[:space:]]*\(|\
ActiveSupport::Notifications\.publish[[:space:]]*\(" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      event_emit=${event_emit:-0}

      echo "route_handler=$route_handler"
      echo "dto_class=$dto_class"
      echo "auth_guard=$auth_guard"
      echo "validator=$validator"
      echo "service_method=$service_method"
      echo "exception_throw=$exception_throw"
      echo "db_query=$db_query"
      echo "event_emit=$event_emit"
      ;;
    data)
      # SQL-ish files PLUS migration-tool DSLs (Knex, Prisma, TypeORM, ActiveRecord,
      # Alembic, Mongoose). table_def, column_def, foreign_key, index_def, constraint, migration_file.
      local table_def column_def foreign_key index_def constraint migration_file=0
      # CREATE TABLE (raw SQL) + Knex/TypeORM createTable() + Rails/Alembic add_table/create_table +
      # Prisma `model X {` + Mongoose `new Schema(`
      table_def=$(grep -ciE \
"CREATE[[:space:]]+TABLE\b|\
\bcreateTable[[:space:]]*\(|\
\bcreate_table\b|\
^[[:space:]]*model[[:space:]]+[A-Z][A-Za-z0-9_]*[[:space:]]*\{|\
\bnew[[:space:]]+Schema[[:space:]]*\(|\
\bmongoose\.Schema[[:space:]]*\(" \
"$file" 2>/dev/null | tr -d ' ')
      table_def=${table_def:-0}

      # column_def — count lines inside CREATE TABLE blocks (rough but workable for raw SQL).
      column_def=$(awk '
        BEGIN { depth=0; cols=0 }
        /CREATE[[:space:]]+TABLE/ { depth=1; next }
        depth==1 && /\(/ { in_body=1; next }
        in_body && /\)[[:space:]]*;/ { in_body=0; depth=0; next }
        in_body && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+/ { cols++ }
        END { print cols }
      ' "$file" 2>/dev/null)
      column_def=${column_def:-0}

      foreign_key=$(grep -ciE "FOREIGN[[:space:]]+KEY\b|REFERENCES\b|\.references[[:space:]]*\(|@relation[[:space:]]*\(" "$file" 2>/dev/null | tr -d ' ')
      foreign_key=${foreign_key:-0}

      # CREATE INDEX (SQL) + addIndex() (Knex/TypeORM) + add_index (Rails/Alembic) +
      # @@index (Prisma) + .index() (Mongoose)
      index_def=$(grep -ciE \
"CREATE[[:space:]]+(UNIQUE[[:space:]]+)?INDEX\b|\
ADD[[:space:]]+(UNIQUE[[:space:]]+)?INDEX\b|\
\baddIndex[[:space:]]*\(|\
\badd_index\b|\
@@index[[:space:]]*\(|\
@@unique[[:space:]]*\(|\
\.index[[:space:]]*\(" \
"$file" 2>/dev/null | tr -d ' ')
      index_def=${index_def:-0}

      constraint=$(grep -ciE "CHECK[[:space:]]*\(|UNIQUE[[:space:]]*\(|NOT[[:space:]]+NULL|@@unique\b|\.notNullable[[:space:]]*\(" "$file" 2>/dev/null | tr -d ' ')
      constraint=${constraint:-0}

      # Filename-shape heuristic for migrations across tools.
      # Raw SQL (timestamp-prefixed), Flyway (V*__), Rails/Alembic (.rb / .py), Knex/TypeORM (.ts/.js with -migration / .migration.).
      case "$(basename "$file")" in
        [0-9]*_*.sql|*migration*.sql|*migration*.py|*migration*.rb|*-migration.ts|*.migration.ts|*.migration.js|V[0-9]*__*.sql)
          migration_file=1
          ;;
      esac

      echo "table_def=$table_def"
      echo "column_def=$column_def"
      echo "foreign_key=$foreign_key"
      echo "index_def=$index_def"
      echo "constraint=$constraint"
      echo "migration_file=$migration_file"
      ;;
    mobile)
      # screen / nav / native-bridge / platform-branch shape across React Native, Flutter,
      # native iOS (UIKit/SwiftUI), native Android (Activity/Fragment).
      local screen=0 text_input nav_route native_call platform_branch
      case "$(basename "$file")" in
        *Screen.tsx|*Screen.jsx|*_screen.dart|*ViewController.swift|*View.swift|*Activity.kt|*Activity.java|*Fragment.kt|*Fragment.java) screen=1 ;;
      esac

      # text_input — RN <TextInput>, Flutter TextField()/TextFormField(), iOS UITextField/SwiftUI TextField, Android EditText
      text_input=$(grep -oE \
'<TextInput\b|<TextField\b|TextField[[:space:]]*\(|TextFormField[[:space:]]*\(|UITextField\b|EditText\b|<EditText\b' \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      text_input=${text_input:-0}

      # nav_route — RN Stack.Screen, Flutter MaterialPageRoute/GoRoute, iOS push/segue, Android Intent/NavController.navigate
      nav_route=$(grep -oE \
'Stack\.Screen\b|MaterialPageRoute\b|GoRoute\b|pushViewController\b|performSegue\b|NavigationLink\b|navController\.navigate\b|startActivity\b' \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      nav_route=${nav_route:-0}

      # native_call — RN NativeModules, Flutter MethodChannel, iOS Bridging-Header symbols, Android JNI native funcs
      native_call=$(grep -oE \
'NativeModules\.[A-Za-z_][A-Za-z0-9_]*|MethodChannel\b|EventChannel\b|@_objc\b|external[[:space:]]+fun\b' \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      native_call=${native_call:-0}

      # platform_branch — RN Platform.OS, Flutter Platform.isIOS/isAndroid, native if-defs
      platform_branch=$(grep -oE \
"Platform\.OS[[:space:]]*===[[:space:]]*['\"]ios|Platform\.OS[[:space:]]*===[[:space:]]*['\"]android|Platform\.isIOS\b|Platform\.isAndroid\b|#if[[:space:]]+os\(iOS\)|#if[[:space:]]+os\(macOS\)" \
"$file" 2>/dev/null | wc -l | tr -d ' ')
      platform_branch=${platform_branch:-0}

      # findViewById / setOnClickListener — Android-specific click surface (extra signal for Android files)
      local android_click
      android_click=$(grep -oE 'findViewById[[:space:]]*[<\(]|setOnClickListener[[:space:]]*\(|@IBAction\b' "$file" 2>/dev/null | wc -l | tr -d ' ')
      android_click=${android_click:-0}
      native_call=$(( native_call + android_click ))

      echo "screen=$screen"
      echo "text_input=$text_input"
      echo "nav_route=$nav_route"
      echo "native_call=$native_call"
      echo "platform_branch=$platform_branch"
      ;;
  esac
}

# Map a primitive class to its expected audit axis section name. Used by
# check_inventory_primitives_match to find evidence of the gap being enumerated.
# Stdout: regex-friendly axis-section title, or empty when no mapping.
primitive_to_axis() {
  case "$1" in
    v_model|input_html|form_state_field|form_state_field_children|form_total) echo "Form fields" ;;
    dropdown)                  echo "Form fields|UI affordances" ;;
    button)                    echo "UI affordances" ;;
    click_handler)             echo "Event handlers" ;;
    permission_gate)           echo "Per-button permission gates" ;;
    tabs)                      echo "Section 0|Navigation Inventory|UI affordances" ;;
    conditional_render)        echo "Reactive lifecycle|UI affordances" ;;
    route_def)                 echo "Section 0|Navigation Inventory" ;;
    route_handler|dto_class)   echo "Inputs|Outputs" ;;
    auth_guard|permission_gate) echo "Auth + permissions" ;;
    validator)                 echo "Inputs" ;;
    db_query)                  echo "Side effects" ;;
    exception_throw)           echo "Error contract" ;;
    event_emit)                echo "Side effects" ;;
    table_def|column_def|foreign_key|index_def|constraint) echo "Schema|Outputs" ;;
    *)                         echo "" ;;
  esac
}

check_inventory_primitives_match() {
  # Stack-aware primitive count comparator. For each meaningful primitive
  # extracted on each side, halt when V2 has < 70% of V1's count AND the
  # audit body doesn't enumerate the gap in the relevant axis section.
  #
  # This supersedes LOC-ratio as the primary auto-promote signal: counting
  # what matters per stack (form fields, buttons, handlers, permission gates,
  # routes, DTOs, schema columns) beats counting raw lines, which can be
  # inflated by verbose markup or comments.
  #
  # Bypass: audit_scope: backend-only frontmatter behaves consistently with
  # check_section_0_evidence — but for backend-* PROJECT_KIND, primitives
  # are computed against backend regexes regardless.
  local feature="$1"; local id="${2:-}"; local tier="${3:-trivial}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0  # check_audit will have already failed

  # Bypass: explicit backend-only UI audit scope (match Section 0 / per-axis enumeration)
  if grep -qE '^audit_scope:[[:space:]]*backend-only' "$file" 2>/dev/null; then
    log_pass "primitive-match: $feature (skipped — audit_scope: backend-only)"
    return 0
  fi

  # Extract V1 + V2 leaf paths from header block (mirroring check_per_axis_enumeration)
  local header_block all_v1_files all_v2_files
  header_block=$(awk 'NR<=25; NR>25 { exit }' "$file" 2>/dev/null)
  all_v1_files=$(echo "$header_block" | awk '
    /^>?[[:space:]]*[Vv]1 path:/ { capture=1 }
    capture && /^>?[[:space:]]*[Vv]2 path:/ { capture=0 }
    capture { print }
  ' | grep -oE '[A-Za-z_./-]+\.(vue|tsx?|jsx?|svelte|html|py|rb|go|java|kt|sql|ts|js)' | sort -u)
  all_v2_files=$(echo "$header_block" | awk '
    /^>?[[:space:]]*[Vv]2 path:/ { capture=1 }
    capture && /^>?[[:space:]]*(ADR|v1_commit|Tier|Verdict|##)/ { capture=0 }
    capture { print }
  ' | grep -oE '[A-Za-z_./-]+\.(vue|tsx?|jsx?|svelte|html|py|rb|go|java|kt|sql|ts|js)' | sort -u)

  # Resolve representative files. Pick the largest candidate by LOC on each
  # side (inline-ports often cite a tab-shell + the actual leaf; the leaf is
  # the larger one). Reuse the helper from check_per_axis_enumeration's
  # closure pattern, but redefined locally for self-containment.
  pick_largest_file_for_primitives() {
    local candidates="$1" root_hint="$2"
    local best="" best_loc=0
    local cand full_path loc
    while IFS= read -r cand; do
      [[ -z "$cand" ]] && continue
      full_path=""
      if [[ -f "$cand" ]]; then
        full_path="$cand"
      elif [[ -n "$root_hint" && -f "${root_hint}/${cand}" ]]; then
        full_path="${root_hint}/${cand}"
      else
        local bn="${cand##*/}"
        if [[ "$root_hint" == "$V1_ROOT" ]]; then
          build_v1_basename_index
          full_path=$(v1_basename_lookup "$bn" 2>/dev/null || echo "")
        else
          build_v2_basename_index
          full_path=$(v2_basename_lookup "$bn" 2>/dev/null || echo "")
        fi
      fi
      [[ -z "$full_path" || ! -f "$full_path" ]] && continue
      loc=$(wc -l < "$full_path" 2>/dev/null | tr -d ' ' || echo 0)
      [[ "$loc" =~ ^[0-9]+$ ]] || loc=0
      if [[ $loc -gt $best_loc ]]; then
        best_loc=$loc
        best="$full_path"
      fi
    done <<< "$candidates"
    echo "$best"
  }

  local v1_full v2_full
  v1_full=$(pick_largest_file_for_primitives "$all_v1_files" "$V1_ROOT")
  v2_full=$(pick_largest_file_for_primitives "$all_v2_files" "$V2_ROOT")

  # If neither side resolved to a real file, this isn't a leaf-level audit — skip
  if [[ -z "$v1_full" && -z "$v2_full" ]]; then
    return 0
  fi

  # Determine effective project kind (default frontend-vue3 with warning if anchors
  # didn't load PROJECT_KIND). Note: PROJECT_KIND is a global already populated by
  # load_project_anchors with a non-empty default at script start.
  local pk="${PROJECT_KIND:-frontend-vue3}"
  if [[ -z "$PROJECT_KIND" ]]; then
    log_warn "primitive-match: PROJECT_KIND not set; defaulting to frontend-vue3 for $feature"
  fi

  # Read overall verdict from frontmatter (`> Verdict: ...`)
  local verdict is_parity=0
  verdict=$(awk '/^>?[[:space:]]*[Vv]erdict:/ {sub(/^>?[[:space:]]*[Vv]erdict:[[:space:]]*/, ""); print; exit}' "$file" 2>/dev/null | head -1)
  if echo "$verdict" | grep -qiE '^PARITY\b|^parity-?clean\b|\bPASS\b'; then
    is_parity=1
  fi

  # Extract primitives from each side
  local v1_prims v2_prims
  v1_prims=$(extract_inventory_primitives "$v1_full" "$pk")
  v2_prims=$(extract_inventory_primitives "$v2_full" "$pk")

  # Walk every primitive present on the V1 side. For each, compute V2's count
  # and compare. Drift fires when V1 > 0 AND V2 / V1 < 0.7 (V2 missing > 30%).
  local violations=0
  local primitive v1_count v2_count drift gap_axis citations_in_axis
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    primitive="${line%%=*}"
    v1_count="${line#*=}"
    [[ "$v1_count" =~ ^[0-9]+$ ]] || continue
    [[ $v1_count -eq 0 ]] && continue   # nothing to compare on this primitive

    # Form-field axis: form_total is the canonical comparator (it folds
    # v_model + form_state_field + child-component aggregation). Skip the
    # constituent primitives so a single form-field gap fires once, not 3×.
    case "$primitive" in
      v_model|form_state_field|form_state_field_children) continue ;;
    esac

    v2_count=$(echo "$v2_prims" | awk -F= -v k="$primitive" '$1 == k { print $2; exit }')
    [[ -z "$v2_count" ]] && v2_count=0
    [[ "$v2_count" =~ ^[0-9]+$ ]] || v2_count=0

    # Threshold: V2 must have ≥ 70% of V1's count (i.e. V2 * 100 >= V1 * 70)
    if [[ $(( v2_count * 100 )) -ge $(( v1_count * 70 )) ]]; then
      continue
    fi

    drift=$(( v1_count - v2_count ))
    gap_axis=$(primitive_to_axis "$primitive")

    # Trivial-tier softening: warn-only for small drift (≤5) when verdict is PARITY.
    # DRIFT / non-PARITY rows must NOT bypass — they fall through to DRIFT enumeration below.
    if [[ "$tier" == "trivial" && $is_parity -eq 1 && $drift -le 5 ]]; then
      log_warn "primitive-match: '$primitive' V1=$v1_count V2=$v2_count (gap=$drift) on trivial-tier PARITY row $feature — small drift; verify manually or promote tier."
      continue
    fi

    # Count enumeration evidence inside the relevant axis section. The axis
    # body is the slice between "### N. <axis>" and the next "### " heading
    # (or "## " section break). path:line citations inside that slice are
    # the per-row enumeration the discipline rule mandates.
    citations_in_axis=0
    if [[ -n "$gap_axis" ]]; then
      # gap_axis may contain "|" alternations ("Form fields|UI affordances").
      # For each candidate axis, grab body + count citations; sum.
      local axis_alt total=0
      IFS='|' read -r -a axis_alts <<< "$gap_axis"
      for axis_alt in "${axis_alts[@]}"; do
        # Allow either "### N. <axis>" or "## <axis>" headings
        local body c
        body=$(awk -v pat="^#{2,4}[[:space:]]+([0-9]+\\.[[:space:]]+)?${axis_alt}\\b" '
          $0 ~ pat { capture=1; next }
          capture && /^#{2,4}[[:space:]]/ { exit }
          capture { print }
        ' "$file" 2>/dev/null)
        c=$(echo "$body" | grep -oE '[A-Za-z_./-]+\.(vue|tsx?|jsx?|svelte|html|py|rb|go|java|kt|sql|ts|js):[0-9]+' | wc -l | tr -d ' ')
        c=${c:-0}
        total=$(( total + c ))
      done
      citations_in_axis=$total
    fi

    # If verdict is PARITY but a primitive class shows V2 < 70% of V1 → halt
    # regardless of axis enumeration. PARITY contradicts an unaccounted gap.
    if [[ $is_parity -eq 1 ]]; then
      log_fail "primitive-match: '$primitive' has V1=$v1_count V2=$v2_count (gap=$drift) on PARITY verdict in $file. Verdict contradicted by primitive inventory; either re-classify as DRIFT or explain the drop in '$gap_axis' axis (e.g. V1 had dead code, fields are legacy, etc.) with v1+v2 path:line citations. Citations in axis: $citations_in_axis < drift: $drift."
      violations=$((violations + 1))
      continue
    fi

    # Verdict is DRIFT (or other). Audit must enumerate every missing primitive in the relevant axis.
    # Include trivial tier: non-PARITY trivial rows must not silently skip enumeration.
    if [[ $is_parity -eq 0 ]]; then
      if [[ $citations_in_axis -lt $drift ]]; then
        log_fail "primitive-match: '$primitive' V1=$v1_count V2=$v2_count (gap=$drift) but axis '$gap_axis' enumerates only $citations_in_axis path:line citations in $file (DRIFT / non-PARITY). Audit MUST enumerate every missing primitive per migration-discipline.md § Per-axis enumeration."
        violations=$((violations + 1))
      fi
    fi
  done <<< "$v1_prims"

  if [[ $violations -gt 0 ]]; then
    return 1
  fi

  # Pass message — summarise the primitive comparison so reviewers see what was checked
  local v1_summary v2_summary
  v1_summary=$(echo "$v1_prims" | tr '\n' ' ')
  v2_summary=$(echo "$v2_prims" | tr '\n' ' ')
  log_pass "primitive-match: $feature (project_kind=$pk; V1: $v1_summary; V2: $v2_summary)"
  return 0
}

check_adr_signoff_completed() {
  # Failure mode this guards against: an audit cites "(per ADR-NNN)" to close an
  # axis as proof-of-completion when the cited ADR is Status: accepted but its
  # sign-off checklist has items unchecked — the ADR was a plan, not a record of
  # completion. When an audit cites an ADR as proof-of-completion, the validator
  # must verify the ADR's sign-off is actually completed. Halt if any unchecked.
  local feature="$1"; local id="${2:-}"
  local file
  file=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$file" ]] && return 0

  # Find every ADR-NNN reference in the audit
  local adr_refs
  adr_refs=$(grep -oE 'ADR-[0-9]{3,4}' "$file" 2>/dev/null | sort -u)
  [[ -z "$adr_refs" ]] && return 0

  # Project's ADR root (default ai/decisions/)
  local adr_root="ai/decisions"
  local violations=0

  local adr
  for adr in $adr_refs; do
    local adr_num
    adr_num="${adr#ADR-}"
    # ADR-NNN may resolve to multiple files when multiple ADRs share the NNN prefix
    # (e.g. 010-fastmodification-url-restructure.md AND 010-phase-9-tier-classifications.md).
    # We check ALL matches; if ANY has unchecked signoff + completion citation, halt.
    # This is the safe-by-default reading.
    local adr_files
    adr_files=$(find "$adr_root" -maxdepth 2 -type f \( -name "${adr}-*.md" -o -name "${adr_num}-*.md" \) 2>/dev/null)
    if [[ -z "$adr_files" ]]; then
      log_warn "ADR signoff check: $adr cited in $file but file not found under $adr_root/ — citation may be malformed."
      continue
    fi

    # Detect citation context — was the ADR cited as proof-of-completion?
    # Search for tokens around "ADR-NNN" in the audit body.
    local context_lines
    context_lines=$(grep -nE "(per ${adr}\\b|${adr} (cover|covers|covered)|fixed (per|via) ${adr}|addressed by ${adr}|\\(per ${adr}\\)|closed (per|via) ${adr}|resolved (per|via|by) ${adr}|reconciled (per|via) ${adr}|restored (per|via) ${adr}|${adr}: accepted|${adr} accepted)" "$file" 2>/dev/null || true)
    local proof_of_completion=0
    if [[ -n "$context_lines" ]]; then
      proof_of_completion=1
    fi

    # Iterate every matching ADR file (collision tolerance).
    local adr_file
    while IFS= read -r adr_file; do
      [[ -z "$adr_file" ]] && continue
      # Locate the Sign-off / Sign off / Acceptance section.
      # POSIX awk doesn't support \b — use simple line-prefix patterns instead.
      local signoff_block
      signoff_block=$(awk '
        /^#{2,4}[[:space:]]+[Ss]ign[- ]?off([[:space:]]|$)/   { capture=1; next }
        /^#{2,4}[[:space:]]+[Ss]ignoff([[:space:]]|$)/        { capture=1; next }
        /^#{2,4}[[:space:]]+[Aa]cceptance([[:space:]]|$|[[:space:]]+criteria)/ { capture=1; next }
        capture && /^#{2,4}[[:space:]]/ { exit }
        capture { print }
      ' "$adr_file" 2>/dev/null)

      if [[ -z "$signoff_block" ]]; then
        if [[ $proof_of_completion -eq 1 ]]; then
          log_warn "ADR signoff check: $adr ($adr_file) has no Sign-off section; cannot verify completion status. Audit cites it as proof-of-completion — consider adding a Sign-off block to the ADR or making the citation neutral."
        fi
        continue
      fi

      # Count checked vs unchecked
      local unchecked_count checked_count
      unchecked_count=$(echo "$signoff_block" | grep -cE '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' || echo 0)
      checked_count=$(echo "$signoff_block" | grep -cE '^[[:space:]]*-[[:space:]]+\[[xX]\]' || echo 0)
      unchecked_count=${unchecked_count:-0}; checked_count=${checked_count:-0}
      [[ "$unchecked_count" =~ ^[0-9]+$ ]] || unchecked_count=0
      [[ "$checked_count" =~ ^[0-9]+$ ]] || checked_count=0

      if [[ $unchecked_count -ge 1 ]]; then
        if [[ $proof_of_completion -eq 1 ]]; then
          local first_ctx
          first_ctx=$(echo "$context_lines" | head -1 | sed 's/^[0-9]*://; s/^[[:space:]]*//' | head -c 160)
          log_fail "ADR signoff incomplete: audit $file cites $adr as proof-of-completion ('${first_ctx}…') but $adr_file Sign-off has $unchecked_count unchecked / $checked_count checked. ADR is a plan not a record. Re-verify the work was actually done OR open a child ledger row to track the remaining work OR rephrase the citation to be neutral ('see $adr' rather than 'per $adr')."
          violations=$((violations + 1))
          break  # one halt per ADR is enough
        else
          [[ $QUIET -eq 0 ]] && echo "  ▸ $adr cited (neutrally) in $file; sign-off has $unchecked_count unchecked items in $adr_file (informational)."
        fi
      fi
    done <<< "$adr_files"
  done

  if [[ $violations -gt 0 ]]; then
    return 1
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

# migration-discipline.md § "ADRs for V1↔V2 divergence require user_decision_quote:".
# Every ai/decisions/*-v2-break.md MUST carry a NON-EMPTY `user_decision_quote:` line — a
# verbatim quote of the user explicitly choosing keep-V2. Empty / placeholder / TODO → halt.
# This blocks the agent-self-ratified-ADR anti-pattern (the Phase-7 ~6-ADR incident): an
# agent legitimizing its own V2 deviation by drafting a quote-less ADR. Repo-global; runs once.
ADR_QUOTE_CHECKED=0
check_adr_user_decision_quote() {
  [[ "${ADR_QUOTE_CHECKED:-0}" == "1" ]] && return 0
  ADR_QUOTE_CHECKED=1
  local rc=0 f any=0
  for f in ai/decisions/*-v2-break.md; do
    [[ -f "$f" ]] || continue
    any=1
    local q val
    q=$(grep -iE '^[[:space:]]*user_decision_quote:' "$f" 2>/dev/null | head -1)
    if [[ -z "$q" ]]; then
      log_fail "$(basename "$f"): missing 'user_decision_quote:' — a V1↔V2 divergence ADR MUST quote the user choosing keep-V2, else the default closure reverts to 'edit V2 to match V1'. See migration-discipline.md."
      rc=1; continue
    fi
    val="${q#*:}"
    val=$(printf '%s' "$val" | sed -E "s/^[[:space:]]*//; s/[[:space:]]*$//; s/^[\"']//; s/[\"']$//")
    if [[ -z "$val" ]] || printf '%s' "$val" | grep -qiE '^(<.*>|todo|tbd|n/?a|\.\.\.)$'; then
      log_fail "$(basename "$f"): 'user_decision_quote:' is empty/placeholder — needs a verbatim user quote (e.g. \"I prefer the new dropdown\" — user, <date>)."
      rc=1; continue
    fi
  done
  [[ $any -eq 1 && $rc -eq 0 ]] && log_pass "every *-v2-break.md carries a real user_decision_quote"
  return $rc
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

  # #13 — portability: if the project declared its OWN fingerprints in _v2-anchors.md, use those
  # (the hardcoded case-block above is the built-in REFERENCE set, kept as the fallback).
  if [[ ${#PROJECT_FINGERPRINTS[@]} -gt 0 ]]; then
    fingerprints=("${PROJECT_FINGERPRINTS[@]}")
    [[ $QUIET -eq 0 ]] && echo "  v2-structure: ${#fingerprints[@]} project fingerprint(s) from _v2-anchors.md"
  elif [[ ${#fingerprints[@]} -gt 0 && $QUIET -eq 0 ]]; then
    echo "  v2-structure: using ${#fingerprints[@]} built-in reference fingerprints (PROJECT_KIND=$PROJECT_KIND) — declare a forbidden_patterns: list in _v2-anchors.md for project-specific detection (#13)"
  fi

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
  # When gaps were tracked, audit body should mention gap IDs / drift (forgery guard).
  if [[ "$gaps_in" =~ ^[1-9][0-9]*$ ]] && [[ "$gaps_in" -gt 0 ]]; then
    local audit_g
    audit_g=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
    if [[ -n "$audit_g" && -f "$audit_g" ]]; then
      if ! grep -qE 'GAP-[0-9]+|gaps_in|gaps_closed|DRIFT|Finding|gap_count' "$audit_g"; then
        if [[ $STRICT -eq 1 ]]; then
          log_fail "[strict] ledger gaps_in=$gaps_in but audit $audit_g lacks gap/drift enumeration markers — audit may be out of sync with ledger"
          return 1
        fi
        log_warn "ledger gaps_in=$gaps_in but audit $audit_g has no obvious gap enumeration markers — verify body lists each gap"
      fi
    fi
  fi
  log_pass "gap-count parity: $feature ($gaps_in gaps in, $gaps_closed closed)"
  return 0
}

# Six-axis dead-V1 reachability (cron / queue / route / admin / deploy / runbook) — discipline § zombie port.
check_migration_reachability_axes() {
  local feature="$1"; local id="${2:-}"
  local rf=""
  if [[ -n "$id" && -f "ai/migration/reachability/${id}-${feature}.md" ]]; then
    rf="ai/migration/reachability/${id}-${feature}.md"
  elif [[ -f "ai/migration/reachability/${feature}.md" ]]; then
    rf="ai/migration/reachability/${feature}.md"
  fi
  if [[ ! -f "$rf" ]]; then
    log_warn "6-axis reachability not documented — add ai/migration/reachability/${feature}.md (see scripts/migration-reachability.sh)"
    [[ $STRICT -eq 1 ]] && { log_fail "[strict] missing reachability doc for $feature"; return 1; }
    return 0
  fi
  # Evidence-based (#15): the OLD keyword scorer grepped the whole file, but the template's own
  # axis labels match all 6 keyword groups — so a BLANK template scored 6/6 and the Zombie-Port
  # gate was unenforceable. Parse each axis ROW instead: decision must be yes|no|n/a (NOT the
  # "yes / no / n/a" placeholder) AND carry non-empty evidence. A blank template now fails.
  local total=0 filled=0 line axis dec ev
  while IFS= read -r line; do
    echo "$line" | grep -qiE '^\|[[:space:]]*Axis\b' && continue
    echo "$line" | grep -qE  '^\|[-: |]+\|[[:space:]]*$' && continue
    axis=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    dec=$(echo  "$line" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    ev=$(echo   "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [[ -z "$axis" ]] && continue
    total=$((total + 1))
    { [[ -z "$dec" ]] || echo "$dec" | grep -qiE 'yes[[:space:]]*/[[:space:]]*no'; } && continue
    echo "$dec" | grep -qiE '^(yes|no|n/?a)$' || continue
    [[ -z "$ev" ]] && continue
    filled=$((filled + 1))
  done < <(grep -E '^\|' "$rf" 2>/dev/null)
  if [[ $total -ge 6 && $filled -eq $total ]]; then
    log_pass "reachability axes fully documented ($filled/$total decided with evidence): $rf"
  else
    log_warn "reachability doc $rf incomplete ($filled/$total axes decided with evidence; need all 6 — a blank template no longer counts)"
    [[ $STRICT -eq 1 ]] && { log_fail "[strict] reachability doc incomplete: $rf ($filled/$total)"; return 1; }
  fi
  return 0
}

# Cutover Stage B–D evidence (metrics snapshots) — parity-auditor Stages B–D are narrative-only without files.
check_cutover_evidence_for_status() {
  local feature="$1"; local id="$2"; local status="$3"
  case "${status// /}" in
    V2-shadow|V2-canary|V2-only)
      local dir="ai/migration/cutover-evidence"
      [[ ! -d "$dir" ]] && mkdir -p "$dir" 2>/dev/null || true
      local found=""
      found=$(find "$dir" -maxdepth 1 \( -name "${id}-${feature}.json" -o -name "${feature}.json" -o -name "${id}-${feature}-*.json" \) -print -quit 2>/dev/null || true)
      if [[ -n "$found" ]]; then
        log_pass "cutover evidence present: $found"
        return 0
      fi
      log_warn "status=$status but no cutover evidence JSON in ai/migration/cutover-evidence/ — add shadow/canary/KPI snapshot (see templates/packs/migration/_examples/cutover-evidence-stage.json)"
      [[ $STRICT -eq 1 ]] && { log_fail "[strict] cutover evidence JSON required for status=$status"; return 1; }
      ;;
  esac
  return 0
}

check_tolerance_loosening_adr_evidence() {
  local feature="$1"; local id="${2:-}"
  local audit
  audit=$(resolve_artifact_path "$AUDITS_DIR" "$feature" "$id")
  [[ -z "$audit" || ! -f "$audit" ]] && return 0
  local tol=""
  tol=$(find . -path "*/parity/${feature}/tolerance.yaml" -print -quit 2>/dev/null)
  [[ -z "$tol" ]] && tol=$(find . -path "*/parity/${id}-${feature}/tolerance.yaml" -print -quit 2>/dev/null)
  [[ -z "$tol" || ! -f "$tol" ]] && return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  git diff --quiet HEAD -- "$tol" 2>/dev/null && return 0
  if grep -qiE 'ADR-[0-9]{3,4}|tolerance.*ADR|loosen.*ADR|Tightening tolerance|tolerance.*reviewer' "$audit"; then
    log_pass "tolerance.yaml differs from HEAD — audit cites ADR / tolerance discipline: $audit"
    return 0
  fi
  log_warn "tolerance.yaml differs from git HEAD but audit may not document ADR sign-off for loosening — $audit"
  [[ $STRICT -eq 1 ]] && { log_fail "[strict] tolerance change requires ADR citation in audit per parity-auditor § Tolerance decisions"; return 1; }
  return 0
}

check_port_diff_scope_warning() {
  local feature="$1"; local id="$2"
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  local ledger_block v2_path
  ledger_block=$(awk -v id="$id" '$0 ~ ("^id: " id "$") { in_block=1 } in_block { print } in_block && /^```/ { exit }' "$LEDGER_PATH" 2>/dev/null)
  v2_path=$(echo "$ledger_block" | grep -m1 '^v2_path:' | sed 's/^v2_path:[[:space:]]*//' | awk '{print $1}')
  [[ -z "$v2_path" ]] || [[ "$v2_path" == "null" ]] && return 0
  local changed
  changed=$(git diff --name-only HEAD 2>/dev/null | head -40)
  [[ -z "$changed" ]] && return 0
  local base
  base=$(echo "$v2_path" | sed 's/\*.*//; s|/[^/]*$||')
  [[ -z "$base" ]] && return 0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      ai/migration/*|.claude/*|CHANGELOG*|docs/*|*.md|package-lock.json|yarn.lock|pnpm-lock.yaml) continue ;;
    esac
    case "$f" in
      ${base}*|${V2_ROOT%/}/*|"${V2_ROOT%/}"/*) ;;
      *)
        log_warn "changed file outside declared v2_path prefix (\`$base\`): $f — verify parity-auditor halt #9 (scope creep)"
        ;;
    esac
  done <<< "$changed"
  return 0
}

check_ledger_row() {
  local id="$1"; local feature="$2"; local status="$3"
  # Check that minimum required fields exist in the ledger row for this id
  local ledger_block
  # 🔴 THE ROW IS A YAML LIST ITEM, SO PARSE ONE.
  #
  # This matched `^id: <id>$` — no leading whitespace, no `- ` marker — while the format
  # migration-ledger.md specifies is `  - id: F001` with the fields indented beneath it.
  # Discovery upstream already handles that shape, so the row WAS found; only its body was
  # invisible here. Every field then read as absent and the row failed with "missing
  # required fields for status=V1-only: feature" — naming a field sitting in the file two
  # lines below the id it had just matched.
  #
  # Two checks disagreeing about one file's format is worse than either being wrong: the
  # row is real enough to report and not real enough to pass. Indented list form and bare
  # `id:` are both accepted now, fields are normalised to column 1 for the `^field:` greps
  # below, and the block ends at the fence OR at the next row — so a later row's fields
  # cannot satisfy this one's requirements. Found by writing this file's first --self-test.
  ledger_block=$(awk -v id="$id" '
    $0 ~ ("^[[:space:]]*-?[[:space:]]*id:[[:space:]]*" id "[[:space:]]*$") {
      in_block=1; line=$0; sub(/^[[:space:]]*-?[[:space:]]*/, "", line); print line; next
    }
    in_block {
      if ($0 ~ /^[[:space:]]*```/) exit
      if ($0 ~ /^[[:space:]]*-[[:space:]]*id:/) exit
      line=$0; sub(/^[[:space:]]*/, "", line); print line
    }
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
    "pending-review")
      # Heavy-tier rows pause here; reviewer_approval must be present AND non-empty (checked below).
      required_for_state=(feature contract plan v1_commit_pinned parity_tests reviewer_approval)
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
  # #14 — reviewer-approval gate. `pending-review` is terminal-non-fix ONLY when reviewer_approval
  # is a real `<reviewer>@<iso>` signoff. A present-but-empty/placeholder line must NOT advance to done.
  if [[ "$status" == "pending-review" ]]; then
    local appr
    appr=$(echo "$ledger_block" | grep -E '^reviewer_approval:' | head -1 | sed 's/^reviewer_approval:[[:space:]]*//; s/[[:space:]]*$//')
    if [[ -z "$appr" ]] || echo "$appr" | grep -qiE '^(<.*>|todo|tbd|pending|none)$'; then
      log_fail "ledger row $id ($feature): status=pending-review but reviewer_approval is empty/placeholder — a heavy-tier row needs a real <reviewer>@<iso> signoff before it can advance to done."
      return 1
    fi
    log_pass "ledger row $id ($feature): reviewer_approval present ($appr)"
  fi
  # Parity-assertion presence: a done-class row must have a recorded parity-run artifact backing it.
  # Existence check only here (content/commit match is enforced by check_parity_run_report). Accept
  # either an inline `parity_runs:` block in the row OR a file under ai/migration/parity-runs/.
  case "$status" in
    "V2-shadow"|"done"|"divergent")
      local has_run=0
      echo "$ledger_block" | grep -qE '^parity_runs:' && has_run=1
      if [[ $has_run -eq 0 ]]; then
        local rf
        rf=$(first_parity_run_file "$feature" "$id")
        [[ -n "$rf" ]] && has_run=1
      fi
      if [[ $has_run -eq 0 ]]; then
        log_fail "ledger row $id ($feature): status=$status but no recorded parity-run artifact — add a parity_runs[] block to the row (result + v1_commit) OR a file at $PARITY_RUNS_DIR/${id:+$id-}${feature}-<run-id>.md. A done-class row's parity claim must be backed by a recorded run (artifact, not a re-executed suite). See migration-discipline.md § halt #3."
        return 1
      fi
      ;;
  esac
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
  check_section_0_evidence "$feature" "$id" || true
  check_per_axis_enumeration "$feature" "$id" "$tier" || true
  check_inventory_primitives_match "$feature" "$id" "$tier" || true
  check_adr_signoff_completed "$feature" "$id" || true
  check_intentional_break_adr "$feature" "$id" || true
  check_adr_user_decision_quote || true
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
  # Parity-assertion gate: a done-class row claiming parity_test=passing MUST have a recorded
  # run-report artifact (ledger parity_runs[] OR ai/migration/parity-runs/<feature>-<run-id>.md)
  # with result=pass against the pinned V1 commit. Artifact-only — never executes tests.
  check_parity_run_report "$feature" "$id" "$status" "$parity_test" || true
  # Phase 9 additions (May 2026 — themes port lessons): every-tier artifact gates
  check_v2_mapping_doc "$feature" "$id" "$tier" || true
  check_api_response_sample "$feature" "$id" || true
  check_migration_reachability_axes "$feature" "$id" || true
  check_cutover_evidence_for_status "$feature" "$id" "$status" || true
  check_tolerance_loosening_adr_evidence "$feature" "$id" || true
  check_port_diff_scope_warning "$feature" "$id" || true
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

  # Parse the `forbidden_patterns:` list (#13) — the exact format _v2-anchors-schema.md §
  # "V1 fingerprints to forbid in V2" documents but the script never read (the doc↔script gap
  # that IS #13). Each entry: `- { regex: '<rx>', severity: <fail|warn>, message: "<msg>" }`.
  # Converted to the internal `<rx>|<sev>|<msg>` form. Lets ANY project declare its own
  # wrappers/primitives instead of inheriting the frozen built-in reference set hardcoded below.
  PROJECT_FINGERPRINTS=()
  while IFS= read -r ln; do
    echo "$ln" | grep -qE '^[[:space:]]*-[[:space:]]*\{.*regex:' || continue
    local rx sev msg
    rx=$(echo "$ln" | sed -nE "s/.*regex:[[:space:]]*'([^']*)'.*/\1/p")
    [[ -z "$rx" ]] && rx=$(echo "$ln" | sed -nE 's/.*regex:[[:space:]]*"([^"]*)".*/\1/p')
    sev=$(echo "$ln" | sed -nE 's/.*severity:[[:space:]]*([a-zA-Z]+).*/\1/p')
    msg=$(echo "$ln" | sed -nE 's/.*message:[[:space:]]*"([^"]*)".*/\1/p')
    [[ -z "$rx" || -z "$sev" ]] && continue
    PROJECT_FINGERPRINTS+=("${rx}|${sev}|${msg:-V1 transposition fingerprint}")
  done < "$ANCHORS_FILE"

  if [[ $QUIET -eq 0 ]]; then
    echo "  anchors: $ANCHORS_FILE (project_kind=$PROJECT_KIND, v2_root=$V2_ROOT, fingerprints=${#PROJECT_FINGERPRINTS[@]})"
  fi
}

# Fail-closed when anchors exist: require explicit project_kind matching schema families.
validate_project_kind_strict() {
  [[ ! -f "$ANCHORS_FILE" ]] && return 0
  local pk
  pk=$(awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$ANCHORS_FILE" 2>/dev/null | grep -m1 '^project_kind:' | sed 's/^project_kind:[[:space:]]*//' | tr -d '"' | tr -d "'")
  [[ -z "$pk" ]] && {
    log_fail "ai/migration/_v2-anchors.md exists but project_kind is unset — set project_kind (fail-closed). See templates/packs/migration/_v2-anchors-schema.md"
    return 1
  }
  case "$pk" in
    frontend-*|backend-*|data-*|mobile-*|mixed|api-other)
      return 0
      ;;
    *)
      log_fail "Unknown project_kind '$pk' in _v2-anchors.md — use frontend-*, backend-*, data-*, mobile-*, mixed, or api-other."
      return 1
      ;;
  esac
}

check_actionable_next_steps() {
  # Per templates/snippets/actionable-next-steps.md: if a final-report.md exists,
  # it MUST end with an `## Actionable next steps` section containing paste-ready
  # commands for every halted / parked / deferred row.
  local report="${1:-ai/migration/final-report.md}"
  [[ ! -f "$report" ]] && return 0

  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$report"; then
    log_fail "final-report missing '## Actionable next steps' section at $report — every halted / parked / deferred row MUST be a paste-ready command (see templates/snippets/actionable-next-steps.md)"
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
    if echo "$args" | grep -qE '/|=|--|\.[a-zA-Z]+|F[0-9]+'; then
      continue
    fi
    log_fail "actionable next-step line looks like prose, not a paste-ready command (no path / flag / extension / ledger-id F<NNN> marker): $line"
    bad=$((bad + 1))
  done <<< "$extracted"

  [[ $bad -gt 0 ]] && return 1
  log_pass "final report ends with paste-ready actionable next steps"
  return 0
}

check_plan_completeness() {
  # Per commands/migration-plan.md § Phase 6, the generated plan.md MUST contain
  # three load-bearing sections AND its Phase 1 foundation MUST cover core
  # primitives. Halts the gate when missing — prevents the all-trivial-by-default
  # bias where heavy-tier rows close without reviewer-approval.
  local plan="${1:-ai/migration/plan.md}"
  [[ ! -f "$plan" ]] && return 0

  local missing=()

  # 1. Cross-cutting audit dimensions section
  if ! grep -qE '^##[[:space:]]+Cross-cutting audit dimensions' "$plan"; then
    missing+=("Cross-cutting audit dimensions section (tenant-isolation / cache-NS / translation-parity / etc.)")
  fi

  # 2. Heavy-tier promoter rollup section
  if ! grep -qE '^##[[:space:]]+Heavy-tier promoter rollup' "$plan"; then
    missing+=("Heavy-tier promoter rollup section (pre-flag auth/payment/order/cart/security rows for reviewer-approval)")
  fi

  # 3. Actionable next steps section (already enforced by check_actionable_next_steps;
  # surfaced here too with plan-specific guidance for clearer error message)
  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$plan"; then
    missing+=("## Actionable next steps section (paste-ready commands per templates/snippets/actionable-next-steps.md)")
  fi

  # 4. Foundation phase contains core primitive language
  # Look at content under "Phase 1" header — should mention at least 2 foundation primitives
  local phase1_block primitives_found=0
  phase1_block=$(awk '
    /^##[[:space:]]+Phase 1/ { in_p1=1; next }
    in_p1 && /^##[[:space:]]+Phase [2-9]/ { in_p1=0 }
    in_p1 { print }
  ' "$plan")
  for keyword in "tenant.*context|RequestContext|AsyncLocalStorage" "cache|Redis" "DomainException|error.*envelope|exception.*filter" "audit.*field|soft.*delete|SoftDelete" "concurrency|p-limit|Promise\.all" "locale|i18n|translation"; do
    echo "$phase1_block" | grep -qiE "$keyword" && primitives_found=$((primitives_found + 1))
  done
  if [[ $primitives_found -lt 2 ]]; then
    missing+=("Phase 1 foundation appears thin — only $primitives_found/6 core primitives (tenant-context / cache / error-envelope / audit / concurrency / locale) referenced; auth/security audits in Phase 1 will be un-verifiable")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fail "plan.md missing required sections (per commands/migration-plan.md § Phase 6 / Phase 4): ${missing[*]}"
    return 1
  fi

  log_pass "plan.md completeness: cross-cutting + heavy-tier rollup + actionable next steps + foundation primitives"
  return 0
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  load_project_anchors
  validate_project_kind_strict || exit 3
  if [[ $QUIET -eq 0 ]]; then
    echo "validate-migration-artifacts.sh"
    echo "  ledger: $LEDGER_PATH"
    if [[ -n "$PHASE" ]]; then echo "  scope:  phase $PHASE"; fi
    if [[ -n "$FEATURE" ]]; then echo "  scope:  feature $FEATURE"; fi
    if [[ $SCAN_ALL -eq 1 ]]; then echo "  scope:  all features"; fi
  fi

  # Pre-check: detect duplicate IDs in the ledger (data-integrity issue).
  # Two rows with the same `id:` cause the validator + reports to skip-or-overwrite each other.
  # Match the canonical INDENTED YAML-list row marker (optional leading whitespace + "- "),
  # then strip the prefix so only the F-id is compared.
  local dupe_ids
  dupe_ids=$(grep -oE '^[[:space:]]*(- )?id: F[0-9]+[a-z]?$' "$LEDGER_PATH" 2>/dev/null \
    | sed -E 's/^[[:space:]]*(- )?id: //' | sort | uniq -d)
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

  check_actionable_next_steps "ai/migration/final-report.md" || true
  check_actionable_next_steps "ai/migration/plan.md" || true
  check_plan_completeness "ai/migration/plan.md" || true

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
