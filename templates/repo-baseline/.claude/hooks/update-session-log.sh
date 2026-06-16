#!/usr/bin/env bash
# Stop hook — appends a brief session summary to ai/dynamic/session-log.md.
# Enables cross-session continuity: next session reads recent context without full git log.
#
# CONTRACT: ai/dynamic/session-log.md MUST be .gitignored (setup-project Phase 4.1
# enforces it). A hook that writes a TRACKED file leaves the tree perpetually dirty.

set -uo pipefail

LOG_FILE="ai/dynamic/session-log.md"
[ ! -d "ai/dynamic" ] && mkdir -p "ai/dynamic"

# Only log if there's something meaningful (branch OR modified files)
if git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  CHANGED_FILES=$(git diff --name-only 2>/dev/null | head -8)
  CHANGED_COUNT=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  UNTRACKED=$(git status -s 2>/dev/null | grep '^??' | head -3 | wc -l | tr -d ' ')
else
  BRANCH="(no git)"
  CHANGED_FILES=""
  CHANGED_COUNT=0
  UNTRACKED=0
fi

# Only append if there were changes (skip noisy no-op logging)
if [ "$CHANGED_COUNT" = "0" ] && [ "$UNTRACKED" = "0" ]; then
  exit 0
fi

TS=$(date '+%Y-%m-%d %H:%M')

{
  echo ""
  echo "## $TS"
  echo "Branch: $BRANCH"
  echo "Changed files ($CHANGED_COUNT):"
  if [ -n "$CHANGED_FILES" ]; then
    echo "$CHANGED_FILES" | sed 's/^/  - /'
  fi
  [ "$CHANGED_COUNT" -gt 8 ] && echo "  (+ $(( CHANGED_COUNT - 8 )) more)"
  [ "$UNTRACKED" -gt 0 ] && echo "Untracked: $UNTRACKED file(s)"
} >> "$LOG_FILE"
