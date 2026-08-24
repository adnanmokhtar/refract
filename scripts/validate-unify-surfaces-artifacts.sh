#!/usr/bin/env bash
# validate-unify-surfaces-artifacts.sh — universal unify-surfaces discipline validator.
#
# Tool-agnostic. Runs from any AI tool's hook system, CI pipeline, or pre-commit.
# Validates the artifact set required by `commands/unify-surfaces.md` for every surface
# category in the progress ledger (or one category with --category=, or all with --all).
#
# The unify-surfaces "ledger" is ai/unify-surfaces/progress.md — a per-category roll-up
# (### <category> [done|in-progress|pending|blocked]) plus the run's final-report.md.
#
# Checks (per commits/unify-surfaces.md § "Hard rules (internal)" + § "Final report contract"):
#   1. actionable-next-steps  — final-report.md ends with a non-empty `## Actionable next steps`
#                               section whose deferrals are paste-ready commands, not prose.
#   2. reuse-before-create    — a category that EXTRACTED a wrapper where _extracted-idioms.md
#                               already names a wrapper for that category is a Reinvented Wrapper
#                               (Reuse-Before-Create violation) → FAIL.
#   3. ledger-row             — every done category row carries the required fields (canonical,
#                               consumers-migrated, commits) and a recognized status keyword.
#   4. honesty-clause         — the run summary block carries the three mandatory honesty lines
#                               (Not validated: / Risks: / Revert:).
#
# Genuinely agent-side (runtime tooling, not deterministic in a validator):
# visual-regression on non-target surfaces, typecheck/lint/test execution, re-detect-to-zero
# (re-runs the per-category inventory). Tagged "(agent-side — not script-enforced)" below.
#
# Usage:
#   validate-unify-surfaces-artifacts.sh --category=<name>      # validate one category
#   validate-unify-surfaces-artifacts.sh --all                  # validate every category
#   validate-unify-surfaces-artifacts.sh --strict               # treat warnings as errors
#   validate-unify-surfaces-artifacts.sh --quiet                # only print failures
#   validate-unify-surfaces-artifacts.sh --check=<name>         # run only the named check
#
# Exit codes:
#   0  — all checks pass
#   1  — at least one check failed
#   2  — usage error / unable to read progress ledger
#   3  — environment error (paths missing, tools missing)
#   4  — data-integrity error (duplicate category rows, malformed ledger)

set -euo pipefail
export LC_ALL=C

# ── Defaults (overridable via ai/unify-surfaces/_anchors.md) ────────────────
UNIFY_DIR="ai/unify-surfaces"
PROGRESS_PATH="$UNIFY_DIR/progress.md"
REPORT_PATH="$UNIFY_DIR/final-report.md"
ANCHORS_FILE="$UNIFY_DIR/_anchors.md"
IDIOMS_FILE="_extracted-idioms.md"

PROJECT_KIND="frontend-vue"        # set per project via _anchors.md

CATEGORY=""
SCAN_ALL=0
STRICT=0
QUIET=0
CHECK_FILTER=""

