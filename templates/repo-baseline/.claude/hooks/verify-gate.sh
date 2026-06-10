#!/usr/bin/env bash
# Stop hook — deterministic verification gate.
# Closes the "looks done" gap: if this session left uncommitted source changes
# AND the project has a test command AND that command FAILS, block the stop (exit 2)
# so the agent fixes red tests instead of declaring success.
#
# Blocks ONLY on actual test failure. No changes, no test runner, or green tests → exit 0.
# Claude Code overrides a Stop block after 8 consecutive blocks, so this can't trap a session.
#
# Opt out per project: create .claude/.no-verify-gate

set -uo pipefail

[ -f ".claude/.no-verify-gate" ] && exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Only gate when this session actually touched source — never run the suite for doc/no-op turns.
changed=$(git status --porcelain 2>/dev/null \
  | grep -Ev '\.(md|txt|json|ya?ml|lock|cfg|ini|toml)$' \
  | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|php|cs|vue|svelte)$' || true)
[ -z "$changed" ] && exit 0

# Detect the project's test command (first match wins).
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
[ -z "$TEST_CMD" ] && exit 0

out=$(eval "$TEST_CMD" 2>&1)
status=$?

if [ "$status" -ne 0 ]; then
  echo "Verification gate: tests are FAILING — do not stop with red tests." >&2
  echo "Command: $TEST_CMD" >&2
  echo "$out" | tail -30 >&2
  echo "Fix the failures (root cause, don't suppress) and try again. To bypass: create .claude/.no-verify-gate." >&2
  exit 2
fi

exit 0
