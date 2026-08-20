#!/usr/bin/env bash
# Stop hook — appends a brief session summary to ai/dynamic/session-log.md.
# Enables cross-session continuity: next session reads recent context without full git log.
#
# CONTRACT: ai/dynamic/session-log.md MUST be .gitignored (setup-project Phase 4.1
# enforces it). A hook that writes a TRACKED file leaves the tree perpetually dirty.
#
# It also records a POINTER at the harness's own verbatim transcript (`session_id` +
# `transcript_path` from the Stop payload). The transcript is NOT copied — the host
# already stores every session as JSONL under `~/.claude/projects/<encoded>/`, and
# duplicating it into the repo would be a secret-leak surface `secret-scan.sh` never
# sees, because a hook write is not an Edit. A path is not content.
#
# The first user prompt (truncated) is CONTENT, so it is written only when the project
# has opted in with `.claude/.recall` — the same marker that arms `recall-inject.sh`.
# Without stdin, without jq, or without the payload fields, this hook behaves exactly
# as it did before: branch + changed files, nothing else.

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

# Session pointers from the Stop payload. `[ -t 0 ]` guards a manual run: without it a
# bare `cat` would block forever on a terminal.
SESSION_ID=""
TRANSCRIPT=""
FIRST_PROMPT=""
if [ ! -t 0 ] && command -v jq >/dev/null 2>&1; then
  PAYLOAD=$(cat 2>/dev/null || true)
  if [ -n "$PAYLOAD" ]; then
    SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null || true)
    TRANSCRIPT=$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null || true)
    # Content — opt-in only, and capped hard at 120 chars.
    if [ -f ".claude/.recall" ] && [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
      FIRST_PROMPT=$(head -200 "$TRANSCRIPT" 2>/dev/null \
        | jq -r 'select(.type=="user") | .message.content
                 | if type=="string" then .
                   elif type=="array" then (map(select(.type=="text").text) | join(" "))
                   else empty end' 2>/dev/null \
        | grep -v '^[[:space:]]*$' | head -1 | tr '\n' ' ' | cut -c1-120 || true)
    fi
  fi
fi

TS=$(date '+%Y-%m-%d %H:%M')

{
  echo ""
  echo "## $TS"
  echo "Branch: $BRANCH"
  [ -n "$SESSION_ID" ] && echo "Session: $SESSION_ID"
  [ -n "$TRANSCRIPT" ] && echo "Transcript: $TRANSCRIPT"
  [ -n "$FIRST_PROMPT" ] && echo "Opened with: $FIRST_PROMPT"
  echo "Changed files ($CHANGED_COUNT):"
  if [ -n "$CHANGED_FILES" ]; then
    echo "$CHANGED_FILES" | sed 's/^/  - /'
  fi
  [ "$CHANGED_COUNT" -gt 8 ] && echo "  (+ $(( CHANGED_COUNT - 8 )) more)"
  [ "$UNTRACKED" -gt 0 ] && echo "Untracked: $UNTRACKED file(s)"
} >> "$LOG_FILE"

exit 0
