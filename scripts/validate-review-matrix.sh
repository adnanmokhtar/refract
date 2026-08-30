#!/usr/bin/env bash
# validate-review-matrix.sh — Phase 1 acceptance for templates/_review-matrix.md
#
# The plan's acceptance: "asserts every named skill/agent/rule resolves to a file on disk, in both
# directions — a renamed skill breaks the build, and a skill in no cell is reported."
#
# Adds a third assertion the plan does not name but needs: the file is GENERATED, so it can be
# stale without any name being wrong. Regenerating into a temp dir and diffing is the only way a
# stale grid is caught at all.
#
# Usage: validate-review-matrix.sh [--quiet]
# Exit:  0 pass / 1 fail
set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

MATRIX="$REPO_ROOT/templates/_review-matrix.md"
MODEL="$REPO_ROOT/templates/_review-model.md"
GEN="$REPO_ROOT/scripts/gen-review-matrix.py"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
FAIL=0
say(){ [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass(){ say "  ok    $*"; }
fail(){ printf '  FAIL  %s\n' "$*" >&2; FAIL=1; }

for f in "$MATRIX" "$MODEL" "$GEN"; do
  [ -f "$f" ] || { printf 'missing input: %s\n' "$f" >&2; exit 1; }
done
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---- 1  not stale: regenerating must reproduce the file byte-for-byte ----
say "freshness"
cp "$MATRIX" "$TMP/committed.md"
if python3 "$GEN" >/dev/null 2>&1; then
  if diff -q "$TMP/committed.md" "$MATRIX" >/dev/null 2>&1; then
    pass "regeneration reproduces the committed file byte-for-byte"
  else
    fail "STALE — regenerating changes it. Run scripts/gen-review-matrix.py and commit."
    diff "$TMP/committed.md" "$MATRIX" | head -20 >&2
  fi
else
  fail "generator failed to run"
fi

# ---- 2  forward: every artifact named in §5 resolves on disk ----
say "forward — named artifacts resolve"
awk '/^## 5\. Artifacts behind the grid/{f=1} f&&/^```$/{c++; next} f&&c==1{print} c==2{exit}' "$MATRIX" \
  | sed 's/^\([a-z0-9-]*\) *//' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -c . >/dev/null
awk '/^## 5\. Artifacts behind the grid/{f=1} f&&/^```$/{c++; next} f&&c==1{print} c==2{exit}' "$MATRIX" \
  | while IFS= read -r line; do
      dom="${line%% *}"; rest="${line#"$dom"}"
      printf '%s\n' "$rest" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep . | while IFS= read -r a; do
        printf '%s\t%s\n' "$dom" "$a"
      done
    done > "$TMP/named.tsv"
missing=0
while IFS=$'\t' read -r dom art; do
  if [ ! -f "$REPO_ROOT/templates/domains/$dom/rules/$art.md" ] \
     && [ ! -f "$REPO_ROOT/templates/domains/$dom/agents/$art.md" ]; then
    fail "named artifact does not resolve: $dom/$art"; missing=1
  fi
done < "$TMP/named.tsv"
n_named=$(wc -l < "$TMP/named.tsv" | tr -d ' ')
[ "$missing" -eq 0 ] && pass "all $n_named named artifacts resolve on disk"

# ---- 3  reverse: every domain artifact on disk appears in the matrix ----
say "reverse — no artifact orphaned"
find "$REPO_ROOT/templates/domains" \( -path '*/rules/*.md' -o -path '*/agents/*.md' \) 2>/dev/null \
  | sed -e "s#^$REPO_ROOT/templates/domains/##" -e 's#/rules/#\'$'\t''#' -e 's#/agents/#\'$'\t''#' -e 's#\.md$##' \
  | sort -u > "$TMP/disk.tsv"
orphan=0
while IFS=$'\t' read -r dom art; do
  grep -qF "$(printf '%s\t%s' "$dom" "$art")" "$TMP/named.tsv" || { fail "artifact in no cell: $dom/$art"; orphan=1; }
done < "$TMP/disk.tsv"
n_disk=$(wc -l < "$TMP/disk.tsv" | tr -d ' ')
[ "$orphan" -eq 0 ] && pass "all $n_disk domain artifacts on disk appear in the matrix"

# ---- 4  vocabulary agrees with the model ----
say "vocabulary agrees with _review-model.md"
awk '/^### 2\.1 /{f=1} f&&/^```$/{c++; next} f&&c==1{print} c==2{exit}' "$MODEL" \
  | tr -s ' ' '\n' | grep -E '^[a-z0-9-]+$' | sort -u > "$TMP/model_surfaces.txt"
awk '/^## 2\. The grid/{f=1} f&&/^```$/{c++; next} f&&c==1{print} c==2{exit}' "$MATRIX" \
  | awk 'NF && $1 !~ /^-+$/ && $1 != "surface" && $1 != "legend" {print $1}' | sort -u > "$TMP/matrix_surfaces.txt"
if diff -q "$TMP/model_surfaces.txt" "$TMP/matrix_surfaces.txt" >/dev/null 2>&1; then
  pass "grid rows are exactly the model's §2.1 surface vocabulary ($(wc -l < "$TMP/matrix_surfaces.txt" | tr -d ' '))"
else
  fail "grid rows diverge from _review-model.md §2.1"
  diff "$TMP/model_surfaces.txt" "$TMP/matrix_surfaces.txt" | head >&2
fi

say ""
[ "$FAIL" -eq 0 ] && say "validate-review-matrix: PASS" || printf 'validate-review-matrix: FAIL\n' >&2
exit "$FAIL"
