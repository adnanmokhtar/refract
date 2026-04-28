#!/usr/bin/env bash
# verify-sync.sh — confirm ~/.claude entries are symlinks pointing back to this repo.
#
# Exit codes: 0 ok / 1 drift detected
#
# Drift = any expected entry under ~/.claude that is missing, is a real file
# instead of a symlink, or points somewhere other than this repo. Catches
# accidental edits made directly in ~/.claude that would otherwise be lost.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="${CLAUDE_HOME:-$HOME/.claude}"

SYNC_MAP=(
  "commands:commands"
  "templates:templates"
  "scripts:scripts"
)

drift=0
ok=0

check_child() {
  local src_path="$1"
  local dst_path="$2"

  if [[ ! -e "$dst_path" && ! -L "$dst_path" ]]; then
    echo "MISS  $dst_path (expected symlink to $src_path)"
    drift=1
    return
  fi

  if [[ ! -L "$dst_path" ]]; then
    echo "REAL  $dst_path is a real file/dir, not a symlink"
    drift=1
    return
  fi

  local current; current="$(readlink "$dst_path")"
  if [[ "$current" != "$src_path" ]]; then
    echo "WRONG $dst_path -> $current (expected $src_path)"
    drift=1
    return
  fi

  ok=$((ok + 1))
}

for entry in "${SYNC_MAP[@]}"; do
  src_rel="${entry%%:*}"
  dst_rel="${entry##*:}"
  src_dir="$REPO_ROOT/$src_rel"
  dst_dir="$TARGET_ROOT/$dst_rel"

  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    name="$(basename "$child")"
    [[ "$name" == ".gitkeep" ]] && continue
    [[ "$name" == ".DS_Store" ]] && continue
    check_child "$child" "$dst_dir/$name"
  done < <(find "$src_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) | sort)
done

echo ""
echo "verified: $ok ok, $drift drift"
exit "$drift"