# ── Args ────────────────────────────────────────────────────────────────────
# ── --self-test ───────────────────────────────────────────────────────────────
# A GOOD fixture that must pass and a BAD one that must fail, both under $repo_root/tmp/.
# Six of the seven validate-*-artifacts.sh scripts shipped without one; writing them found
# three real defects in the five that had none.
run_unify_self_test() {
  local td repo_root rc me
  # Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
  # § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
  _ss="${BASH_SOURCE[0]}"
  while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
  repo_root="$(cd -P "$(dirname "$_ss")/.." && pwd)"
  me="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"; unset _ss _sd
  mkdir -p "$repo_root/tmp"
  td=$(mktemp -d "$repo_root/tmp/unify-selftest.XXXXXX")
  mkdir -p "$td/ai/unify-surfaces" "$td/src"
  printf 'export const Btn = 1\n' > "$td/src/Btn.vue"
  cat > "$td/ai/unify-surfaces/progress.md" <<'FIX'
# Unify surfaces progress

### buttons [done]

Canonical: `src/Btn.vue:1`
Consumers migrated: 3/3
Commits: abc1234
FIX
  cat > "$td/ai/unify-surfaces/final-report.md" <<'FIX'
# Final report

One category unified: buttons.

Not validated: visual regression on the print stylesheet.
Risks: the wrapper changes focus order on nested menus.
Revert: `git revert HEAD`

## Actionable next steps

```bash
npm run test -- src/Btn.vue
```
FIX

  rc=0
  ( cd "$td" && bash "$me" --all >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: the GOOD fixture was rejected (exit $rc)" >&2
    exit 1
  fi

  # Drop one of the three mandatory honesty lines. A report that lists what it DID while
  # omitting what it did not validate is the failure this clause exists to prevent, and it
  # is invisible unless something checks for the line's absence.
  grep -v '^Risks:' "$td/ai/unify-surfaces/final-report.md" > "$td/bad.md"
  mv "$td/bad.md" "$td/ai/unify-surfaces/final-report.md"
  rc=0
  ( cd "$td" && bash "$me" --all >/dev/null 2>&1 ) || rc=$?
  if [[ $rc -eq 0 ]]; then
    rm -rf "$td"
    echo "self-test FAIL: a final report missing the 'Risks:' honesty line was accepted" >&2
    exit 1
  fi

  rm -rf "$td"
  echo "validate-unify-surfaces-artifacts.sh --self-test OK"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --category=*)  CATEGORY="${1#--category=}"; shift ;;
    --all)         SCAN_ALL=1; shift ;;
    --strict)      STRICT=1; shift ;;
    --quiet)       QUIET=1; shift ;;
    --self-test)  run_unify_self_test ;;
    --check=*)     CHECK_FILTER="${1#--check=}"; shift ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--category=NAME | --all] [--strict] [--quiet] [--check=NAME]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$CATEGORY" && "$SCAN_ALL" -eq 0 ]]; then
  echo "Usage: $0 [--category=NAME | --all]" >&2
  exit 2
fi

if [[ ! -f "$PROGRESS_PATH" ]]; then
  echo "FATAL: progress ledger not found at $PROGRESS_PATH" >&2
  echo "Run /unify-surfaces first, OR you're in the wrong directory." >&2
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

# ── Parse progress.md to discover category rows ──────────────────────────────
# Progress format (per unify-surfaces.md § "Progress file shape"):
#   ### <category> [<status>] (date, dur)
#     - Canonical:          ...
#     - Consumers migrated: ...
#     - Wrappers extracted: ...
#     - Wrappers reused:    ...
#     - Commits:            ...
#
# Output: "<category>|<status>"
discover_categories() {
  awk '
    /^###[[:space:]]+/ {
      line=$0
      sub(/^###[[:space:]]+/, "", line)
      cat=line; sub(/[[:space:]]*\[.*/, "", cat)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cat)
      status=""
      if (match(line, /\[[a-z-]+\]/)) {
        status=substr(line, RSTART+1, RLENGTH-2)
      }
      if (cat != "") print cat "|" status
    }
  ' "$PROGRESS_PATH"
}

filter_categories() {
  if [[ -n "$CATEGORY" ]]; then
    grep -i "^${CATEGORY}|" || true
  else
    cat
  fi
}

