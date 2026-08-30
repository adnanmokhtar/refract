#!/usr/bin/env bash
# validate-review-model.sh — Phase 0 acceptance for templates/_review-model.md
#
# WHY THIS EXISTS. The model file names surfaces and gates. Every one of those names is read by
# `/audit` Phase 0 and used to resolve a cell. A name that does not resolve does not error — the
# cell is simply never dispatched, and the N/A ledger cannot report a surface that was never
# named. That is the silent-skip failure documented at templates/phases/phase-2-profile.md:269
# for §11 free-text labels, one layer up.
#
# Asserts:
#   1  every §2.1 surface name is a literal implemented key in _registry.md
#   2  §2.1 is complete — no implemented key missing (bidirectional)
#   3  every §2.2 structural name starts with `_` and is NOT a registry key
#   4  every §5 gate resolves to a registry key | a _project-kind.md value | a §2.2 name
#   5  no name appears in two dimensions
#   6  every cross-file path cited in the model resolves on disk
#
# Usage: validate-review-model.sh [--quiet]
# Exit:  0 all pass / 1 a check failed
set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

MODEL="$REPO_ROOT/templates/_review-model.md"
REGISTRY="$REPO_ROOT/templates/domains/_registry.md"
KINDFILE="$REPO_ROOT/templates/packs/_project-kind.md"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
FAIL=0

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { say "  ok    $*"; }
fail() { printf '  FAIL  %s\n' "$*" >&2; FAIL=1; }

for f in "$MODEL" "$REGISTRY" "$KINDFILE"; do
  [ -f "$f" ] || { printf 'missing input: %s\n' "$f" >&2; exit 1; }
done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---- inputs -----------------------------------------------------------------
awk '/^## Registry \(implemented\)/,/^## Registry \(cataloged/' "$REGISTRY" \
  | grep -oE '^\| `[a-z0-9-]+`' | tr -d '|` ' | sort -u > "$TMP/registry.txt"

# §2.1 fenced block: the paragraph after the "### 2.1" heading
awk '/^### 2\.1 /{f=1} f&&/^```$/{c++; next} f&&c==1{print} c==2{exit}' "$MODEL" \
  | tr -s ' ' '\n' | grep -E '^[a-z0-9-]+$' | sort -u > "$TMP/surfaces.txt"

# §2.2 structural names from the table's first column
awk '/^### 2\.2 /{f=1} f&&/^## /{exit} f' "$MODEL" \
  | grep -oE '^\| `[a-z_][a-z0-9_-]*`' | tr -d '|` ' | sort -u > "$TMP/structural.txt"

# _project-kind.md closed value set
grep -oE 'project_kind: *[a-z]+ ' "$KINDFILE" >/dev/null 2>&1
printf '%s\n' browser server mobile cli any | sort > "$TMP/kinds.txt"

# ---- 1 + 2  surface vocabulary is exactly the implemented registry ----------
say "§2.1 surface vocabulary"
if [ ! -s "$TMP/surfaces.txt" ]; then
  fail "parsed 0 surface names from §2.1 — parser or heading drift"
else
  extra="$(comm -23 "$TMP/surfaces.txt" "$TMP/registry.txt")"
  missing="$(comm -13 "$TMP/surfaces.txt" "$TMP/registry.txt")"
  [ -z "$extra" ]   && pass "all $(wc -l < "$TMP/surfaces.txt" | tr -d ' ') names are implemented registry keys" \
                    || fail "not registry keys: $(echo "$extra" | tr '\n' ' ')"
  [ -z "$missing" ] && pass "complete — no implemented key missing" \
                    || fail "registry keys absent from §2.1: $(echo "$missing" | tr '\n' ' ')"
fi

# ---- 3  structural names are underscore-prefixed and not registry keys ------
say "§2.2 structural surfaces"
if [ ! -s "$TMP/structural.txt" ]; then
  fail "parsed 0 structural names from §2.2"
else
  ok=1
  while read -r n; do
    case "$n" in _*) ;; *) fail "structural name lacks leading underscore: $n"; ok=0 ;; esac
    if grep -qx "${n#_}" "$TMP/registry.txt"; then
      fail "structural name shadows registry key: $n"; ok=0
    fi
  done < "$TMP/structural.txt"
  [ "$ok" -eq 1 ] && pass "$(wc -l < "$TMP/structural.txt" | tr -d ' ') structural names, all _-prefixed, none shadowing"
fi

# ---- 4  every §5 gate resolves ---------------------------------------------
say "§5 gates"
awk '/^## 5\. Conditional gating/{f=1} f&&/^## 6\./{exit} f' "$MODEL" \
  | grep -oE '(signal|kind|surface) `[a-z_][a-z0-9-]*`' \
  | sed 's/.*`\(.*\)`/\1/' | sort -u > "$TMP/gates.txt"
if [ ! -s "$TMP/gates.txt" ]; then
  fail "parsed 0 gates from §5"
else
  ok=1
  while read -r g; do
    grep -qx "$g" "$TMP/registry.txt" && continue
    grep -qx "$g" "$TMP/kinds.txt" && continue
    grep -qx "$g" "$TMP/structural.txt" && continue
    fail "gate does not resolve: $g"; ok=0
  done < "$TMP/gates.txt"
  [ "$ok" -eq 1 ] && pass "$(wc -l < "$TMP/gates.txt" | tr -d ' ') gates resolve to a registry key, project_kind value, or structural surface"
fi

