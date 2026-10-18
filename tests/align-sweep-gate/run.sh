#!/usr/bin/env bash
# tests/align-sweep-gate/run.sh — pins find-and-align's proof ladder (align-sweep-gate.py) and the AL-01
# meta-check (oracle-map.py quotes) against benchmarks/fixtures/convention-drift/fix-runs/.
#
#   1. align-sweep-gate.py --self-test --fix-runs=<fixture>/fix-runs: every fix-run's verdicts equal its
#      <name>.expect (each run against a copy under $TMPDIR), then the script's synthetic suite.
#   2. oracle-map.py <fixture> quotes --candidates=fix-runs/candidates-invented.json: exactly the two rows that
#      cite an oracle nobody wrote are dropped (`AL-01: 2 candidate rows dropped (of 6)`, exit 1).
#   3. Control: a copy of the fix-runs with one .expect flipped must FAIL the comparison — a harness that
#      cannot fail proves nothing.
#   4. Nothing under the fixture changed (content hash before and after).
#
# Usage:  bash tests/align-sweep-gate/run.sh [--quiet]
# Exit:   0 every check holds · 1 any check failed · 2 an engine or the fixture is missing.
set -uo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$ROOT/benchmarks/fixtures/convention-drift"
GATE="$ROOT/templates/packs/align/skills/find-and-align/scripts/align-sweep-gate.py"
ORACLE="$ROOT/templates/packs/align/skills/convention-oracle/scripts/oracle-map.py"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
for f in "$GATE" "$ORACLE" "$FIX/fix-runs/candidates-invented.json"; do
  [ -f "$f" ] || { echo "align-sweep-gate test: missing $f"; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/align-sweep-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK"
pass=0; fail=0
ok()  { pass=$((pass + 1)); [ $QUIET -eq 1 ] || echo "  ok    $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' | head -40; }
tree_hash() { ( cd "$FIX" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum ) | shasum | cut -d' ' -f1; }

before="$(tree_hash)"
runs=$(find "$FIX/fix-runs" -name '*.patch' | wc -l | tr -d ' ')

# 1. the fixture's fix-runs + the synthetic suite
out="$(python3 -I "$GATE" --self-test --fix-runs="$FIX/fix-runs" 2>&1)"; rc=$?
matched=$(printf '%s\n' "$out" | grep -c $'\texpect OK$')
if [ "$rc" -eq 0 ] && [ "$matched" -eq "$runs" ] && [ "$runs" -ge 8 ]; then
  ok "align-sweep-gate --self-test: $matched/$runs fix-runs match their .expect; $(printf '%s\n' "$out" | tail -1 | sed 's/^align-sweep-gate --self-test: //')"
else
  bad "align-sweep-gate --self-test (exit $rc, $matched/$runs runs matched)" "$out"
fi

# 2. AL-01: the invented oracle rows are dropped, the real ones kept
out="$(python3 -I "$ORACLE" "$FIX" quotes --candidates="$FIX/fix-runs/candidates-invented.json" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qx 'AL-01: 2 candidate rows dropped (of 6)' \
   && [ "$(printf '%s\n' "$out" | awk -F'\t' '$2=="dropped"{print $1}' | paste -sd, -)" = "C1,C2" ]; then
  ok "oracle-map quotes: C1, C2 dropped (AL-01); C3-C6 kept, unconfirmed or contested"
else
  bad "oracle-map quotes (exit $rc)" "$out"
fi

# 3. control: a flipped expectation must fail the comparison
mkdir -p "$WORK/control"
cp -R "$FIX/fix-runs" "$WORK/control/fix-runs"
sed -i.bak 's/^verdict PASS$/verdict FAIL/' "$WORK/control/fix-runs/run-05.expect" && rm -f "$WORK/control/fix-runs/run-05.expect.bak"
out="$(python3 -I "$GATE" --fix-runs="$WORK/control/fix-runs" --base-dir="$FIX" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^run-05	PASS	verdict expected FAIL got PASS'; then
  ok "control: a flipped run-05.expect is reported (exit 1)"
else
  bad "control: a flipped expectation was not caught (exit $rc)" "$out"
fi

# 4. read-only
after="$(tree_hash)"
if [ "$before" = "$after" ]; then ok "fixture unchanged"; else bad "the fixture tree changed during the run"; fi

echo "align-sweep-gate test: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
