#!/usr/bin/env bash
# PreToolUse hook for Bash — blocks destructive commands.

set -uo pipefail

payload=$(cat)
cmd=$(echo "$payload" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

[ -z "$cmd" ] && exit 0

block() {
  echo "Blocked by guard-destructive: $1" >&2
  echo "If you really need this, run it yourself in your own terminal." >&2
  exit 2
}

case "$cmd" in
  *"rm -rf /"*|*"rm -fr /"*) block "rm -rf on root path" ;;
  *"git push --force"*|*"git push -f "*) block "force push — run manually if intended" ;;
  *"git reset --hard"*) block "hard reset destroys work — run manually if intended" ;;
  *"git clean -fd"*) block "git clean -fd wipes untracked files" ;;
  *"git branch -D"*) block "force branch delete" ;;
  *":(){ :|:& };:"*) block "fork bomb" ;;
esac

exit 0
