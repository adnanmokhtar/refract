#!/usr/bin/env bash
# Workspace-level SessionStart — briefing across all sibling repos.

set -uo pipefail

workspace_root=$(cd "$(dirname "$0")/../.." && pwd)
echo "=== Workspace: $(basename "$workspace_root") ==="

if [ -f "$workspace_root/PROJECTS.md" ]; then
  echo ""
  echo "--- Registered repos ---"
  grep -E '^\| `' "$workspace_root/PROJECTS.md" 2>/dev/null | head -20 || head -20 "$workspace_root/PROJECTS.md"
fi

echo ""
echo "--- Per-repo status ---"
for dir in "$workspace_root"/*/; do
  repo=$(basename "$dir")
  [ "$repo" = ".claude" ] && continue
  [ "$repo" = "ai" ] && continue
  [ ! -d "$dir/.git" ] && continue

  branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "-")
  uncommitted=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  printf "  %-28s branch=%s  uncommitted=%s\n" "$repo" "$branch" "$uncommitted"
done

echo ""
