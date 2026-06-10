#!/usr/bin/env bash
# Status line — keeps the #1 constraint (context usage) and session state visible.
# Claude Code feeds session JSON on stdin. Prints: dir • branch • model • context% • cost.
# Robust with or without jq.

set -uo pipefail
input=$(cat)

get() { # get <jq-path> <sed-key>
  if command -v jq >/dev/null 2>&1; then
    echo "$input" | jq -r "$1 // empty" 2>/dev/null
  else
    echo "$input" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
  fi
}
getnum() {
  if command -v jq >/dev/null 2>&1; then
    echo "$input" | jq -r "$1 // empty" 2>/dev/null
  else
    echo "$input" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p" | head -n1
  fi
}

cur_dir=$(get '.workspace.current_dir' 'current_dir')
[ -z "$cur_dir" ] && cur_dir="$PWD"
dir=$(basename "$cur_dir")
model=$(get '.model.display_name' 'display_name')
used=$(getnum '.context.used_tokens' 'used_tokens')
max=$(getnum '.context.max_tokens' 'max_tokens')
cost=$(getnum '.cost.total_cost_usd' 'total_cost_usd')

branch=""
if git -C "$cur_dir" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cur_dir" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch="detached"
fi

line="📁 $dir"
[ -n "$branch" ] && line="$line  ⎇ $branch"
[ -n "$model" ] && line="$line  🤖 $model"
if [ -n "$used" ] && [ -n "$max" ] && [ "$max" != "0" ]; then
  pct=$(awk -v u="$used" -v m="$max" 'BEGIN{printf "%d", (u/m)*100}')
  line="$line  🧠 ${pct}%"
fi
[ -n "$cost" ] && line="$line  💲$(awk -v c="$cost" 'BEGIN{printf "%.2f", c}')"

echo "$line"
