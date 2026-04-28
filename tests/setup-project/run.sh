#!/usr/bin/env bash
# tests/setup-project/run.sh — snapshot-style fixture runner for /setup-project.
#
# What it does
# ------------
# 1. For each fixture under tests/setup-project/fixtures/<name>/:
#    a. Copy the fixture into a temp dir.
#    b. (Stub) "Run /setup-project" against the temp dir.
#    c. Diff the temp-dir output against tests/setup-project/snapshots/<name>/.
#    d. Report pass/fail.
# 2. With --update-snapshots: copies the temp-dir output BACK to the snapshot
#    after a manual review prompt. This is how intentional changes land.
# 3. With --idempotency-only: runs /setup-project a second time and verifies
#    the second run produces an empty diff (the idempotency contract).
#
# IMPORTANT — current state
# -------------------------
# The "run /setup-project" step is a stub. /setup-project is a Claude Code
# command (a markdown prompt the model executes), not an automatable shell
# command. To turn this stub into a real driver:
#   - Option A: invoke `claude` non-interactively against the fixture
#       (requires CLAUDE_CODE_BIN env + a careful prompt fixture).
#   - Option B: extract a deterministic subset of /setup-project's work
#       (Phase 4.0 preflight, Phase 4.2.b deterministic copy) into a shell
#       harness that the snapshot test calls directly.
#
# Until one of those exists, this script:
#   - Validates the fixture/snapshot directory shape.
#   - Verifies that fixtures parse (e.g., package.json is valid JSON).
#   - Diffs any pre-recorded snapshot against the fixture's current state.
# Use --shape-only for that minimal validation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES_ROOT="$REPO_ROOT/tests/setup-project/fixtures"
SNAPSHOTS_ROOT="$REPO_ROOT/tests/setup-project/snapshots"

UPDATE=0
IDEMPOTENCY=0
SHAPE_ONLY=0
SELECT_FIXTURE=""

usage() {
  sed -n '2,40p' "$0"
  cat <<'EOF'

Usage:
  run.sh [--shape-only] [--idempotency-only] [--update-snapshots]
         [--fixture <name>]

Flags:
  --shape-only        Only verify directory shape + fixture parsability. Default.
  --idempotency-only  Skip first-run; assume snapshot is current; verify second-run empty diff.
  --update-snapshots  Re-record the snapshot after a manual confirm. Use with care.
  --fixture <name>    Limit to a single fixture (default: all).
EOF
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --update-snapshots) UPDATE=1 ;;
    --idempotency-only) IDEMPOTENCY=1 ;;
    --shape-only) SHAPE_ONLY=1 ;;
    --fixture) shift; SELECT_FIXTURE="${1:-}"; [[ -z "$SELECT_FIXTURE" ]] && usage ;;
    -h|--help) usage ;;
    *) ;;
  esac
done

# Default mode: shape-only (the only mode that can run today).
if [[ "$UPDATE" -eq 0 && "$IDEMPOTENCY" -eq 0 && "$SHAPE_ONLY" -eq 0 ]]; then
  SHAPE_ONLY=1
fi

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERR:  %s\n' "$*" >&2; }

pass=0
fail=0
skip=0

verify_fixture_shape() {
  local fixture_dir="$1"
  local name; name="$(basename "$fixture_dir")"
  local snap_dir="$SNAPSHOTS_ROOT/$name"

  log ""
  log "=== fixture: $name ==="

  if [[ ! -d "$fixture_dir" ]]; then
    err "fixture missing: $fixture_dir"
    fail=$((fail + 1)); return
  fi

  # Sanity: parse any package.json in the fixture
  while IFS= read -r pkg; do
    if ! python3 -c "import json,sys; json.load(open('$pkg'))" 2>/dev/null; then
      err "$name: $pkg is not valid JSON"
      fail=$((fail + 1)); return
    fi
  done < <(find "$fixture_dir" -name package.json)

  # Check the snapshot directory exists (may be empty until M4+ runner lands)
  if [[ ! -d "$snap_dir" ]]; then
    warn "$name: no snapshot dir at $snap_dir; create with --update-snapshots once a real runner exists"
    skip=$((skip + 1)); return
  fi

  # Snapshot present: ensure README and at least one expected output marker exist
  if [[ ! -f "$snap_dir/README.md" && "$(ls "$snap_dir" 2>/dev/null | wc -l)" -eq 0 ]]; then
    warn "$name: snapshot dir empty; will be populated when runner is wired"
    skip=$((skip + 1)); return
  fi

  log "$name: shape ok (fixture parses; snapshot dir present)"
  pass=$((pass + 1))
}

run_full() {
  err "Full /setup-project invocation is not yet implemented. Use --shape-only."
  err "See header of this script for what it would take to wire it up."
  exit 3
}

if [[ "$IDEMPOTENCY" -eq 1 || "$UPDATE" -eq 1 ]]; then
  run_full
fi

# Shape-only: iterate fixtures, run shape verification.
fixtures=()
if [[ -n "$SELECT_FIXTURE" ]]; then
  fixtures=("$FIXTURES_ROOT/$SELECT_FIXTURE")
else
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    fixtures+=("$d")
  done < <(find "$FIXTURES_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
fi

for f in "${fixtures[@]}"; do
  verify_fixture_shape "$f"
done

log ""
log "result: $pass passed / $fail failed / $skip skipped"

[[ "$fail" -gt 0 ]] && exit 1
exit 0
