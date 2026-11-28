#!/usr/bin/env bash
# check-declared-idioms.sh — every unit ai/declared-idioms.md lists is extracted into .claude/_extracted-idioms.md.
#
# THE LOOP THIS CLOSES. Phase 2.5 extracts an idiom only when three or more places depend on it.
# A unit built on purpose — the wrapper /unify-surfaces or /add-component made, the gate
# /add-feature added, the token source /polish introduced — starts with fewer, because the rows
# that halted for it are the ones that will use it. Every /setup-project run regenerated
# _extracted-idioms.md without it, and the command that had halted for it halted again on the
# same line. ai/declared-idioms.md is the list Phase 2.5 must always extract
# (templates/snippets/decide-before-change.md § 10); this check proves the run did.
#
# WHAT COUNTS AS KEPT — exact, never "the path is mentioned somewhere":
#   - a line that carries the marker `[declared: ai/declared-idioms.md]` and names the path as a
#     whole token (after `(`, a space, a backtick or the line start; before `)`, a space, a
#     backtick, `:`, `,` or the line end), or
#   - `declared but missing: <path>` (Phase 2.5 § Declared units) when the path is really absent
#     from the target.
# A path that survives only in a `[found: <path:line>]` provenance marker, or as a substring of
# another path, is a dropped row. Each of those passed an earlier draft of this check.
#
# Usage: check-declared-idioms.sh <target>
# Exit:  0 every declared row kept (or nothing declared) / 1 a row dropped or malformed / 2 usage
set -uo pipefail
export LC_ALL=C

TARGET="${1:-}"
if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "usage: check-declared-idioms.sh <target>" >&2
  exit 2
fi

DECL="$TARGET/ai/declared-idioms.md"
IDI="$TARGET/.claude/_extracted-idioms.md"
KINDS=" wrapper composable service base-class type-primitive tokens "

if [ ! -f "$DECL" ]; then
  echo "declared idioms: none (no ai/declared-idioms.md)"
  exit 0
fi

bad=0
# A row written as a bullet reads as no row at all, and the run would pass with it dropped.
while IFS= read -r l; do
  [ -z "$l" ] && continue
  echo "FAIL declared idiom not a table row: $l"
  bad=$((bad + 1))
done <<EOF
$(grep -E '^[[:space:]]*[-*][[:space:]]+`?(wrapper|composable|service|base-class|type-primitive|tokens)`?[[:space:]]*[|:—-]' "$DECL" || true)
EOF

# kind|path for every table row; the header (any case) and the separator are not rows. A `|`
# delimiter, never a tab: a tab is whitespace to `read`, so an empty kind collapsed into the path
# and the row was skipped as `0/0 kept`.
rows="$(awk -F'|' '/^[[:space:]]*\|/ {
  k = $2; p = $3
  gsub(/^[[:space:]`]+|[[:space:]`]+$/, "", k); gsub(/^[[:space:]`]+|[[:space:]`]+$/, "", p)
  if (p == "" || tolower(p) == "path" || p ~ /^:?-+:?$/) next
  print tolower(k) "|" p
}' "$DECL")"

if [ -z "$rows" ] && [ "$bad" -eq 0 ]; then
  echo "declared idioms: 0 rows"
  exit 0
fi

if [ ! -f "$IDI" ]; then
  n="$(printf '%s\n' "$rows" | grep -c . || true)"
  echo "FAIL declared idioms: $n row(s) in ai/declared-idioms.md, and .claude/_extracted-idioms.md is missing"
  exit 1
fi

# missing_line <path>: Phase 2.5's Strategy line, with or without its bullet.
missing_line() { grep -qxE -- "[[:space:]]*([-*][[:space:]]+)?declared but missing: $(printf '%s' "$1" | sed 's/[][\.*^$(){}+?|]/\\&/g')[[:space:]]*" "$IDI"; }

# kept <path>: a marker line naming the path as a whole token, or a true `declared but missing`.
kept() {
  local p="$1"
  if awk -v p="$p" '
    function whole(line, s,   i, rest, pre, post, off) {
      off = 0
      while ((i = index(substr(line, off + 1), s)) > 0) {
        i += off
        pre = (i == 1) ? "" : substr(line, i - 1, 1)
        post = substr(line, i + length(s), 1)
        if ((pre == "" || pre ~ /[( `]/) && (post == "" || post ~ /[) `:,]/)) return 1
        off = i
      }
      return 0
    }
    index($0, "[declared: ai/declared-idioms.md]") && whole($0, p) { found = 1; exit }
    END { exit found ? 0 : 1 }' "$IDI"; then
    return 0
  fi
  if missing_line "$p" && [ ! -e "$TARGET/$p" ]; then
    return 0
  fi
  return 1
}

n=0; miss=0
while IFS='|' read -r k p; do
  [ -z "$p" ] && continue
  n=$((n + 1))
  case "$KINDS" in
    *" $k "*) ;;
    *) echo "FAIL declared idiom has an unknown kind: '$k' for $p (kinds:$KINDS)"; bad=$((bad + 1)); continue ;;
  esac
  if ! kept "$p"; then
    if missing_line "$p"; then
      echo "FAIL declared idiom marked missing but on disk: $p"
    else
      echo "FAIL declared idiom dropped: $p (no line in .claude/_extracted-idioms.md carries it with [declared: ai/declared-idioms.md])"
    fi
    miss=$((miss + 1))
  fi
done <<EOF
$rows
EOF

if [ "$miss" -gt 0 ] || [ "$bad" -gt 0 ]; then
  echo "declared idioms: $miss of $n dropped, $bad malformed — Phase 2.5 must extract every declared row (phase-2-profile.md § Declared units)"
  exit 1
fi
echo "declared idioms: $n/$n kept"
exit 0