# ---- 4b  prose kind vocabulary must not appear as a gate -------------------
awk '/^## 5\. Conditional gating/{f=1} f&&/^## 6\./{exit} f&&/^\| /{print}' "$MODEL" > "$TMP/gatetable.txt"
if grep -qE '(frontend|backend|data)-\*' "$TMP/gatetable.txt"; then
  fail "prose PROJECT_KIND family (frontend-*/backend-*/data-*) used in a gate table"
else
  pass "no prose PROJECT_KIND family used as a gate"
fi

# ---- 5  no name in two dimensions ------------------------------------------
say "cross-dimension collisions"
dup="$(cat "$TMP/surfaces.txt" "$TMP/structural.txt" | sort | uniq -d)"
[ -z "$dup" ] && pass "surface vocabularies disjoint" || fail "name in two dimensions: $dup"

# ---- 6  cited paths resolve -------------------------------------------------
say "cited paths"
bad=0
# every relative link target; skip absolute URLs and pure in-page anchors
grep -oE '\]\([^)]+\)' "$MODEL" | sed 's/^](//; s/)$//; s/#.*$//' \
  | grep -vE '^(https?:|#|$)' | sort -u > "$TMP/paths.txt"
while read -r rel; do
  [ -e "$REPO_ROOT/templates/$rel" ] || { fail "cited path does not resolve: $rel"; bad=1; }
done < "$TMP/paths.txt"
[ "$bad" -eq 0 ] && pass "$(wc -l < "$TMP/paths.txt" | tr -d ' ') cited paths resolve"

# ---- 10  concern rules (Phase 4) name only resolvable surfaces and kinds ----
say "templates/concerns/ rules"
if [ -d "$REPO_ROOT/templates/concerns" ]; then
  cbad=0; cn=0
  for f in "$REPO_ROOT"/templates/concerns/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in _*) continue ;; esac
    cn=$((cn+1))
    grep -qE '^concern: C[0-9]+' "$f" || { fail "$(basename "$f") has no 'concern: C<n>' front-matter key"; cbad=1; }
    for sfc in $(grep -oE '^\| `[a-z0-9_-]+`' "$f" | tr -d '|` '); do
      grep -qx "$sfc" "$TMP/registry.txt" || grep -qx "$sfc" "$TMP/structural.txt" \
        || { fail "$(basename "$f") names unresolvable surface: $sfc"; cbad=1; }
    done
    if grep -qE '(frontend|backend|data)-\*' "$f" && ! grep -q 'never the' "$f"; then
      fail "$(basename "$f") uses a prose PROJECT_KIND family; use browser|server|mobile|cli"; cbad=1
    fi
  done
  [ "$cbad" -eq 0 ] && pass "$cn concern rule(s): every surface resolves, no prose PROJECT_KIND"
else
  pass "no templates/concerns/ yet (Phase 4 not started)"
fi

# ---- 7/8/9  the source list is complete and every item has exactly one home ----
say "§7 source list accounting"
python3 - "$MODEL" <<'PYEOF'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()

def section(n):
    m = re.search(r"\n#{2,3} %s[.\d]* [^\n]*\n(.*?)(?=\n#{2,3} |\Z)" % re.escape(n), src, re.S)
    return m.group(1) if m else ""

fail = []

# 7 — §7.1 is a complete 01..30
nums = sorted(int(x) for x in re.findall(r"\b(\d{2})\s\s+[A-Z]", section("7.1")))
if nums != list(range(1, 31)):
    missing = sorted(set(range(1, 31)) - set(nums))
    dupes = sorted({n for n in nums if nums.count(n) > 1})
    fail.append("§7.1 is not a clean 01-30 (missing=%s dupes=%s count=%d)" % (missing, dupes, len(nums)))
else:
    print("  ok    §7.1 is a complete 01-30, no gap, no duplicate")

# 8 — recompute the classification from §2/§3/§4 themselves
surf = sorted(int(x) for x in re.findall(r"`(\d{2})`", section("7.3")[:section("7.3").find("Concern")]))
axes = sorted(int(x) for x in re.findall(r"\b(\d{2})\s\s+[A-Z]", section("4.1")))
conc = sorted(int(x) for x in re.findall(r"yes — `(\d{2})`", section("3.1")))
allc = sorted(surf + axes + conc)
if allc != list(range(1, 31)):
    fail.append("classification is not a partition: surfaces=%d axes=%d concerns=%d total=%d overlap=%s"
                % (len(surf), len(axes), len(conc), len(allc),
                   sorted({n for n in allc if allc.count(n) > 1})))
else:
    print("  ok    30 = %d surfaces + %d concerns + %d axes, each number classified exactly once"
          % (len(surf), len(conc), len(axes)))

# 9 — all 7 cross-cutting are in §3.1; exactly 4 carry a source number
seven = [w.strip() for w in re.split(r"\s{2,}", section("7.2").replace("```", "").strip()) if w.strip()]
tbl = section("3.1")
if len(seven) != 7:
    fail.append("§7.2 lists %d cross-cutting concerns, expected 7: %s" % (len(seven), seven))
else:
    absent = [c for c in seven if c not in tbl]
    numbered = len(re.findall(r"yes — `\d{2}`", tbl))
    if absent:
        fail.append("cross-cutting concern(s) missing from §3.1: %s" % absent)
    elif numbered != 4:
        fail.append("§3.1 marks %d concerns as carrying a source number, expected 4" % numbered)
    else:
        print("  ok    all 7 cross-cutting concerns present in §3.1; exactly 4 carry a source number")

for f in fail:
    print("  FAIL  " + f, file=sys.stderr)
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] || FAIL=1

say ""
if [ "$FAIL" -eq 0 ]; then say "validate-review-model: PASS"; else printf 'validate-review-model: FAIL\n' >&2; fi
exit "$FAIL"
