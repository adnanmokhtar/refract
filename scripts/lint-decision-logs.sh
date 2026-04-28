#!/usr/bin/env bash
# Decision-log + hooks.json structural validator.
#
# WHY THIS EXISTS:
#   Phase 4.8-DEEP's correctness depends on `.claude/_phase-4-6-decisions.md` and
#   `_phase-4-7-decisions.md` being parseable so the affected-artifact list can be computed.
#   Phase 4.8-DEEP itself writes `_phase-4-8-decisions.md` with a specific table shape.
#
#   The original spec describes these formats in prose. If a contributor edits the spec and
#   accidentally drifts a column name or an action token, the entire 4.8-DEEP cost-bound
#   collapses (the LLM tries to parse a malformed file and either halts or falls back to
#   "rewrite everything" — both bad).
#
#   This script asserts the spec documents:
#     1. Every action token used by 4.6 / 4.7 / 4.8-DEEP decision logs.
#     2. The exact column shapes for the 4-8 decision table.
#     3. The helper-function names (lookup_phase_4_6_decision, etc.) — these are the
#        contract that Phase 5.3 audit depends on.
#     4. The cursor + claude-code adapters' hooks.json structural schema (event names).
#
# Usage:  scripts/lint-decision-logs.sh
# Exit:   0 = clean, 1 = drift detected

