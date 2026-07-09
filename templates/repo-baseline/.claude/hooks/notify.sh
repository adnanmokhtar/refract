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

if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$message" 2>/dev/null
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; \$n.ShowBalloonTip(5000, '$title', '$message', 'Info')" 2>/dev/null
fi
exit 0