# Extract the markdown block for one category (lines until the next ### or EOF).
category_block() {
  awk -v cat="$1" '
    /^###[[:space:]]+/ {
      if (in_block) exit
      line=$0; sub(/^###[[:space:]]+/, "", line)
      c=line; sub(/[[:space:]]*\[.*/, "", c)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", c)
      in_block = (tolower(c) == tolower(cat)) ? 1 : 0
      if (in_block) { print; next }
    }
    in_block { print }
  ' "$PROGRESS_PATH"
}

# ── CHECK 1: actionable next steps in the final report ───────────────────────
# Per templates/snippets/actionable-next-steps.md: if a final-report.md exists, it MUST end
# with a non-empty `## Actionable next steps` section whose deferrals are paste-ready commands.
REPORT_CHECKED=0
check_actionable_next_steps() {
  [[ "${REPORT_CHECKED:-0}" == "1" ]] && return 0
  REPORT_CHECKED=1
  local report="${1:-$REPORT_PATH}"
  if [[ ! -f "$report" ]]; then
    [[ $QUIET -eq 0 ]] && echo "  ▸ final-report.md not present at $report (no run report to check)"
    return 0
  fi

  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$report"; then
    log_fail "final-report missing '## Actionable next steps' section at $report — every deferred / skipped consumer + halted category MUST be a paste-ready command (see templates/snippets/actionable-next-steps.md)"
    return 1
  fi

  local extracted
  extracted=$(awk '
    /^##[[:space:]]+Actionable next steps/ { in_sec=1; next }
    in_sec && /^##[[:space:]]/ { in_sec=0 }
    in_sec { print }
  ' "$report")

  # Non-empty: at least one non-blank, non-fence line of content.
  if ! echo "$extracted" | grep -qE '[^[:space:]]'; then
    log_fail "'## Actionable next steps' section is EMPTY at $report — name every deferral as a paste-ready follow-up command, or state 'none — nothing deferred'."
    return 1
  fi

  # Allow an explicit "nothing deferred" escape hatch.
  if echo "$extracted" | grep -qiE '^[[:space:]]*(none|n/a)\b'; then
    log_pass "final report: actionable next steps section present (nothing deferred)"
    return 0
  fi

  if ! echo "$extracted" | grep -qE '^[[:space:]]*```'; then
    log_fail "actionable next steps section has no bash fence at $report — commands must be inside \`\`\`bash\`\`\` so they are paste-ready"
    return 1
  fi

  local bad=0 line
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
  log_pass "final report ends with non-empty, paste-ready actionable next steps"
  return 0
}

# Slice out the "§ Wrappers" section of _extracted-idioms.md (the contract is
# "_extracted-idioms.md § Wrappers § <Category>", per commands/unify-surfaces.md).
# A Wrappers heading is any markdown/section heading whose text mentions Wrappers
# (e.g. "## Wrappers", "### Wrappers", "§ Wrappers"). The slice runs from that
# heading until the next heading at the SAME-or-higher level (i.e. a heading with
# the same-or-fewer leading '#'), so § Wrappers § <Category> sub-headings stay in.
# Prints the section body to stdout (empty if no Wrappers section exists).
wrappers_section_slice() {
  local file="$1"
  awk '
    function hashes(s,  n) { n=0; while (substr(s,n+1,1)=="#") n++; return n }
    {
      level = ($0 ~ /^#+[[:space:]]/) ? hashes($0) : 0
      is_heading = (level > 0)
      if (in_sec && is_heading && level <= sec_level) { in_sec=0 }
      if (!in_sec && is_heading && tolower($0) ~ /wrappers/) {
        in_sec=1; sec_level=level; print; next
      }
      if (in_sec) print
    }
  ' "$file"
}

# ── CHECK 2: reuse-before-create gate ────────────────────────────────────────
# Per § "Hard rules § Reuse-Before-Create": before extracting a new wrapper for a category,
# the agent MUST check _extracted-idioms.md § Wrappers. If idioms ALREADY name a wrapper for
# this category but the progress row says the wrapper was EXTRACTED (forked) rather than
# REUSED / EXTENDED, that's a Reinvented Wrapper → FAIL. Warn-skips when idioms file absent.
check_reuse_before_create() {
  local cat="$1"
  local blk; blk=$(category_block "$cat")

  # Did this category extract a new wrapper? "Wrappers extracted: N" with N>0, OR a Canonical
  # line annotated "(extracted)".
  local extracted_count extracted_anno
  extracted_count=$(printf '%s\n' "$blk" | grep -iE 'Wrappers extracted:' | grep -oE '[0-9]+' | head -1 || echo 0)
  extracted_count=${extracted_count:-0}
  extracted_anno=$(printf '%s\n' "$blk" | grep -iE 'Canonical:.*\(extracted\)' || true)

  if [[ "$extracted_count" -eq 0 && -z "$extracted_anno" ]]; then
    log_pass "$cat: no new wrapper extracted — Reuse-Before-Create N/A"
    return 0
  fi

  if [[ ! -f "$IDIOMS_FILE" ]]; then
    log_warn "$cat: extracted a wrapper but $IDIOMS_FILE not found — cannot verify Reuse-Before-Create (no oracle to check the duplicate against)"
    [[ $STRICT -eq 1 ]] && return 1
    return 0
  fi

  # Does the idioms oracle already name a wrapper for this category under § Wrappers?
  # Categories map to idiom headings: tables→Tables, forms→Forms, headers→PageHeader,
  # tabs→Tabs, filters→FilterPanel, buttons→Button. Match the category word OR its common
  # wrapper noun — but ONLY inside the § Wrappers section (per the documented
  # "_extracted-idioms.md § Wrappers § <Category>" contract), and as a WHOLE WORD so a
  # stray "Button" in unrelated prose elsewhere can't trigger a false-positive halt.
  local needle="$cat"
  case "$cat" in
    headers) needle='headers|PageHeader|Header' ;;
    filters) needle='filters|FilterPanel|Filters' ;;
    buttons) needle='buttons|Button' ;;
    tables)  needle='tables|Table|DataTable' ;;
    forms)   needle='forms|Form' ;;
    tabs)    needle='tabs|Tab' ;;
  esac

  # Scope to the Wrappers section slice — if the oracle has no Wrappers section at
  # all, there is no canonical wrapper to collide with → legitimate extraction.
  local wrappers_slice
  wrappers_slice=$(wrappers_section_slice "$IDIOMS_FILE")
  if [[ -z "${wrappers_slice//[[:space:]]/}" ]]; then
    log_pass "$cat: $IDIOMS_FILE has no § Wrappers section — no pre-existing wrapper to collide with"
    return 0
  fi

  # Whole-word match (mirrors the (^|[^A-Za-z]) idiom used elsewhere in these validators)
  # so "Button" matches but "ButtonGroupLegacyNotes" / inline prose substrings do not.
  if printf '%s\n' "$wrappers_slice" | grep -qiE "(^|[^A-Za-z])($needle)([^A-Za-z]|\$)" 2>/dev/null; then
    log_fail "$cat: progress row EXTRACTED a new wrapper, but $IDIOMS_FILE § Wrappers already names a wrapper for this category — Reinvented Wrapper (Reuse-Before-Create violation: extend the existing wrapper, do NOT fork a parallel one)."
    return 1
  fi

  log_pass "$cat: extracted wrapper has no pre-existing idiom entry under § Wrappers — legitimate extraction"
  return 0
}

