#!/usr/bin/env bash
# verify-fixture-counts.sh — CONTRIBUTING's hook-fixture figures must equal what is on disk.
#
# WHY. The same failure verify-gate-count.sh was written for, one table row lower. CONTRIBUTING
# described tests/hooks/run.sh as "60 fixtures across guard-destructive (17), module-boundaries
# (15), pre-edit-guard (11), secret-scan (7) … 63 checks total". On the day this gate was written
# the true figures were 69 / 23 / 20 / 11 / 8 / 72 checks. Every one of those six numbers was
# wrong, and had been for however long people had been adding fixtures — which is the point:
# adding a fixture is the good outcome, remembering to renumber a sentence is not something a
# contributor should have to do, and nothing was reading the sentence.
#
# The figures matter because that row is how a reader decides whether the hook suite is thorough.
# A suite advertised at 60 that actually holds 69 is harmless; the same drift running the other
# way — a suite advertised at 69 after someone deletes a directory — is a suite that looks
# healthy while covering less, and that is exactly the always-allow regression tests/hooks/run.sh
# exists to catch.
#
# THE CHECK. Parse the per-hook counts and the two totals out of the CONTRIBUTING row, compare
# each against `ls` and against the runner's own "N passed" line. A figure with no counterpart on
# disk is a FAIL naming both numbers.
#
# Usage: verify-fixture-counts.sh [--quiet]
# Exit:  0 every figure matches / 1 one does not

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
cd "$REPO_ROOT" || exit 1

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
say() { [ $QUIET -eq 0 ] && echo "$@"; return 0; }

DOC="CONTRIBUTING.md"
CASES="tests/hooks/cases"
echo "=== verify-fixture-counts ==="
say ""

ROW=$(grep -n 'tests/hooks/run.sh' "$DOC" | grep -i 'fixtures across' | head -1)
if [ -z "$ROW" ]; then
  echo "FAIL  no CONTRIBUTING row describing tests/hooks/run.sh fixtures — the population is empty."
  echo "      If the row was reworded, update this gate with it; a silent pass here is the bug."
  exit 1
fi
ln="${ROW%%:*}"; txt="${ROW#*:}"
fails=0; checked=0

# ---- per-hook figures: `<name>` (N) --------------------------------------------------------
while IFS= read -r pair; do
  [ -n "$pair" ] || continue
  name=$(printf '%s' "$pair" | sed -nE 's/^`([^`]+)` \(([0-9]+)\)$/\1/p')
  want=$(printf '%s' "$pair" | sed -nE 's/^`([^`]+)` \(([0-9]+)\)$/\2/p')
  [ -n "$name" ] && [ -n "$want" ] || continue
  [ -d "$CASES/$name" ] || continue
  got=$(find "$CASES/$name" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
  checked=$((checked+1))
  if [ "$want" != "$got" ]; then
    echo "FAIL  $DOC:$ln says \`$name\` ($want); $CASES/$name holds $got."
    fails=$((fails+1))
  else
    say "  ok    $name — $got"
  fi
done <<EOF
$(printf '%s' "$txt" | grep -oE '`[a-z-]+` \([0-9]+\)')
EOF

# ---- the two totals --------------------------------------------------------------------------
total_disk=$(find "$CASES" -mindepth 2 -maxdepth 2 -name '*.json' | wc -l | tr -d ' ')
total_doc=$(printf '%s' "$txt" | sed -nE 's/.*[^0-9]([0-9]+) fixtures across.*/\1/p' | head -1)
if [ -n "$total_doc" ]; then
  checked=$((checked+1))
  if [ "$total_doc" != "$total_disk" ]; then
    echo "FAIL  $DOC:$ln says $total_doc fixtures; $CASES holds $total_disk."
    fails=$((fails+1))
  else
    say "  ok    total fixtures — $total_disk"
  fi
fi

checks_doc=$(printf '%s' "$txt" | sed -nE 's/.*[^0-9]([0-9]+) checks total.*/\1/p' | head -1)
if [ -n "$checks_doc" ]; then
  checked=$((checked+1))
  # The runner is the authority on checks: fixtures plus the programmatic assertions it adds.
  run_out=$(bash tests/hooks/run.sh 2>/dev/null | grep -oE '[0-9]+ passed' | tail -1)
  checks_run=$(printf '%s' "$run_out" | grep -oE '^[0-9]+' || true)
  if [ -z "$checks_run" ]; then
    echo "FAIL  could not read a 'N passed' line from tests/hooks/run.sh — its output format moved."
    fails=$((fails+1))
  elif [ "$checks_doc" != "$checks_run" ]; then
    echo "FAIL  $DOC:$ln says $checks_doc checks total; the runner reports $checks_run."
    fails=$((fails+1))
  else
    say "  ok    checks total — $checks_run (runner's own count)"
  fi
fi

say ""
echo "reach: $checked figure(s) checked against disk and the runner"
if [ $fails -gt 0 ]; then
  echo ""
  echo "FAIL  $fails stale figure(s) in $DOC."
  exit 1
fi
echo "PASS  every fixture figure in CONTRIBUTING matches what is on disk."
exit 0
