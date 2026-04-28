#!/usr/bin/env bash
# Workspace-level PostToolUse dispatcher.
# Routes Edit/Write/MultiEdit events to the owning sibling repo's post-edit-check.sh.

set -uo pipefail

payload=$(cat)
file_path=$(echo "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

[ -z "$file_path" ] && exit 0

# Find the longest-matching sibling repo that contains this file.
workspace_root=$(cd "$(dirname "$0")/../.." && pwd)

best_match=""
for dir in "$workspace_root"/*/; do
  repo=$(basename "$dir")
  # skip workspace's own .claude
  [ "$repo" = ".claude" ] && continue
  [ "$repo" = "ai" ] && continue
  if [[ "$file_path" == "$workspace_root/$repo"* ]]; then
    if [ -z "$best_match" ] || [ ${#repo} -gt ${#best_match} ]; then
      best_match="$repo"
    fi
  fi
done

[ -z "$best_match" ] && exit 0

hook="$workspace_root/$best_match/.claude/hooks/post-edit-check.sh"
if [ -x "$hook" ]; then
  echo "$payload" | "$hook"
fi
