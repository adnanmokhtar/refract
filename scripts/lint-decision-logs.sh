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
#     5. The extraction-coverage contract: the field names + marker shape that
#        `_extracted-codebase.md` publishes and that Phase 4 / 4.6 / 5.5 parse. Same failure
#        class as (2) — a contributor renames `census_method` in the emitter, every consumer
#        keeps looking for the old key, and coverage silently reads as absent (which is NOT
#        the same as 100%). Presence-of-vocabulary over the SPEC, not a runtime assertion:
#        there is no project codebase here to measure, and a gate that pretended otherwise
#        would be unrunnable.
#
# Usage:  scripts/lint-decision-logs.sh [--repo-root=<dir>]
# Exit:   0 = clean, 1 = drift detected

set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) ROOT="${1#*=}" ;;
    --quiet)       : ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
ADAPTERS_DIR="$ROOT/templates/tool-adapters"
ERRORS=0
fail()  { printf '\033[31m✗ %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass()  { printf '\033[32m✓ %s\033[0m\n' "$*"; }
group() { printf '\033[1m\n%s\033[0m\n' "$*"; }

# The M2 split moved the decision-log / phase-helper tokens out of setup-project.md into the
# LIVE phase + rule + skill sources below. A token now lives in WHICHEVER owner inherited it,
# so each check is satisfied if the token is found in ANY candidate (not a single hardcoded
# file). Point at live sources — NOT abridged _examples/ copies. bash 3.2: plain space-joined
# list, no arrays-of-paths gymnastics needed.
DECISION_LOG_OWNERS="
$ROOT/templates/rule-7-phase-4-6-file-adaptation.md
$ROOT/templates/phases/phase-4.6-deep.md
$ROOT/templates/phases/phase-4.8-deep.md
$ROOT/templates/phases/phase-5-verify.md
$ROOT/templates/packs/learning/skills/apply-pack-adaptation/SKILL.md
"

# grep_owners <fixed-string> — succeed (0) if the literal is present in ANY owner file.
grep_owners() {
  local needle="$1" f
  for f in $DECISION_LOG_OWNERS; do
    [ -f "$f" ] || continue
    if grep -qF "$needle" "$f"; then return 0; fi
  done
  return 1
}

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
  "SAMPLED"
)
for tok in "${PHASE_4_6_TOKENS[@]}"; do
  if grep_owners "$tok"; then
    pass "Phase 4.6 token: $tok"
  else
    fail "Phase 4.6 token MISSING from decision-log owners: $tok"
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
  if grep_owners "$tok"; then
    pass "DEEP token: $tok"
  else
    fail "DEEP token MISSING from decision-log owners: $tok"
  fi
done

# 3. Phase 4.8-DEEP decision-log column shape.
group "3. Phase 4.8-DEEP decision-log column shape"
# The canonical row is: | Adapter | Output file | Action | Triggered by | Notes |
PATTERN_4_8="| Adapter | Output file | Action | Triggered by | Notes |"
if grep_owners "$PATTERN_4_8"; then
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
  if grep_owners "$h"; then
    pass "audit helper documented: \`$h\`"
  else
    fail "audit helper MISSING from decision-log owners: \`$h\`"
  fi
done

# 5. Phase 5.1 halt token MISSING_PHASE_4_6_DECISIONS_FILE — the canonical "decision log
#    is missing" failure mode. Without this, audit silently passes garbage.
group "5. Phase 5.1 halt tokens"
HALT_TOKENS=(
  "MISSING_PHASE_4_6_DECISIONS_FILE"
)
for tok in "${HALT_TOKENS[@]}"; do
  if grep_owners "$tok"; then
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
# The cursor names below are Cursor's REAL API surface (cursor.com/docs/agent/hooks).
# They were previously asserted as `beforeToolCall`/`afterToolCall`, which no Cursor
# release has ever emitted; the adapter doc was corrected to `preToolUse`/`postToolUse`
# and this list was not, so the linter was pinning invented vocabulary.
declare_hooks_for() {
  case "$1" in
    cursor)      echo "preToolUse postToolUse sessionStart sessionEnd" ;;
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

# 7. Cursor hooks.json schema pin. Cursor publishes NO `$schema` URL for hooks.json.
#    This check used to demand the string `hooks.v1.json`, i.e. the invented
#    `cursor.com/schemas/hooks.v1.json` reference that the adapter doc removed on purpose
#    ("drop the fabricated URL"). Asserting it forced the repo to re-add fabricated
#    evidence to go green, so the assertion — not the doc — was wrong. The only real
#    discriminator the format carries is its top-level `version: 1`; that is what Phase
#    4.8 output is validated against, so that is what gets pinned. The second arm is a
#    regression guard so the fabricated URL cannot quietly return.
group "7. Cursor hooks.json schema pin"
CURSOR_DOC="$ADAPTERS_DIR/cursor/adapter.md"
if grep -qE '"version"[[:space:]]*:[[:space:]]*1|schema `version: 1`' "$CURSOR_DOC"; then
  pass "cursor: hooks.json schema version discriminator documented (\`version: 1\`)"
else
  fail "cursor: hooks.json schema version NOT pinned (need \`version: 1\` — the only schema discriminator Cursor's hooks.json has)"
fi
# Match only a LIVE re-introduction: a real `"$schema"` JSON key, or a fetchable
# cursor.com/schemas URL. The caveat prose that documents the removal names the string
# in backticks with an ellipsis and no scheme, so it does not (and must not) trip this.
if grep -qE '"\$schema"|https?://cursor\.com/schemas/' "$CURSOR_DOC"; then
  fail "cursor: fabricated schema URL re-introduced — Cursor's hooks.json has no \$schema key"
else
  pass "cursor: no fabricated \$schema key / cursor.com/schemas URL"
fi

# 8. apply-pack-adaptation skill mentions decision-log file by name.
group "8. apply-pack-adaptation skill — decision-log integration"
APPLY_SKILL="$ROOT/templates/packs/learning/skills/apply-pack-adaptation/SKILL.md"
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

# 9. Extraction-coverage contract. `[EXTRACTION-WEAK]` says "no signal"; `[SAMPLED]` says
#    "partial signal". The second is only useful if emitter and consumers agree on the exact
#    field names and marker shape — a drifted key reads downstream as "no coverage reported",
#    which is indistinguishable from "coverage is complete" unless the vocabulary is pinned.
group "9. Extraction-coverage contract (emitter fields + consumer downgrade rule)"
EXTRACT_SKILL="$ROOT/templates/packs/learning/skills/extract-codebase-overview/SKILL.md"
if [ -f "$EXTRACT_SKILL" ]; then
  # Emitter side — the literal names every consumer parses out of _extracted-codebase.md.
  COVERAGE_FIELDS=(
    "## Coverage"
    "census_method"
    "walk_scope"
    "files_cited"
    "[SAMPLED: <seen>/<present> <unit>]"
  )
  for fld in "${COVERAGE_FIELDS[@]}"; do
    if grep -qF "$fld" "$EXTRACT_SKILL"; then
      pass "coverage contract documented by emitter: \`$fld\`"
    else
      fail "coverage contract field MISSING from extract-codebase-overview: \`$fld\`"
    fi
  done
else
  fail "extract-codebase-overview skill not found at $EXTRACT_SKILL"
fi
# Consumer side — a marker nothing consumes is decoration. Pin the downgrade rule itself,
# not just the token: the behaviour IS that generalizing claims from a sampled section stop
# being [found:] and therefore stop being anchorable.
DOWNGRADE_RULE="sampled <seen>/<present> <unit>"
if grep_owners "$DOWNGRADE_RULE"; then
  pass "coverage downgrade rule documented by a decision-log owner: \`[inferred: <basis>; $DOWNGRADE_RULE]\`"
else
  fail "coverage downgrade rule MISSING — no decision-log owner documents \`$DOWNGRADE_RULE\`; [SAMPLED] would change no behaviour"
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
