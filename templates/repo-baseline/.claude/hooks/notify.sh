#!/usr/bin/env bash
# Notification hook — native OS notification when Claude needs your attention.
# macOS (osascript), Linux (notify-send), WSL (PowerShell toast). Silent exit
# when no notifier exists. Set CLAUDE_NOTIFY_DRYRUN=1 to print instead (tests).

set -uo pipefail

payload=$(cat 2>/dev/null || true)

message="Claude Code needs your attention"
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  msg=$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null || true)
  [ -n "$msg" ] && message="$msg"
fi
title="Claude Code"

if [ "${CLAUDE_NOTIFY_DRYRUN:-0}" = "1" ]; then
  echo "notify: $title: $message"
  exit 0
fi

# The message comes from the hook payload. Interpolating it into a script STRING is code
# injection, not a formatting detail: a `"` closes the AppleScript literal and
# `" & (do shell script "…") & "` runs whatever follows. Verified — a crafted message wrote a file.
# Every notifier below therefore receives the text as an ARGUMENT, never as script source.
if command -v osascript >/dev/null 2>&1; then
  # `on run argv` keeps the text out of the script body entirely.
  osascript -e 'on run argv' \
            -e 'display notification (item 1 of argv) with title (item 2 of argv)' \
            -e 'end run' -- "$message" "$title" 2>/dev/null
elif command -v notify-send >/dev/null 2>&1; then
  # `--` so a message beginning with `-` is text, not a flag.
  notify-send -- "$title" "$message" 2>/dev/null
elif command -v powershell.exe >/dev/null 2>&1; then
  # PowerShell single-quoted strings escape a quote by doubling it. Without this a `'` in the
  # message closes the literal the same way the AppleScript one did.
  ps_title=$(printf '%s' "$title"   | sed "s/'/''/g")
  ps_msg=$(printf '%s' "$message" | sed "s/'/''/g")
  powershell.exe -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; \$n.ShowBalloonTip(5000, '$ps_title', '$ps_msg', 'Info')" 2>/dev/null
fi
exit 0
