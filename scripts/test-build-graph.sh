#!/usr/bin/env bash
# test-build-graph.sh — pin the two properties that make an assembled graph safe to trust.
#
# The claim being locked is not "the graph builds". It is:
#
#   (A) THE GRAPH CANNOT EXCEED ITS GATES. Case 3 reads each gate's own reach line and asserts
#       the edge count matches it exactly. A graph that quietly carried one more edge than CI
#       enforces would be a graph asserting something no gate ever proved, which is the whole
#       failure mode a derived artifact is prone to. Equality both ways is the point: fewer
#       edges than proven is a silently lossy graph, more is a fabricated one.
#
#   (B) IT CANNOT GO STALE. Case 4 edits a file a gate reads and asserts the cache is REJECTED.
#       A cached graph that survives an edit to its own input is the exact hazard that kept this
#       artifact out of the repo until now. mtime is restored afterwards, so the test leaves no
#       trace on disk.
#
# Usage: test-build-graph.sh [--quiet]
# Exit:  0 all assertions hold / 1 one did not

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
G="$REPO_ROOT/scripts/build-graph.py"

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
pass=0; fail=0
ok()   { pass=$((pass+1)); [ $QUIET -eq 0 ] && echo "  ok    $1"; return 0; }
bad()  { fail=$((fail+1)); echo "  FAIL  $1"; return 0; }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1 — expected '$3', got '$2'"; }

command -v python3 >/dev/null 2>&1 || { echo "SKIP  build-graph (needs python3)"; exit 0; }
cd "$REPO_ROOT" || exit 1

echo "=== test-build-graph ==="

# ---------- 1. it builds, and every edge resolves on disk ------------------------------------
if python3 "$G" --check --repo-root="$REPO_ROOT" >/dev/null 2>&1; then
  ok "--check passes (edges resolve, build is deterministic)"
else
  bad "--check does not pass"
fi

# ---------- 2. the graph is a cache, never a tracked file ------------------------------------
python3 "$G" --stats --repo-root="$REPO_ROOT" >/dev/null 2>&1
if git -C "$REPO_ROOT" check-ignore -q tmp/graph/graph.json 2>/dev/null; then
  ok "the built graph is gitignored (a cache, not a source)"
else
  bad "tmp/graph/graph.json is NOT gitignored — it could be committed and then drift"
fi

# ---------- 3. (A) edge count equals what the gates report proving ---------------------------
# lint-import-edges prints:  "reach: N claim lines · N targets · <D> direct · <H> via one hop · …"
reach=$(bash scripts/lint-import-edges.sh --quiet --repo-root="$REPO_ROOT" 2>/dev/null \
        | grep '^reach:' || true)
d=$(printf '%s' "$reach" | sed -n 's/.*· \([0-9][0-9]*\) direct .*/\1/p')
h=$(printf '%s' "$reach" | sed -n 's/.*· \([0-9][0-9]*\) via one hop.*/\1/p')
if [ -n "$d" ] && [ -n "$h" ]; then
  want=$((d + h))
  got=$(python3 "$G" --json --repo-root="$REPO_ROOT" 2>/dev/null \
        | python3 -c 'import json,sys; print(sum(1 for e in json.load(sys.stdin)["edges"] if e["kind"]=="import"))')
  assert_eq "import edges == the gate's own direct+hop count" "$got" "$want"
else
  bad "could not read the import gate's reach line — its format moved"
fi

# ---------- 3b. a baselined claim is withheld, not carried ----------------------------------
# Every emitted edge must be one the gate proved. The baseline file lists claims it could NOT
# verify; none of those pairs may appear as an edge.
base="scripts/_import-edge-baseline.txt"
leaked=0
if [ -f "$base" ]; then
  json=$(python3 "$G" --json --repo-root="$REPO_ROOT" 2>/dev/null)
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    a=$(printf '%s' "$line" | awk '{print $1}')
    b=$(printf '%s' "$line" | awk '{print $2}')
    [ -n "$a" ] && [ -n "$b" ] || continue
    if printf '%s' "$json" | grep -q "\"from\": \"$b\"" && \
       printf '%s' "$json" | grep -q "\"to\": \"$a\""; then
      leaked=$((leaked+1))
    fi
  done < "$base"
fi
assert_eq "no baselined (unverified) claim leaked into the graph" "$leaked" "0"