set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETUP_CMD="$ROOT/commands/setup-project.md"
ADAPTERS_DIR="$ROOT/templates/tool-adapters"
ERRORS=0
fail()  { printf '\033[31m✗ %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass()  { printf '\033[32m✓ %s\033[0m\n' "$*"; }
group() { printf '\033[1m\n%s\033[0m\n' "$*"; }

echo "════════════════════════════════════════════════════════════════"
echo "  Decision-log + hooks.json structural validator"
echo "════════════════════════════════════════════════════════════════"

# 1. Phase 4.6 decision log — action tokens documented.
group "1. Phase 4.6 decision-log action tokens"
PHASE_4_6_TOKENS=(
  "CHANGE-anchor"
  "CHANGE-anchor-with-warn"
  "LEAVE-with-redirect"
  "LEAVE-delete"
  "EXTRACTION-WEAK"
)
for tok in "${PHASE_4_6_TOKENS[@]}"; do
  if grep -qF "$tok" "$SETUP_CMD"; then
    pass "Phase 4.6 token: $tok"
  else
    fail "Phase 4.6 token MISSING from setup-project.md: $tok"
  fi
done

# 2. Phase 4.6-DEEP / 4.7-DEEP / 4.8-DEEP action tokens.
group "2. Phase 4.6-DEEP / 4.7-DEEP / 4.8-DEEP tokens"
DEEP_TOKENS=(
  "ANCHOR-DEEP"
  "NEW-FILE"
  "LEAVE-DEEP"
  "LEAVE-DEEP-IDEMPOTENT"
  "ROLLBACK-MARKER-DRIFT"
  "MARKERS-INJECTED"
  "RE-TRANSLATED"
  "INDEX-REFRESHED"
  "NO-OP"
  "SKIPPED-NO-CHANGES"
)
for tok in "${DEEP_TOKENS[@]}"; do
  if grep -qF "$tok" "$SETUP_CMD"; then
    pass "DEEP token: $tok"
  else
    fail "DEEP token MISSING from setup-project.md: $tok"
  fi
done

# 3. Phase 4.8-DEEP decision-log column shape.
group "3. Phase 4.8-DEEP decision-log column shape"
# The canonical row is: | Adapter | Output file | Action | Triggered by | Notes |
PATTERN_4_8="| Adapter | Output file | Action | Triggered by | Notes |"
if grep -qF "$PATTERN_4_8" "$SETUP_CMD"; then
  pass "Phase 4.8-DEEP table header documented: \`$PATTERN_4_8\`"
else
  fail "Phase 4.8-DEEP table header MISSING — expected exact row: $PATTERN_4_8"
fi

# 4. Phase 5.3 helper function names (audit contract).
group "4. Phase 5.3 helper-function names"
HELPERS=(
  "lookup_phase_4_6_decision"
  "DECISIONS_FILE"
  "EXTRACTION_FILE"
  "IDIOMS_FILE"
)
for h in "${HELPERS[@]}"; do
  if grep -qF "$h" "$SETUP_CMD"; then
    pass "audit helper documented: \`$h\`"
  else
    fail "audit helper MISSING from setup-project.md: \`$h\`"
  fi
done

# 5. Phase 5.1 halt token MISSING_PHASE_4_6_DECISIONS_FILE — the canonical "decision log
#    is missing" failure mode. Without this, audit silently passes garbage.
group "5. Phase 5.1 halt tokens"
HALT_TOKENS=(
  "MISSING_PHASE_4_6_DECISIONS_FILE"
)
for tok in "${HALT_TOKENS[@]}"; do
  if grep -qF "$tok" "$SETUP_CMD"; then
    pass "Phase 5.1 halt token: $tok"
  else
    fail "Phase 5.1 halt token MISSING: $tok"
  fi
done

# 6. hooks.json structural schema — for cursor + claude-code adapters that emit it,
#    the canonical events are documented in the adapter doc.
group "6. hooks.json events documented in cursor + claude-code adapters"
# Cursor uses camelCase events; claude-code uses PascalCase. We accept either set as
# valid documentation (each adapter is checked against ITS canonical naming).
declare_hooks_for() {
  case "$1" in
    cursor)      echo "beforeToolCall afterToolCall sessionStart sessionEnd" ;;
    claude-code) echo "PreToolUse PostToolUse SessionStart Stop" ;;
  esac
}
for adapter in cursor claude-code; do
  doc="$ADAPTERS_DIR/$adapter/adapter.md"
  [ -f "$doc" ] || { fail "$adapter: missing adapter.md"; continue; }
  events=$(declare_hooks_for "$adapter")
  found=0
  total=0
  for ev in $events; do
    total=$((total+1))
    if grep -qF "$ev" "$doc"; then
      found=$((found+1))
    fi
  done
  if [ "$found" -ge 3 ]; then
    pass "$adapter: hooks.json schema documents $found/$total canonical event(s) ($events)"
  else
    fail "$adapter: hooks.json schema underdocumented — only $found/$total canonical event(s) found ($events)"
  fi
done

# 7. The cursor adapter must mention either the JSON schema URL or its filename — Phase 4.8
#    outputs hooks.json validated against this.
group "7. Cursor hooks.json schema reference"
if grep -qE "(hooks\.v[0-9]+\.json|hooks\.json schema|hooks-schema)" "$ADAPTERS_DIR/cursor/adapter.md"; then
  pass "cursor: hooks.json schema reference documented"
else
  fail "cursor: hooks.json schema reference NOT documented (need 'hooks.v1.json' or 'hooks.json schema')"
fi

# 8. apply-pack-adaptation skill mentions decision-log file by name.
group "8. apply-pack-adaptation skill — decision-log integration"
APPLY_SKILL="$ROOT/templates/packs/learning/skills/apply-pack-adaptation.md"
if [ -f "$APPLY_SKILL" ]; then
  for ref in "_phase-4-6-decisions.md" "_phase-4-8-decisions.md"; do
    if grep -qF "$ref" "$APPLY_SKILL"; then
      pass "apply-pack-adaptation references: $ref"
    else
      fail "apply-pack-adaptation MISSING reference to: $ref"
    fi
  done
else
  fail "apply-pack-adaptation skill not found at $APPLY_SKILL"
fi

echo
echo "════════════════════════════════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[32m  Decision-log + hooks.json validator: PASS\033[0m\n'
  exit 0
else
  printf '\033[31m  Decision-log + hooks.json validator: FAIL (%d issue(s))\033[0m\n' "$ERRORS"
  exit 1
fi
