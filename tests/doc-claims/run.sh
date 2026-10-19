#!/usr/bin/env bash
# tests/doc-claims/run.sh — pins doc-drift-scan's engine (doc-claims.py) against benchmarks/fixtures/doc-drift.
#
#   1. doc-claims.py --self-test: the synthetic suite plus the git-history lanes (DH-1, DI-2, DL-1 detail).
#   2. The fixture staged the way the benchmark stages it (benchmarks/run.sh: one commit, then the key's
#      `Stage with: --history` replays the fixed 14-commit release history), the engine run read-only on it, and
#      its candidate rows (class, status, doc, line, claim; a DH-1 SHA written <sha>) equal engine.expect.
#   3. Control: a copy of engine.expect with one row flipped must FAIL the comparison — a harness that cannot
#      fail proves nothing.
#   4. Nothing under the fixture or the staged copy changed (content hash before and after the engine run).
#
# Usage:  bash tests/doc-claims/run.sh [--quiet]
# Exit:   0 every check holds · 1 any check failed · 2 the engine, the fixture or git is missing.
set -uo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/tests/doc-claims"
FIX="$ROOT/benchmarks/fixtures/doc-drift"
ENGINE="$ROOT/templates/packs/documentation/skills/doc-drift-scan/scripts/doc-claims.py"
EXPECT="$HERE/engine.expect"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
for f in "$ENGINE" "$EXPECT" "$FIX/DEFECTS.md" "$FIX/.refract-fixture/stage-history.sh" "$ROOT/benchmarks/run.sh"; do
  [ -f "$f" ] || { echo "doc-claims test: missing $f"; exit 2; }
done
command -v git >/dev/null 2>&1 || { echo "doc-claims test: git is not on PATH"; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/doc-claims-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK"
pass=0; fail=0
ok()  { pass=$((pass + 1)); [ $QUIET -eq 1 ] || echo "  ok    $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' | head -40; }
tree_hash() { ( cd "$1" && find . -path ./.git -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum ) | shasum | cut -d' ' -f1; }
# class, status, doc, line, claim — the order engine.expect is written in, sorted the same way
rows() { awk -F'\t' '$2=="MISS"||$2=="WRONG"||$2=="CHECK"{c=$7; sub(/^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]+ /,"<sha> ",c); print $3"\t"$2"\t"$5"\t"$6"\t"c}' "$1" \
         | LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k3,3 -k5,5; }
compare() { diff <(grep -v '^#' "$1" | LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k3,3 -k5,5) "$2"; }

fix_before="$(tree_hash "$FIX")"

# 1. self-test
out="$(python3 -I -B "$ENGINE" --self-test 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "doc-claims --self-test: $(printf '%s\n' "$out" | tail -1 | sed 's/^self-test: //')"
else bad "doc-claims --self-test (exit $rc)" "$out"; fi

# 2. the history-staged fixture against engine.expect
if ! bash "$ROOT/benchmarks/run.sh" --fixture=doc-drift --workdir="$WORK/stage" >"$WORK/stage.log" 2>&1; then
  bad "benchmarks/run.sh could not stage doc-drift" "$(tail -5 "$WORK/stage.log")"
else
  COPY="$WORK/stage/doc-drift"
  tags="$(git -C "$COPY" tag | paste -sd, -)"
  copy_before="$(tree_hash "$COPY")"
  python3 -I -B "$ENGINE" "$COPY" --out="$WORK/out" >"$WORK/rows.tsv" 2>"$WORK/ledger.txt"; rc=$?
  rows "$WORK/rows.tsv" > "$WORK/got.tsv"
  n="$(wc -l < "$WORK/got.tsv" | tr -d ' ')"
  if [ "$rc" -eq 1 ] && [ "$tags" = "v1.4.0,v1.5.0" ] && d="$(compare "$EXPECT" "$WORK/got.tsv")"; then
    ok "doc-drift (history-staged, tags $tags): $n candidate rows equal engine.expect"
  else
    bad "doc-drift rows differ from engine.expect (exit $rc, tags '$tags', $n rows)" "${d:-$(tail -3 "$WORK/ledger.txt")}"
  fi
  if grep -q 'DI-2 history-blind on 2 pair' "$WORK/ledger.txt"; then ok "ledger names the 2 history-blind DI-2 pairs"
  else bad "ledger lost the DI-2 history-blind note" "$(grep 'lane i18n' "$WORK/ledger.txt")"; fi
  [ "$(tree_hash "$COPY")" = "$copy_before" ] && ok "engine wrote nothing into the scanned copy" \
    || bad "the engine changed the scanned copy"

  # 3. control: one flipped expectation must fail the comparison
  awk 'BEGIN{FS=OFS="\t"} !/^#/ && !d && $1=="DE-2" {$2="WRONG"; d=1} {print}' "$EXPECT" > "$WORK/flipped.expect"
  if ! cmp -s "$WORK/flipped.expect" "$EXPECT" && ! compare "$WORK/flipped.expect" "$WORK/got.tsv" >/dev/null; then
    ok "control: a flipped engine.expect row is reported"
  else
    bad "control: a flipped expectation was not caught"
  fi
fi

# 4. the fixture itself is read-only
[ "$(tree_hash "$FIX")" = "$fix_before" ] && ok "fixture unchanged" || bad "the fixture tree changed during the run"

echo "doc-claims test: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