# ── CHECK 3: ledger-row completeness ─────────────────────────────────────────
# Every `done` category row MUST carry the fields the run report contract requires:
# Canonical, Consumers migrated, Commits. Non-`done` rows are skipped (not yet at the gate).
check_ledger_row() {
  local cat="$1" status="$2"
  case "$status" in
    done) ;;
    in-progress|pending|"")
      log_warn "$cat: status='${status:-unset}' — not at the gate; skipping row-completeness"
      return 0
      ;;
    blocked|halted)
      log_pass "$cat: status='$status' — terminal blocked state; row-completeness N/A"
      return 0
      ;;
    *)
      log_fail "$cat: unrecognized status '$status' (expected done|in-progress|pending|blocked)"
      return 1
      ;;
  esac

  local blk; blk=$(category_block "$cat")
  local missing=0
  if ! printf '%s\n' "$blk" | grep -qiE 'Canonical:'; then
    log_fail "$cat: done row missing 'Canonical:' field — name the canonical wrapper that won"
    missing=$((missing + 1))
  fi
  if ! printf '%s\n' "$blk" | grep -qiE 'Consumers migrated:'; then
    log_fail "$cat: done row missing 'Consumers migrated:' field — report N/M consumers migrated"
    missing=$((missing + 1))
  fi
  if ! printf '%s\n' "$blk" | grep -qiE 'Commits:'; then
    log_fail "$cat: done row missing 'Commits:' field — one cascade commit per category"
    missing=$((missing + 1))
  fi

  [[ $missing -gt 0 ]] && return 1
  log_pass "$cat: done row carries Canonical + Consumers migrated + Commits"
  return 0
}

