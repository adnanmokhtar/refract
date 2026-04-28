#!/usr/bin/env bash
# post-merge-learn.sh — runs after `git merge` (including merge from pull/fetch)
# Same intent as post-commit-learn but scans the entire merged range, not just one commit.

set -uo pipefail

DYNAMIC_DIR="ai/dynamic"
[ ! -d "$DYNAMIC_DIR" ] && exit 0

CHANGELOG="$DYNAMIC_DIR/changelog.md"
QUEUE_FILE="$DYNAMIC_DIR/.review-queue"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# `git merge` invokes this hook; ORIG_HEAD is the previous HEAD before the merge.
PREV=$(git rev-parse ORIG_HEAD 2>/dev/null || echo "HEAD~1")
NEW=$(git rev-parse HEAD)
COMMIT_DATE=$(date '+%Y-%m-%d %H:%M')

# How many files in the merged range?
FILES_CHANGED=$(git diff --name-only "$PREV" "$NEW" 2>/dev/null | wc -l | tr -d ' ')

if [ "$FILES_CHANGED" = "0" ]; then
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

# Append a merge entry to the changelog
{
  echo ""
  echo "### $COMMIT_DATE — MERGE → $BRANCH"
  echo "Range: $PREV..$NEW"
  echo "Files: $FILES_CHANGED"
  git diff --name-only "$PREV" "$NEW" 2>/dev/null | head -10 | sed 's/^/  - /'
  [ "$FILES_CHANGED" -gt 10 ] && echo "  (+ $(( FILES_CHANGED - 10 )) more)"
} >> "$CHANGELOG"

# Always queue a pattern-emergence review on merges (they often introduce shape repetition)
echo "$NEW | pattern-emergence-watcher | merge ($FILES_CHANGED files)" >> "$QUEUE_FILE"

# Queue a refresh hint if the merge is large
if [ "$FILES_CHANGED" -gt 30 ]; then
  echo "$NEW | knowledge-curator | recommend-refresh-knowledge (merge of $FILES_CHANGED files — profile may have shifted)" >> "$QUEUE_FILE"
fi

exit 0
