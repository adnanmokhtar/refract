#!/usr/bin/env bash
# find-duplication.sh — surface overlapping content across packs.
#
# Three checks:
#   1. Files with the same H1 in 2+ files.
#   2. Files with the same first body paragraph (100 chars) in 2+ files.
#   3. MUST / MUST NOT bullets repeated verbatim 3+ times.
#
# Candidate finder, not a fixer. Macos-bash compatible (no associative arrays).

set -euo pipefail
export LC_ALL=C    # tr / sed are byte-oriented; avoid Illegal byte sequence on UTF-8 inputs.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d /tmp/m7-dup.XXXXXX)"
trap "rm -rf '$TMPDIR'" EXIT

H1_LOG="$TMPDIR/h1.tsv"
LEAD_LOG="$TMPDIR/lead.tsv"

# Use a tab separator: <key>\t<file>
while IFS= read -r f; do
  rel="${f#$REPO_ROOT/}"

  h1=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g; s/  */ /g; s/^ *//; s/ *$//' || true)
  if [[ -n "$h1" ]]; then
    printf '%s\t%s\n' "$h1" "$rel" >>"$H1_LOG"
  fi

  lead=$(awk '
    /^---$/ { if (in_fm) { in_fm = 0; next } else { in_fm = 1; next } }
    in_fm { next }
    /^#/ { next }
    /^$/ { next }
    { print; exit }
  ' "$f" | head -c 100 | tr -s ' ')
  if [[ -n "$lead" ]]; then
    printf '%s\t%s\n' "$lead" "$rel" >>"$LEAD_LOG"
  fi
done < <(find "$REPO_ROOT/templates" -type f -name '*.md' \
    \( -path '*/rules/*' -o -path '*/ai-patterns/*' -o -path '*/patterns/*' \
       -o -path '*/skills/*' -o -path '*/agents/*' -o -path '*/commands/*' \) \
    | sort)

echo "=== Duplicate H1 titles (same heading in 2+ files) ==="
# Collapse: for each key, list of files
awk -F'\t' '{ files[$1] = files[$1] "\n    " $2; n[$1]++ } END { for (k in n) if (n[k]>=2) printf "\n  H1: \"%s\"%s\n", k, files[k] }' "$H1_LOG" | head -100
dup_h1_count=$(awk -F'\t' '{ n[$1]++ } END { c=0; for (k in n) if (n[k]>=2) c++; print c }' "$H1_LOG")

echo ""
echo "=== Duplicate lead paragraphs (verbatim opening 100 chars) ==="
awk -F'\t' '{ files[$1] = files[$1] "\n    " $2; n[$1]++ } END { for (k in n) if (n[k]>=2) printf "\n  lead: \"%s\"%s\n", k, files[k] }' "$LEAD_LOG" | head -50
dup_lead_count=$(awk -F'\t' '{ n[$1]++ } END { c=0; for (k in n) if (n[k]>=2) c++; print c }' "$LEAD_LOG")

echo ""
echo "=== Top MUST bullets repeated verbatim 3+ times ==="
grep -rhE '^- (\*\*MUST|MUST)' "$REPO_ROOT/templates" 2>/dev/null \
  | sed 's/[`*]//g' \
  | sed 's/^- //' \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 ]//g; s/  */ /g; s/^ *//; s/ *$//' \
  | sort \
  | uniq -c \
  | awk '$1 >= 3 { count = $1; $1 = ""; sub(/^ */, ""); print count " : " $0 }' \
  | sort -rn \
  | head -20

echo ""
echo "=== summary ==="
echo "  duplicate H1 groups:    $dup_h1_count"
echo "  duplicate lead groups:  $dup_lead_count"