# ── CHECK 4: honesty clause in the run summary ───────────────────────────────
# Per § "Hard rules § Honesty clause": every run summary closes with three lines —
# Not validated: / Risks: / Revert:. Omitting the negative space is the Trusted-Summary
# failure mode applied to the run report. Checked against final-report.md.
HONESTY_CHECKED=0
check_honesty_clause() {
  [[ "${HONESTY_CHECKED:-0}" == "1" ]] && return 0
  HONESTY_CHECKED=1
  local report="${1:-$REPORT_PATH}"
  if [[ ! -f "$report" ]]; then
    [[ $QUIET -eq 0 ]] && echo "  ▸ final-report.md not present at $report (no summary to check honesty clause)"
    return 0
  fi

  local missing=0
  grep -qE '^[[:space:]]*Not validated:' "$report" || { log_fail "final-report missing mandatory 'Not validated:' honesty line at $report"; missing=$((missing + 1)); }
  grep -qE '^[[:space:]]*Risks:' "$report"         || { log_fail "final-report missing mandatory 'Risks:' honesty line at $report"; missing=$((missing + 1)); }
  grep -qE '^[[:space:]]*Revert:' "$report"        || { log_fail "final-report missing mandatory 'Revert:' honesty line at $report"; missing=$((missing + 1)); }

  [[ $missing -gt 0 ]] && return 1
  log_pass "final report carries the honesty clause (Not validated: / Risks: / Revert:)"
  return 0
}

# ── Per-category orchestrator ────────────────────────────────────────────────
validate_category() {
  local cat="$1" status="$2"
  TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
  log_section "$cat (status=${status:-unset})"

  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "reuse-before-create" ]]; then
    check_reuse_before_create "$cat"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "ledger-row" ]]; then
    check_ledger_row "$cat" "$status"
  fi
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  load_project_anchors
  if [[ $QUIET -eq 0 ]]; then
    echo "validate-unify-surfaces-artifacts.sh"
    echo "  ledger:  $PROGRESS_PATH"
    echo "  project: $PROJECT_KIND"
    [[ -n "$CATEGORY" ]] && echo "  scope:   category $CATEGORY"
    [[ $SCAN_ALL -eq 1 ]] && echo "  scope:   all categories"
    [[ -n "$CHECK_FILTER" ]] && echo "  check:   $CHECK_FILTER"
  fi

  # Pre-check: duplicate category rows
  local dupes
  dupes=$(discover_categories | cut -d'|' -f1 | sort | uniq -d)
  if [[ -n "$dupes" ]]; then
    echo "FATAL: duplicate category rows in progress.md:" >&2
    echo "$dupes" | sed 's/^/  /' >&2
    exit 4
  fi

  local categories
  categories=$(discover_categories | filter_categories)
  if [[ -z "$categories" ]]; then
    echo "No categories matched the scope. Check progress.md contents." >&2
    exit 2
  fi

  while IFS='|' read -r cat status; do
    [[ -n "$cat" ]] || continue
    validate_category "$cat" "$status"
  done <<< "$categories"

  # Run-level checks (once, regardless of category scope).
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "actionable-next-steps" ]]; then
    log_section "Run-level: actionable next steps (final-report.md)"
    check_actionable_next_steps "$REPORT_PATH" || true
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "honesty-clause" ]]; then
    log_section "Run-level: honesty clause (final-report.md)"
    check_honesty_clause "$REPORT_PATH" || true
  fi

  echo
  echo "── Summary ──"
  echo "  categories checked: $TOTAL_CHECKED"
  echo "  checks passed:      $TOTAL_PASS"
  echo "  checks failed:      $TOTAL_FAIL"

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
    echo "Note: the following remain AGENT-side enforcement (need runtime tooling — the script"
    echo "      cannot run the test suite / a11y / visual-regression / re-detect inventory):"
    echo "      visual-regression-on-non-target-surfaces, typecheck/lint/test, re-detect-to-zero."
    echo "      (actionable-next-steps, reuse-before-create, ledger-row, honesty-clause are now"
    echo "      SCRIPT-enforced above.)"
  fi
  exit 0
}

main "$@"
