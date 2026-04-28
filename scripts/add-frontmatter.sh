#!/usr/bin/env bash
# add-frontmatter.sh — add minimal YAML frontmatter to rule + pattern files that lack it.
#
# Reads each .md under templates/packs/<pack>/{rules,ai-patterns}/ and
# templates/repo-baseline + templates/workspace-baseline + templates/tracks.
# If the file does NOT start with `---`, prepends a frontmatter block with:
#   name: <derived-from-filename>
#   description: <derived-from-h1>
#   kind: rule | ai-pattern (per directory)
#   pack: <pack-name when under packs/>
#
# Idempotent — files that already have frontmatter are skipped.
# --apply to write; default is dry-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

added=0
skipped=0

process_one() {
  local file="$1"
  local rel; rel="${file#$REPO_ROOT/}"

  # Already has frontmatter?
  if head -1 "$file" | grep -q '^---'; then
    skipped=$((skipped + 1))
    return
  fi

  # Derive kind from the directory path
  local kind
  case "$file" in
    */rules/*)        kind=rule ;;
    */ai-patterns/*)  kind=ai-pattern ;;
    */patterns/*)     kind=ai-pattern ;;
    *)                kind=note ;;
  esac

  # Derive pack name (if under packs/)
  local pack=""
  if [[ "$file" == *"/packs/"* ]]; then
    pack="$(echo "$file" | sed -E 's|.*/packs/([^/]+)/.*|\1|')"
  fi

  # Derive name from filename
  local name; name="$(basename "$file" .md)"

  # Derive description from first H1 line. Tolerate no-match (grep returns 1).
  local h1
  h1="$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' | head -1 || true)"
  if [[ -z "$h1" ]]; then
    # Fall back to first H2 line
    h1="$(grep -m1 '^## ' "$file" 2>/dev/null | sed 's/^## //' | head -1 || true)"
  fi
  [[ -z "$h1" ]] && h1="$name"

  local fm
  fm="---
name: $name
description: $h1
kind: $kind"
  [[ -n "$pack" ]] && fm="$fm
pack: $pack"
  fm="$fm
---

"

  if [[ "$APPLY" -eq 1 ]]; then
    local tmp; tmp="$(mktemp)"
    printf '%s' "$fm" > "$tmp"
    cat "$file" >> "$tmp"
    mv "$tmp" "$file"
    echo "  added  $rel"
  else
    echo "  would-add  $rel  (name=$name, kind=$kind, pack=$pack)"
  fi
  added=$((added + 1))
}

while IFS= read -r f; do
  process_one "$f"
done < <(find "$REPO_ROOT/templates" -type f -name '*.md' \
    \( -path '*/rules/*' -o -path '*/ai-patterns/*' -o -path '*/patterns/*' \) \
    | sort)

echo ""
echo "summary: $added added (or would-add) / $skipped already-ok"
[[ "$APPLY" -eq 0 ]] && echo "(dry run — pass --apply to write)"
