#!/usr/bin/env bash
# Fixture suite for the security-critical baseline hooks.
#
# Each case file is the hook's stdin payload (JSON). The filename encodes the
# expected outcome: "*-block-*" / "*block*" ⇒ hook must exit 2 (deny);
# "*-allow-*" / "*allow*" ⇒ hook must exit 0 (permit). We pipe the payload into
# the matching hook and assert the exit code.
#
# Run: bash tests/hooks/run.sh   (exit 0 = all pass, 1 = a case failed)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS="$REPO_ROOT/templates/repo-baseline/.claude/hooks"
CASES="$REPO_ROOT/tests/hooks/cases"

# Deterministic env: fixed protected branches, dry-run notify, no CWD git deps.
export CLAUDE_PROTECTED_BRANCHES="main,master"
export CLAUDE_NOTIFY_DRYRUN=1

pass=0; fail=0

run_dir() {
  local hook_name="$1" hook="$HOOKS/$1.sh" dir="$CASES/$1"
  [ -d "$dir" ] || return 0
  local f base want got
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      *block*) want=2 ;;
      *allow*) want=0 ;;
      *) echo "SKIP  $hook_name/$base (no block/allow in name)"; continue ;;
    esac
    # Run the hook from a scratch dir so CWD-relative opt-out flags never apply.
    got=0
    ( cd "$(mktemp -d)" && cat "$f" | bash "$hook" >/dev/null 2>&1 ) || got=$?
    if [ "$got" = "$want" ]; then
      pass=$((pass+1))
    else
      fail=$((fail+1))
      echo "FAIL  $hook_name/$base — expected exit $want, got $got"
    fi
  done
}

run_dir guard-destructive
run_dir pre-edit-guard
run_dir secret-scan

# inject-path-rules is context-only (always exit 0); assert on stdout instead of
# exit code. It must run from a dir that actually holds .claude/rules/, so we run
# it inside the repo-baseline. "*nomatch*" ⇒ empty output; "*match*" ⇒ injects the
# scoped rule. (Check nomatch first — "nomatch" contains the substring "match".)
run_inject() {
  local hook="$HOOKS/inject-path-rules.sh" dir="$CASES/inject-path-rules"
  local base_dir="$REPO_ROOT/templates/repo-baseline"
  [ -d "$dir" ] || return 0
  local f base out
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    out=$( cd "$base_dir" && cat "$f" | bash "$hook" 2>/dev/null )
    case "$base" in
      *nomatch*)
        if [ -z "$out" ]; then pass=$((pass+1)); else
          fail=$((fail+1)); echo "FAIL  inject-path-rules/$base — expected no injection, got output"; fi ;;
      *match*)
        if printf '%s' "$out" | grep -q 'migration-safety'; then pass=$((pass+1)); else
          fail=$((fail+1)); echo "FAIL  inject-path-rules/$base — expected migration-safety injection, got none"; fi ;;
      *) echo "SKIP  inject-path-rules/$base (no match/nomatch in name)" ;;
    esac
  done
}
run_inject

echo "----"
echo "hooks fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
