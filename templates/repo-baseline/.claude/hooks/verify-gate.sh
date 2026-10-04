#!/usr/bin/env bash
# Stop hook — the deterministic "done" gate.
# Closes the "looks done" gap: when this session left uncommitted source changes, run the
# project's gates and block the stop (exit 2) on a gate in `block` mode that FAILs, so the agent
# fixes the cause instead of declaring success.
#
# The gates live in .claude/scripts/gate-check.py (--local): G1 tests, G2 test integrity,
# G3 secrets, G7 lint / typecheck / standards, G15 provenance trailer — each mode (shadow |
# warn | block) set in .claude/gates.json, each result written to .claude/evidence/<sha>/.
# This file only decides WHETHER to run them and how the result reaches Claude Code:
#   exit 2  a block-mode gate FAILed — stderr carries the report, Claude reads it and continues
#   exit 0  allowed; a non-PASS verdict (UNVERIFIED, a warn-mode FAIL) still reaches the user as
#           a `systemMessage` — a project with no test runner is reported UNVERIFIED, never
#           passed in silence, which is what this hook did before gate-check.py existed.
# Claude Code overrides a Stop block after 8 consecutive blocks, so this can't trap a session —
# and for the same reason it is advisory-strong, not a hard gate: CI (refract-gates) is that.
#
# Opt out per project: create .claude/.no-verify-gate

set -uo pipefail

[ -f ".claude/.no-verify-gate" ] && exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Only gate when this session actually touched source, or the files that decide whether tests run
# (CI config, coverage floors) — never run the suite for doc/no-op turns. `-uall` lists untracked
# files one by one: without it a new file in a new directory shows as `?? src/`, which matches no
# extension, so a change made only of new files skipped the gate entirely.
changed=$(git status --porcelain -uall 2>/dev/null \
  | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|kts|scala|swift|php|cs|fs|vue|svelte|dart|ex|exs|c|cc|cpp|h|hpp|m|mm)$|\.github/workflows/|\.gitlab-ci\.yml$|(jest|vitest)\.config\.|codecov\.ya?ml$|\.coveragerc$' || true)
[ -z "$changed" ] && exit 0

GATE=".claude/scripts/gate-check.py"
if [ -f "$GATE" ] && command -v python3 >/dev/null 2>&1; then
  python3 "$GATE" --local --hook-json
  status=$?
  if [ "$status" -eq 2 ]; then
    echo "Fix the cause (root cause — don't suppress a check, skip a test or lower a threshold) and try again." >&2
    echo "Modes: .claude/gates.json · evidence: .claude/evidence/ · to bypass this hook: create .claude/.no-verify-gate." >&2
  fi
  exit "$status"
fi

# ── Fallback: gate-check.py not installed here (an older setup) or no python3 ──────────────────
# Tests only, through the heavy-test lane when it ships here (test-lane.sh): one full suite per
# machine at a time. The agent's own green run of this command on exactly this tree IS the
# verification. The wait is bounded because Claude Code cancels a hook at its 600s timeout.
TEST_CMD=""
if [ -f "package.json" ] && grep -q '"test"' package.json; then
  if command -v bun >/dev/null 2>&1 && [ -f "bun.lockb" ]; then TEST_CMD="bun run test"
  elif command -v pnpm >/dev/null 2>&1 && [ -f "pnpm-lock.yaml" ]; then TEST_CMD="pnpm test"
  elif command -v npm >/dev/null 2>&1; then TEST_CMD="npm test --silent"; fi
elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.cfg" ]; then
  command -v pytest >/dev/null 2>&1 && TEST_CMD="pytest -q"
elif [ -f "go.mod" ]; then
  command -v go >/dev/null 2>&1 && TEST_CMD="go test ./..."
elif [ -f "Cargo.toml" ]; then
  command -v cargo >/dev/null 2>&1 && TEST_CMD="cargo test --quiet"
fi
if [ -z "$TEST_CMD" ]; then
  printf '{"systemMessage":"Verification gate: tests UNVERIFIED - no test runner detected and .claude/scripts/gate-check.py is not installed (re-run apply-baseline-sync.sh to get it)."}\n'
  exit 0
fi

LANE=".claude/hooks/test-lane.sh"
if [ -f "$LANE" ] && [ ! -f ".claude/.no-test-lane" ]; then
  bash "$LANE" verified "$TEST_CMD" && exit 0
  out=$(CLAUDE_TEST_LANE_WAIT="${CLAUDE_VERIFY_GATE_WAIT:-240}" bash "$LANE" run "$TEST_CMD" 2>&1)
  status=$?
  if [ "$status" -eq 75 ]; then
    echo "Verification gate: tests NOT verified — the heavy-test lane stayed busy." >&2
    echo "$out" | grep '^test-lane:' | tail -1 >&2
    echo "Run the suite through the lane in the background (it waits its turn), then stop once it is green; the gate accepts that run instead of repeating it:" >&2
    echo "  \"$PWD/$LANE\" run '$TEST_CMD'" >&2
    exit 2
  fi
else
  out=$(eval "$TEST_CMD" 2>&1)
  status=$?
fi

if [ "$status" -ne 0 ]; then
  echo "Verification gate: tests are FAILING — do not stop with red tests." >&2
  echo "Command: $TEST_CMD" >&2
  echo "$out" | tail -30 >&2
  echo "Fix the failures (root cause, don't suppress) and try again. To bypass: create .claude/.no-verify-gate." >&2
  exit 2
fi

exit 0