# ---------- 4. (B) the staleness contract ----------------------------------------------------
victim="templates/capabilities.md"
if [ -f "$victim" ]; then
  stamp=$(mktemp); touch -r "$victim" "$stamp"
  python3 "$G" --stats --repo-root="$REPO_ROOT" >/dev/null 2>&1     # warm
  first=$(python3 "$G" --stats --repo-root="$REPO_ROOT" 2>/dev/null | grep -c 'cache hit')
  assert_eq "an unchanged tree serves from cache" "$first" "1"
  touch "$victim"
  after=$(python3 "$G" --stats --repo-root="$REPO_ROOT" 2>/dev/null | grep -c 'cache rebuilt')
  assert_eq "editing a gate input REJECTS the cache" "$after" "1"
  touch -r "$stamp" "$victim"; rm -f "$stamp"
else
  bad "fixture file $victim is gone — case 4 cannot run"
fi

# ---------- 5. traversal answers the question it advertises ----------------------------------
who=$(python3 "$G" --who-breaks templates/capabilities.md --repo-root="$REPO_ROOT" 2>/dev/null)
if printf '%s' "$who" | grep -q 'commands/setup-project.md'; then
  ok "--who-breaks finds a declared consumer without opening the file"
else
  bad "--who-breaks missed a consumer the import gate proved"
fi

miss=$(python3 "$G" --who-breaks does/not/exist.md --repo-root="$REPO_ROOT" 2>&1; echo "rc=$?")
if printf '%s' "$miss" | grep -q 'rc=2'; then
  ok "an unknown node exits 2 rather than answering emptily"
else
  bad "an unknown node did not exit 2 — an empty answer reads as 'nothing breaks'"
fi

# ---------- 6. --corpus=project on a READ-ONLY target: --no-cache / --cache-dir -------------
# The default project cache is <repo>/.claude/_graph.json. An audit pre-flight that promised not
# to write the checkout wrote that file (2026-10-15). Both flags must leave the target untouched.
PJ=$(mktemp -d); CD=$(mktemp -d)
mkdir -p "$PJ/src"
echo 'export const a = 1;'                                   > "$PJ/src/a.ts"
printf 'import type { T } from "./c";\nimport { a } from "./a";\nexport const b = a;\n' > "$PJ/src/b.ts"
printf 'import { b } from "./b";\nexport type T = typeof b;\n'  > "$PJ/src/c.ts"
python3 "$G" --corpus=project --repo="$PJ" --no-cache --stats >/dev/null 2>&1
assert_eq "--no-cache writes nothing into the target" "$(find "$PJ" -name '_graph.json' | wc -l | tr -d ' ')" "0"
nc=$(python3 "$G" --corpus=project --repo="$PJ" --no-cache --stats 2>/dev/null | grep -c 'cache off')
assert_eq "--no-cache says so instead of claiming a hit or a rebuild" "$nc" "1"
python3 "$G" --corpus=project --repo="$PJ" --cache-dir="$CD" --stats >/dev/null 2>&1
assert_eq "--cache-dir writes the cache there, not into the target" \
  "$(find "$PJ" -name '_graph.json' | wc -l | tr -d ' ') $(find "$CD" -maxdepth 1 -name '_graph.json' | wc -l | tr -d ' ')" "0 1"
hit=$(python3 "$G" --corpus=project --repo="$PJ" --cache-dir="$CD" --stats 2>/dev/null | grep -c 'cache hit')
assert_eq "--cache-dir is served on the second run" "$hit" "1"
lab=$(python3 "$G" --corpus=project --repo="$PJ" --no-cache --json 2>/dev/null \
  | python3 -c 'import json,sys; print(sorted((e["from"][4:],e["to"][4:],e["label"]) for e in json.load(sys.stdin)["edges"]))')
assert_eq "code edges carry the ranker's type-only label" "$lab" \
  "[('b.ts', 'a.ts', ''), ('b.ts', 'c.ts', 'type'), ('c.ts', 'b.ts', '')]"
both=$(python3 "$G" --corpus=project --repo="$PJ" --no-cache --cache-dir="$CD" --stats >/dev/null 2>&1; echo $?)
assert_eq "--no-cache with --cache-dir is a usage error" "$both" "2"
rm -rf "$PJ" "$CD"

echo ""
echo "reach: $((pass + fail)) assertions · $pass passed · $fail failed"
[ $fail -gt 0 ] && { echo "FAIL  $fail assertion(s)."; exit 1; }
echo "PASS  the graph cannot exceed its gates, and cannot survive an edit to its inputs."
exit 0
