#!/usr/bin/env bash
# test-pack-search.sh — regression test for the row-granularity retrieval layer.
#
# Covers the three things that can silently rot:
#   1. EXTRACTION  — the catalog builds, is deterministic, regenerates byte-identically,
#                    and every emitted `path:line` pointer still resolves.
#   2. RETRIEVAL   — a handful of queries whose right answer is a stable fact about this
#                    repo still surface the right rows (BM25 tuning can regress silently).
#   3. CONTRACT    — filters actually filter, the hard cap holds, --json is valid JSON,
#                    the "rows point AT prose" disclosure is present, and the deliberately
#                    UNINDEXED prose (_examples/, discipline catalogues) stays unindexed.
#
# Pure stdlib + shell. No network, no pip. Exit 0 = clean, 1 = drift.
#
# Usage: scripts/test-pack-search.sh [--repo-root=<dir>]

set -o pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$ROOT" || exit 1

ERRORS=0
fail() { printf '\033[31m✗ %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass() { printf '\033[32m✓ %s\033[0m\n' "$*"; }
info() { printf '\033[36m• %s\033[0m\n' "$*"; }

SEARCH="python3 $ROOT/scripts/pack-search.py --repo-root=$ROOT"
GEN="python3 $ROOT/scripts/gen-pack-catalog.py --repo-root=$ROOT"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pack-search-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "================================================================"
echo "  pack-search — retrieval regression fixture"
echo "================================================================"

# ───────────────── 1. extraction: builds, deterministic, pointers resolve ─────────────────
info ""
info "1. Catalog extraction (--check: determinism + pointer integrity)"
if $GEN --check > "$WORK/check.txt" 2>&1; then
  pass "gen-pack-catalog.py --check: PASS"
  grep -E '^\s+(ok|[0-9]+ rows)' "$WORK/check.txt" | sed 's/^/    /'
else
  fail "gen-pack-catalog.py --check: FAIL"
  sed 's/^/    /' "$WORK/check.txt"
fi

# ───────────────── 2. regenerate-and-diff (the CI-friendly freshness check) ────────────────
info ""
info "2. Regenerate and diff (catalog is reproducible from source)"
$GEN --stdout > "$WORK/a.csv" 2>/dev/null
$GEN --stdout > "$WORK/b.csv" 2>/dev/null
if [ ! -s "$WORK/a.csv" ]; then
  fail "catalog is empty"
elif diff -q "$WORK/a.csv" "$WORK/b.csv" >/dev/null; then
  pass "two independent runs are byte-identical ($(wc -l < "$WORK/a.csv" | tr -d ' ') lines)"
else
  fail "catalog is non-deterministic — two runs differ"
  diff "$WORK/a.csv" "$WORK/b.csv" | head -10 | sed 's/^/    /'
fi
$GEN --format=jsonl --stdout > "$WORK/a.jsonl" 2>/dev/null
if python3 -c "
import json,sys
n=0
for ln in open('$WORK/a.jsonl'):
    json.loads(ln); n+=1
sys.exit(0 if n > 4000 else 1)"; then
  pass "jsonl export is valid JSON per line ($(wc -l < "$WORK/a.jsonl" | tr -d ' ') rows)"
else
  fail "jsonl export invalid or implausibly small"
fi

# Explicit --out promotes staleness from WARN to FAIL — prove the freshness gate fires.
FRESH_REL="tmp/pack-search/selftest-catalog.csv"
rm -f "$ROOT/$FRESH_REL"
$GEN --out="$FRESH_REL" >/dev/null 2>&1
if $GEN --check --out="$FRESH_REL" >/dev/null 2>&1; then
  pass "freshly written catalog passes --check --out=<path>"
else
  fail "a just-written catalog failed its own freshness check"
fi
printf 'stale,row,injected,by,the,test,x,y,z\n' >> "$ROOT/$FRESH_REL"
if $GEN --check --out="$FRESH_REL" >/dev/null 2>&1; then
  fail "a mutated catalog still passed --check — the freshness gate does not fire"
else
  pass "mutated catalog FAILs --check (regenerate-and-diff gate is live)"
fi
rm -f "$ROOT/$FRESH_REL"

ROW_COUNT=$(python3 -c "
import csv,sys
print(sum(1 for _ in csv.DictReader(open('$WORK/a.csv'))))")
if [ "${ROW_COUNT:-0}" -ge 4500 ]; then
  pass "row count plausible: $ROW_COUNT (floor 4500)"
else
  fail "row count $ROW_COUNT below floor 4500 — an extractor stopped matching"
fi

# A single global floor CANNOT see one extractor going dark, and did not: when `skills/`
# migrated from `skills/<name>.md` to `skills/<name>/SKILL.md`, all 98 `skill` rows and
# all 72 `closure-verb` rows silently left the index and the total still read 4,982 —
# comfortably above 4,500. Every kind therefore carries its own floor, set ~10% under the
# count at the time of writing so ordinary authoring churn does not trip it.
# Excluded on purpose: `pattern`, `topic-ai-pattern`, `topic-reference-pair` — those are
# the vocabulary-drift kinds `--check` WARNs about, and they SHOULD fall to zero when the
# `kind:` vocabulary is unified. A floor on them would punish the fix.
KIND_FLOOR_OUT=$(python3 - "$WORK/a.csv" <<'PY'
import csv, sys
from collections import Counter
FLOORS = {
    "rule-directive": 1900, "domain-checklist": 1550, "command": 150, "ai-pattern": 108,
    "catalog-row": 94, "agent": 93, "skill": 88, "topic-command": 99, "topic-pattern": 78,
    "topic-skill": 76, "stack-subst": 69, "closure-verb": 64, "topic-agent": 62,
    "rule": 54, "trigger": 49, "reference": 27, "topic-rule": 25,
}
counts = Counter(r["kind"] for r in csv.DictReader(open(sys.argv[1])))
for k, floor in sorted(FLOORS.items()):
    if counts.get(k, 0) < floor:
        print("%s=%d (floor %d)" % (k, counts.get(k, 0), floor))
PY
)
if [ -z "$KIND_FLOOR_OUT" ]; then
  pass "all 17 indexed kinds clear their own floor (a dark extractor cannot hide behind the total)"
else
  fail "a kind fell below its floor — that extractor stopped matching"
  sed 's/^/      /' <<<"$KIND_FLOOR_OUT"
fi

# ───────────────── 3. deliberate exclusions (prose must stay unindexed) ─────────────────
info ""
info "3. Deliberate exclusions — narrative prose is NOT flattened into rows"
# The `path` column is what gets Read. A topic spec's `fallback: _examples/…` pointer may
# appear in `text` (that is the point — the example is REACHED by path), but no row may
# itself BE an _examples/ file.
if python3 -c "
import csv,sys
bad=[r['id'] for r in csv.DictReader(open('$WORK/a.csv')) if r['path'].startswith('templates/packs/') and '/_examples/' in r['path']]
sys.stderr.write('\\n'.join(bad[:5]))
sys.exit(1 if bad else 0)"; then
  pass "_examples/ absent from every row path (whole-artifact fallbacks reached by path only)"
else
  fail "_examples/ leaked into the catalog (267 whole-artifact files — must stay out)"
fi
for prose in align-discipline-catalogue migration-discipline-catalogue; do
  n=$(grep -c "references/$prose\.md" "$WORK/a.csv" || true)
  # `-le 1` also accepts ZERO — a renamed or dropped catalogue file printed "pass … 0 row" while
  # the pointer this asserts had ceased to exist. The property is exactly one row.
  if [ "${n:-0}" -eq 1 ]; then
    pass "$prose.md: $n row (file-level pointer only, ❌/✅ pairs not split)"
  elif [ "${n:-0}" -eq 0 ]; then
    fail "$prose.md: no row at all — the catalogue file is missing or was renamed"
  else
    fail "$prose.md exploded into $n rows — its reasoning does not survive row-splitting"
  fi
done
# Ordered procedure steps (`### 7. Generate current spec`) must NOT become closure verbs.
if python3 -c "
import csv,sys,re
bad=[r for r in csv.DictReader(open('$WORK/a.csv'))
     if r['kind']=='closure-verb' and not re.fullmatch(r'[a-z][a-z0-9]*(-[a-z0-9]+)+', r['name'])]
sys.stderr.write('\n'.join(b['id'] for b in bad[:5]))
sys.exit(1 if bad else 0)"; then
  pass "closure verbs are kebab-case set members only (ordered steps excluded)"
else
  fail "an ordered procedure step was captured as a closure verb — order is content"
fi

# ───────────────── 4. retrieval assertions ─────────────────
info ""
info "4. Retrieval — known queries must surface the governing rows"

# expect_hit <label> <expected-path-substring> <query> [flags...]
expect_hit() {
  local label="$1" want="$2" query="$3"; shift 3
  local out
  out=$($SEARCH "$query" --format=paths --limit=8 "$@" 2>&1)
  if grep -qF "$want" <<<"$out"; then
    pass "$label → $want"
  else
    fail "$label → expected '$want' in top 8 for '$query' ${*:-}"
    sed 's/^/      /' <<<"$out" | head -8
  fi
}

expect_hit "multi-tenant isolation"    "templates/domains/multi-tenant/" \
           "multi-tenant isolation cross-tenant leak"
expect_hit "multi-tenant (rule row)"   "templates/domains/multi-tenant/rules/" \
           "tenant_id filter missing on query" --kind=rule-directive
expect_hit "webhook replay"            "templates/domains/webhook/" \
           "webhook signature verification replay"
expect_hit "ecommerce guest checkout"  "templates/business-domains/ecommerce/feature-checklist.md" \
           "guest checkout cart merging" --domain=ecommerce
expect_hit "n+1 query"                 "templates/packs/backend/rules/backend-principles.md" \
           "n+1 query eager loading" --kind=rule-directive
expect_hit "focus ring closure verb"   "templates/packs/ui-ux/skills/ui-design-sweep/SKILL.md" \
           "focus ring keyboard indicator" --kind=closure-verb
expect_hit "reduced motion"            "templates/packs/ui-ux/" \
           "prefers-reduced-motion animation duration"
expect_hit "repository pattern (stack)" "templates/packs/backend/references/nestjs.md" \
           "repository pattern dependency injection" --stack=nestjs
expect_hit "topic spec lookup"         "templates/packs/ui-ux/_topics.md" \
           "design system architect tokens" --pack=ui-ux --kind=topic-agent
expect_hit "registry row"              "templates/packs/_registry.md" \
           "track detection signals ORM migrations schema" --scope=registry
expect_hit "trigger vocabulary"        "templates/packs/_trigger-vocabulary.md" \
           "dark mode capability detected" --kind=trigger
expect_hit "stack substitution table"  "STACK.md" \
           "structured logger substitution" --kind=stack-subst

# ───────────────── 5. filter contract ─────────────────
info ""
info "5. Filter contract — filters actually constrain the result set"

check_all_paths_under() {
  local label="$1" prefix="$2"; shift 2
  local out bad
  out=$($SEARCH "$@" --format=paths --limit=15 2>&1)
  bad=$(grep -v "^$prefix" <<<"$out" | grep -v '^$' || true)
  if [ -z "$out" ]; then
    fail "$label: no results at all"
  elif [ -z "$bad" ]; then
    pass "$label: every result under $prefix"
  else
    fail "$label: leaked outside $prefix"
    sed 's/^/      /' <<<"$bad" | head -5
  fi
}
check_all_paths_under "--pack=ui-ux"   "templates/packs/ui-ux/"          "contrast token spacing" --pack=ui-ux
check_all_paths_under "--domain=fintech" "templates/business-domains/fintech/" "ledger reconciliation" --domain=fintech

KINDS_OUT=$($SEARCH "review checklist" --kind=rule-directive --json --limit=10 2>&1)
if python3 -c "
import json,sys
d=json.loads('''$KINDS_OUT''')
sys.exit(0 if d['results'] and all(r['kind']=='rule-directive' for r in d['results']) else 1)" 2>/dev/null; then
  pass "--kind=rule-directive: every result is a rule-directive"
else
  fail "--kind filter did not constrain kinds"
fi

CAP=$($SEARCH "must validate error" --limit=200 --format=paths 2>/dev/null | grep -c . || true)
if [ "${CAP:-0}" -le 25 ] && [ "${CAP:-0}" -ge 10 ]; then
  pass "--limit hard cap holds ($CAP ≤ 25)"
else
  fail "--limit hard cap breached: $CAP results"
fi

# ───────────────── 6. output contract ─────────────────
info ""
info "6. Output contract"
TEXT_OUT=$($SEARCH "tenant isolation" --limit=3 2>&1)
if grep -q 'Rows point AT prose' <<<"$TEXT_OUT"; then
  pass "text output carries the pointer-not-answer disclosure"
else
  fail "text output is missing the mandatory disclosure footer"
fi
if grep -qE '^[0-9]+\.[0-9]+ ' <<<"$TEXT_OUT" && grep -qE '\.md(:[0-9]+)?$' <<<"$TEXT_OUT"; then
  pass "text output shows score + path (with :line where addressable)"
else
  fail "text output does not match the score/kind/owner/path contract"
fi
if $SEARCH "tenant isolation" --json --limit=3 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['results'] and 'path' in d['results'][0] and d['disclaimer']
sys.exit(0)" 2>/dev/null; then
  pass "--json emits parseable JSON with path + disclaimer"
else
  fail "--json output is not valid / missing keys"
fi
EMPTY=$($SEARCH "zzqqxx yywwvv qqzzxxvv" --limit=3 2>&1)
if grep -q 'no rows matched' <<<"$EMPTY"; then
  pass "empty result set is reported honestly (no fabricated hit)"
else
  fail "a no-match query did not report 'no rows matched'"
fi

# ───────────────── 7. cache behaviour + latency ─────────────────
info ""
info "7. Cache + latency (must be inline-callable)"
CACHE="tmp/pack-search/selftest-index.json"
rm -f "$ROOT/$CACHE"
COLD_START=$(python3 -c 'import time;print(time.time())')
$SEARCH "tenant isolation" --cache="$CACHE" --rebuild --limit=1 >/dev/null 2>&1
COLD=$(python3 -c "import time;print(int((time.time()-$COLD_START)*1000))")
if [ -f "$ROOT/$CACHE" ]; then
  pass "cold run wrote the cache to $CACHE (gitignored via tmp/)"
else
  fail "cold run did not write a cache"
fi
WARM_START=$(python3 -c 'import time;print(time.time())')
WARM_OUT=$($SEARCH "tenant isolation" --cache="$CACHE" --limit=1 2>&1)
WARM=$(python3 -c "import time;print(int((time.time()-$WARM_START)*1000))")
if grep -q 'index: cache' <<<"$WARM_OUT"; then
  pass "warm run reused the cache (cold ${COLD}ms → warm ${WARM}ms)"
else
  fail "warm run rebuilt instead of reusing the cache"
fi
# Wall-clock on shared CI is not a correctness signal — it measures how busy the runner is, and
# these numbers include extra interpreter startups. A flapping red gate gets ignored, and an
# ignored gate protects nothing. Report it always; fail only past a margin so wide that only a
# real algorithmic regression reaches it.
if [ "${COLD:-9999}" -lt 3000 ] && [ "${WARM:-9999}" -lt 1000 ]; then
  pass "latency budget: cold ${COLD}ms < 3000, warm ${WARM}ms < 1000"
elif [ "${COLD:-9999}" -lt 15000 ] && [ "${WARM:-9999}" -lt 5000 ]; then
  info "latency above target but within tolerance: cold ${COLD}ms (target 3000) / warm ${WARM}ms (target 1000) — a loaded runner, not a regression"
  pass "latency within tolerance"
else
  fail "latency budget blown by an order of magnitude: cold ${COLD}ms / warm ${WARM}ms — that is a regression, not load"
fi
# An edited source file must invalidate the cache (fingerprint = size + mtime).
# Bump the mtime, then restore it — the file's CONTENT is never touched.
PROBE="$ROOT/templates/packs/_registry.md"
ORIG_MTIME=$(python3 -c "import os;print(os.stat('$PROBE').st_mtime_ns)")
touch "$PROBE"
INVAL=$($SEARCH "tenant isolation" --cache="$CACHE" --limit=1 2>&1)
python3 -c "import os;os.utime('$PROBE', ns=($ORIG_MTIME, $ORIG_MTIME))"
if grep -q 'index: rebuild' <<<"$INVAL"; then
  pass "touching a source file invalidates the cache (no stale-index drift)"
else
  fail "cache survived a source-file change — the index can go stale"
fi
rm -f "$ROOT/$CACHE"

# ───────────────── 8. determinism of ranking ─────────────────
info ""
info "8. Ranking determinism"
R1=$($SEARCH "tenant isolation cache key" --limit=8 --format=paths 2>&1)
R2=$($SEARCH "tenant isolation cache key" --limit=8 --format=paths --rebuild 2>&1)
if [ "$R1" = "$R2" ]; then
  pass "same query → same ranking across a cache hit and a rebuild"
else
  fail "ranking differs between cached and rebuilt index"
  diff <(echo "$R1") <(echo "$R2") | head -6 | sed 's/^/      /'
fi

# ───────────────── 9. end-to-end self check ─────────────────
info ""
info "9. pack-search.py --check"
if $SEARCH --check > "$WORK/selfcheck.txt" 2>&1; then
  pass "pack-search.py --check: PASS"
else
  fail "pack-search.py --check: FAIL"
  sed 's/^/    /' "$WORK/selfcheck.txt" | tail -20
fi

echo ""
echo "================================================================"
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[32m  pack-search: ALL CHECKS PASS\033[0m\n'
  echo "================================================================"
  exit 0
fi
printf '\033[31m  pack-search: %d FAILURE(S)\033[0m\n' "$ERRORS"
echo "================================================================"
exit 1
