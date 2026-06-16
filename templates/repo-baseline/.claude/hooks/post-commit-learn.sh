#!/usr/bin/env bash
# post-commit-learn.sh — runs after each git commit
# Scans the commit's diff for learnable signals; queues findings for the next session
# to surface (does NOT block the commit; learning is async).
#
# CONTRACT: the files this writes (ai/dynamic/changelog.md, ai/dynamic/.review-queue)
# MUST be .gitignored. A post-commit hook that writes a TRACKED file makes a clean
# working tree impossible (commit -> this appends -> dirty -> commit -> ...).
# setup-project Phase 4.1 enforces those .gitignore entries.

set -uo pipefail

DYNAMIC_DIR="ai/dynamic"
[ ! -d "$DYNAMIC_DIR" ] && exit 0   # Project not yet using the learning system.

CHANGELOG="$DYNAMIC_DIR/changelog.md"

# Get the just-made commit info
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

COMMIT_HASH=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --pretty=%s)
COMMIT_DATE=$(git log -1 --pretty=%cd --date=format:'%Y-%m-%d %H:%M')
FILES_CHANGED=$(git diff-tree --no-commit-id --name-only -r HEAD | wc -l | tr -d ' ')

# Skip merge commits + commits with no file changes (defensive)
if [ "$FILES_CHANGED" = "0" ]; then
  exit 0
fi

# Append to changelog
{
  echo ""
  echo "### $COMMIT_DATE — $COMMIT_HASH — $COMMIT_MSG"
  echo "Files: $FILES_CHANGED"
  git diff-tree --no-commit-id --name-only -r HEAD | head -10 | sed 's/^/  - /'
  [ "$FILES_CHANGED" -gt 10 ] && echo "  (+ $(( FILES_CHANGED - 10 )) more)"
} >> "$CHANGELOG"

# If commit is large (>5 files) or touches many modules, queue a pattern-emergence review
QUEUE_FILE="$DYNAMIC_DIR/.review-queue"
if [ "$FILES_CHANGED" -gt 5 ]; then
  echo "$COMMIT_HASH | pattern-emergence-watcher | large-commit ($FILES_CHANGED files)" >> "$QUEUE_FILE"
fi

# Detect potential new entities by scanning for new class/interface declarations in TS/JS
NEW_ENTITIES=$(git diff HEAD~1 HEAD -- '*.ts' '*.tsx' '*.js' 2>/dev/null \
  | grep -E '^\+(export )?(class|interface|type|enum) [A-Z][a-zA-Z]+' \
  | grep -oE '(class|interface|type|enum) [A-Z][a-zA-Z]+' \
  | awk '{print $2}' \
  | sort -u)

if [ -n "$NEW_ENTITIES" ]; then
  echo "$COMMIT_HASH | knowledge-curator | new-entities ($(echo "$NEW_ENTITIES" | tr '\n' ',' | sed 's/,$//'))" >> "$QUEUE_FILE"
fi

# Detect potential convention drift: console.log added, any type added, swallowed errors
DRIFT_HINTS=""
if git diff HEAD~1 HEAD -- '*.ts' '*.tsx' '*.js' 2>/dev/null | grep -qE '^\+.*console\.log'; then
  DRIFT_HINTS="$DRIFT_HINTS console.log-added"
fi
if git diff HEAD~1 HEAD -- '*.ts' '*.tsx' 2>/dev/null | grep -qE '^\+.*: any\b'; then
  DRIFT_HINTS="$DRIFT_HINTS any-type-added"
fi
if git diff HEAD~1 HEAD -- '*.ts' '*.tsx' '*.js' 2>/dev/null | grep -qE '^\+.*catch.*\{[^}]*\}' | head; then
  DRIFT_HINTS="$DRIFT_HINTS swallowed-catch"
fi

if [ -n "$DRIFT_HINTS" ]; then
  echo "$COMMIT_HASH | convention-drift-detector |$DRIFT_HINTS" >> "$QUEUE_FILE"
fi

# Detect new dependencies (package.json change)
if git diff HEAD~1 HEAD -- package.json 2>/dev/null | grep -qE '^\+\s*"[^"]+":\s*"\^?[0-9]'; then
  NEW_DEPS=$(git diff HEAD~1 HEAD -- package.json 2>/dev/null \
    | grep -E '^\+\s*"[^"]+":\s*"\^?[0-9]' \
    | grep -oE '"[^"]+":' \
    | tr -d '":' \
    | head -5 \
    | tr '\n' ',' | sed 's/,$//')
  echo "$COMMIT_HASH | knowledge-curator | new-deps ($NEW_DEPS)" >> "$QUEUE_FILE"
fi

# Always exit 0 — learning is best-effort, never blocks commits
exit 0
