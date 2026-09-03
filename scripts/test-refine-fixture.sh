#!/usr/bin/env bash
# Regression test for /setup-project --refine.
#
# /setup-project --refine is an LLM-driven workflow — we can't end-to-end-test
# it from a shell script. But the safety guarantees + structural contracts can
# be tested mechanically:
#
#   1. Marker-safety simulation — re-implement the byte-level write contract
#      and exercise it on a synthetic project.
#   2. Static structure — every REFINE artifact referenced in the spec exists;
#      marker token strings are byte-identical across spec / skill / pattern;
#      plateau classifier vocabulary is consistent.
#
# Exit 0 = clean, 1 = drift / contract violation.
#
# Usage: scripts/test-refine-fixture.sh

set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
fail() { printf '\033[31m\u2717 %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass() { printf '\033[32m\u2713 %s\033[0m\n' "$*"; }
info() { printf '\033[36m\u2022 %s\033[0m\n' "$*"; }

echo "================================================================"
echo "  /setup-project --refine — regression fixture"
echo "================================================================"

# ───────────────── 1. Marker-safety simulation ─────────────────
info ""
info "1. Marker-safety simulation (Python)"
if python3 "$ROOT/tests/refine-fixture/marker_safety.py"; then
  pass "marker_safety.py: PASS"
else
  fail "marker_safety.py: FAIL — see output above"
fi

# ───────────────── 2. REFINE skill + pattern presence ─────────────────
info ""
info "2. REFINE artifact presence"

REQUIRED_FILES=(
  "templates/packs/learning/skills/extract-domain-entities-deeply/SKILL.md"
  "templates/packs/learning/skills/extract-architecture-deeply/SKILL.md"
  "templates/packs/learning/skills/extract-flows-deeply/SKILL.md"
  "templates/packs/learning/skills/extract-conventions-emerging/SKILL.md"
  "templates/packs/learning/skills/extract-hotpaths/SKILL.md"
  "templates/packs/learning/skills/extract-failures-from-history/SKILL.md"
  "templates/packs/learning/skills/compute-anchor-density/SKILL.md"
  "templates/packs/learning/skills/apply-pack-adaptation/SKILL.md"
  "templates/packs/learning/ai-patterns/setup-quality-scoring.md"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [ -f "$ROOT/$f" ]; then
    pass "$f"
  else
    fail "missing: $f"
  fi
done

# ───────────────── 3. Marker token byte-stability ─────────────────
info ""
info "3. Marker tokens are byte-identical across spec / skill / pattern / fixture"

# Every place that mentions the start/end markers must use the EXACT strings.
# Variants like '<!--project-specific:start-->' (no spaces) or ':START:' would
# silently break REFINE.

for token in \
  "<!-- project-specific:start -->" \
  "<!-- project-specific:end -->" \
  "<!-- refine-enriched:start -->" \
  "<!-- refine-enriched:end -->" \
  "<!-- generated:start -->" \
  "<!-- generated:end -->"; do

  count=$(grep -rFc "$token" \
    "$ROOT/commands/setup-project.md" \
    "$ROOT/templates/packs/learning/skills/apply-pack-adaptation/SKILL.md" \
    "$ROOT/templates/packs/learning/skills/compute-anchor-density/SKILL.md" \
    "$ROOT/templates/packs/learning/ai-patterns/setup-quality-scoring.md" \
    "$ROOT/README.md" \
    2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')

  if [ "$count" -lt 1 ]; then
    fail "token never referenced: $token"
  else
    pass "token referenced ($count occurrences): $token"
  fi
done

# ───────────────── 4. REFINE phase presence in spec ─────────────────
info ""
info "4. Every REFINE phase + flag is in setup-project.md"

SPEC="$ROOT/commands/setup-project.md"
for phase in \
  "Phase 2.7" "Phase 2.8" "Phase 2.9" "Phase 2.10" "Phase 2.11" "Phase 2.12" \
  "Phase 4.6-DEEP" "Phase 4.7-DEEP" "Phase 4.8-DEEP" "Phase 5.5"; do
  if grep -qF "### $phase" "$SPEC"; then
    pass "spec contains: $phase"
  else
    fail "spec missing: $phase"
  fi
done

# Every REFINE phase that names a backing skill must reference a real file.
# (Pattern: "invoke `<skill-name>`" or "invoke the `<skill-name>` skill")
declare -a SKILL_REFS=(
  "extract-domain-entities-deeply"
  "extract-architecture-deeply"
  "extract-flows-deeply"
  "extract-conventions-emerging"
  "extract-hotpaths"
  "extract-failures-from-history"
  "compute-anchor-density"
  "apply-pack-adaptation"
)
for skill in "${SKILL_REFS[@]}"; do
  if ! grep -qF "$skill" "$SPEC"; then
    fail "spec doesn't reference skill: $skill"
  fi
done

# ───────────────── 5. Plateau classifier vocabulary consistency ─────────────────
info ""
info "5. Plateau classifier vocabulary (PLATEAU-DEEP / PLATEAU-WEAK / NOT-PLATEAU)"

_cls_errors_before=$ERRORS
for v in PLATEAU-DEEP PLATEAU-WEAK NOT-PLATEAU; do
  for f in \
    "$SPEC" \
    "$ROOT/templates/packs/learning/skills/compute-anchor-density/SKILL.md" \
    "$ROOT/templates/packs/learning/ai-patterns/setup-quality-scoring.md" \
    "$ROOT/README.md"; do
    if ! grep -qF "$v" "$f"; then
      rel="$(echo "$f" | sed "s|$ROOT/||")"
      fail "$rel: missing classifier '$v'"
    fi
  done
done
# Was unconditional, directly after a loop that calls `fail` up to twelve times — so the suite
# could report both the failures and a pass for the same assertion. Only claim it when nothing
# in the loop failed.
if [ "$ERRORS" -eq "$_cls_errors_before" ]; then
  pass "all three classifiers present in spec / skill / pattern / README"
fi

# Bare "Plateau reached" without DEEP/WEAK qualifier should not appear in the
# user-facing report formats — that's the misleading-message bug.
# Allow it inside descriptive sentences (e.g. "when the run is plateau reached"),
# but disallow it appearing alone as a heading.
LEAKY=$(grep -nE '^## Plateau reached *$' \
  "$SPEC" \
  "$ROOT/templates/packs/learning/ai-patterns/setup-quality-scoring.md" \
  "$ROOT/templates/packs/learning/skills/compute-anchor-density/SKILL.md" \
  2>/dev/null || true)
if [ -n "$LEAKY" ]; then
  fail "bare '## Plateau reached' heading found (should be PLATEAU-DEEP / PLATEAU-WEAK):"
  echo "$LEAKY"
else
  pass "no bare '## Plateau reached' headings (always classified)"
fi

# ───────────────── 6. --max-subagents flag wired everywhere ─────────────────
info ""
info "6. --max-subagents documented in spec + cheatsheet + README"

for f in \
  "commands/setup-project.md" \
  "docs/setup-project-cheatsheet.md" \
  "README.md"; do
  if grep -qF -- "--max-subagents" "$ROOT/$f"; then
    pass "$f references --max-subagents"
  else
    fail "$f missing --max-subagents"
  fi
done

# ───────────────── 7. ACT options for REFINE present in skill ─────────────────
info ""
info "7. apply-pack-adaptation skill documents all REFINE + ADAPTER-SYNC ACTs"

SKILL="$ROOT/templates/packs/learning/skills/apply-pack-adaptation/SKILL.md"
for act in ANCHOR-DEEP LEAVE-DEEP LEAVE-DEEP-IDEMPOTENT NEW-FILE ROLLBACK-MARKER-DRIFT \
           RE-TRANSLATED INDEX-REFRESHED SKIPPED-NO-CHANGES NO-OP-ADAPTER NEEDS-FULL-PHASE-4.8 \
           MARKERS-INJECTED-ADAPTER ADAPTER-SYNC; do
  if grep -qF "$act" "$SKILL"; then
    pass "skill documents ACT: $act"
  else
    fail "skill missing ACT: $act"
  fi
done

# ───────────────── 8. Phase 4.8-DEEP coverage in spec + docs ─────────────────
info ""
info "8. Phase 4.8-DEEP referenced consistently in spec + README + cheatsheet"

# 4.8-DEEP phase header in setup-project.md (already covered in step 4 — this
# is a deeper check: the cross-references must also exist).
for f in \
  "commands/setup-project.md" \
  "README.md" \
  "docs/setup-project-cheatsheet.md" \
  "templates/packs/learning/skills/apply-pack-adaptation/SKILL.md"; do
  if grep -qF "Phase 4.8-DEEP" "$ROOT/$f"; then
    pass "$f references Phase 4.8-DEEP"
  else
    fail "$f missing Phase 4.8-DEEP reference"
  fi
done

# Decision-mode table in spec must mention the 4.8-DEEP step in the REFINE flow.
if grep -qE "Phase 4\.8-DEEP" "$SPEC"; then
  if grep -qE "4\.6-DEEP.*4\.7-DEEP.*4\.8-DEEP" "$SPEC"; then
    pass "decision-mode flow includes 4.6-DEEP → 4.7-DEEP → 4.8-DEEP ordering"
  else
    fail "spec mentions 4.8-DEEP but the decision-mode flow doesn't show 4.6→4.7→4.8 ordering"
  fi
fi

# Decision log file referenced.
for f in \
  "commands/setup-project.md" \
  "templates/packs/learning/skills/apply-pack-adaptation/SKILL.md" \
  "README.md"; do
  if grep -qF "_phase-4-8-decisions.md" "$ROOT/$f"; then
    pass "$f references _phase-4-8-decisions.md log"
  else
    fail "$f missing _phase-4-8-decisions.md reference"
  fi
done

# Three marker tokens must each map to at least one phase that owns it
# (project-specific → 4.6-DEEP, refine-enriched → 4.7-DEEP, generated → 4.8-DEEP).
SKILL_TEXT="$(cat "$ROOT/templates/packs/learning/skills/apply-pack-adaptation/SKILL.md")"
if echo "$SKILL_TEXT" | grep -qF "Cross-mode marker semantics"; then
  pass "skill documents three-marker partition (project-specific / refine-enriched / generated)"
else
  fail "skill missing 'Cross-mode marker semantics' section"
fi

# ───────────────── final ─────────────────
echo
echo "================================================================"
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[32m  Refine-fixture regression: PASS\033[0m\n'
  exit 0
else
  printf '\033[31m  Refine-fixture regression: FAIL (%d issue(s))\033[0m\n' "$ERRORS"
  exit 1
fi
