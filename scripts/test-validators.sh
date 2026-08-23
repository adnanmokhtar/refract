#!/usr/bin/env bash
# test-validators.sh — the harness that pins gate behaviour with known-good / known-bad
# fixtures, so a future edit can't silently regress a validator to always-pass (the root
# cause of the latent-bug class this framework keeps hitting).
#
# Convention:
#   tests/validators/<script-name>/good/<case>/   → the script MUST exit 0 against it
#   tests/validators/<script-name>/bad/<case>/    → the script MUST exit non-zero against it
# Each <case> dir is a self-contained mini-repo-root; the script is invoked
# `scripts/<script-name> --repo-root=<case>`. Add a new script by dropping a folder here +,
# if it doesn't take --repo-root, an entry in invoke()'s case statement.
#
# Usage:  test-validators.sh [--quiet]
# Exit:   1 if any fixture's actual exit disagrees with its good/bad contract; 0 otherwise.

set -uo pipefail   # NOT -e: we capture non-zero exits deliberately
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
TESTS_DIR="$REPO_ROOT/tests/validators"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

invoke() {  # $1=script-name $2=case-dir → prints exit code
  local script="$1" case="$2"
  case "$script" in
    # migration-reachability.sh: positional `--lint <slug>`, reads cwd-relative
    # ai/migration/reachability/<slug>.md. Case-dir basename = the slug.
    migration-reachability.sh)
      ( cd "$case" && bash "$REPO_ROOT/scripts/migration-reachability.sh" --lint "$(basename "$case")" ) >/dev/null 2>&1; echo $? ;;
    # audit-anchoring.sh: positional <target> + --strict (no --repo-root). --strict
    # makes a skeleton/leak finding exit non-zero (the bad-case contract). Pins the
    # extract_anchor_block fence-skip: good/ proves a FENCED example anchor is ignored,
    # bad/ proves a real (unfenced) skeleton anchor is still caught.
    # --stdout is not incidental here: it keeps the harness from writing a report into
    # every fixture on every run (that is what tests/validators/audit-anchoring.sh/
    # .gitignore used to exist for), and it exercises the read-only mode against all of
    # them, so a regression that reinstates the in-target write shows up as a red gate
    # rather than as a quietly dirtied fixture tree.
    audit-anchoring.sh)
      bash "$REPO_ROOT/scripts/audit-anchoring.sh" "$case" --strict --quiet --stdout >/dev/null 2>&1; echo $? ;;
    # All other fixtured scripts honour --repo-root. New non-repo-root scripts get an arm here.
    *) bash "$REPO_ROOT/scripts/$script" --repo-root="$case" >/dev/null 2>&1; echo $? ;;
  esac
}

pass=0; fail=0
[ -d "$TESTS_DIR" ] || { echo "no tests/validators/ dir — nothing to test"; exit 0; }

for sdir in "$TESTS_DIR"/*/; do
  [ -d "$sdir" ] || continue
  script="$(basename "$sdir")"
  [ -f "$REPO_ROOT/scripts/$script" ] || { echo "  WARN  fixture dir '$script' has no scripts/$script — skipping"; continue; }

  for good in "$sdir"good/*/; do
    [ -d "$good" ] || continue
    rc=$(invoke "$script" "$good")
    if [ "$rc" -eq 0 ]; then
      [ $QUIET -eq 0 ] && echo "  ok    $script  good/$(basename "$good")"
      pass=$((pass + 1))
    else
      echo "  FAIL  $script  good/$(basename "$good")  — expected exit 0, got $rc"
      fail=$((fail + 1))
    fi
  done

  for bad in "$sdir"bad/*/; do
    [ -d "$bad" ] || continue
    rc=$(invoke "$script" "$bad")
    if [ "$rc" -ne 0 ]; then
      [ $QUIET -eq 0 ] && echo "  ok    $script  bad/$(basename "$bad")  (correctly rejected, exit $rc)"
      pass=$((pass + 1))
    else
      echo "  FAIL  $script  bad/$(basename "$bad")  — expected non-zero exit, got 0 (gate is blind to this fingerprint)"
      fail=$((fail + 1))
    fi
  done
done

echo ""
echo "validators-test: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
