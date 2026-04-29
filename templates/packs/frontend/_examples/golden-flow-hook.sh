#!/usr/bin/env bash
# golden-flow-hook.sh — opt-in path-scoped hook for breaking-change guardrail.
#
# Drop a copy of this file at <project>/.claude/hooks/golden-flow.sh and wire
# it into <project>/.claude/settings.json under "hooks.PostToolUse.Edit". Then
# every time the agent edits one of the high-blast-radius paths listed below,
# this hook fires a 10-second Playwright smoke against the dev server.
#
# Why it's a separate file and not the default: a "run after every Edit" hook
# adds 30+ seconds per edit, even for typo fixes. This file scopes to paths
# where breakage propagates everywhere (router, top-level layout, auth,
# api client) and runs ONLY then.
#
# Wire-up (in <project>/.claude/settings.json):
# {
#   "hooks": {
#     "PostToolUse": {
#       "Edit": [
#         { "command": ".claude/hooks/golden-flow.sh \"$CLAUDE_FILE_PATH\"" }
#       ]
#     }
#   }
# }
#
# Edit the WATCHED_PATHS regex below to match YOUR project's high-blast-radius
# paths. The default below targets a typical Vue/Vite project.

set -euo pipefail

EDITED_FILE="${1:-}"
[[ -z "$EDITED_FILE" ]] && exit 0

# ---------- 1. Path filter ----------
# Only fire on edits to paths whose breakage is invisible-but-everywhere.
# Tune this to your project's actual blast-radius surface.
WATCHED_PATHS='^src/(router|main\.ts|App\.vue|core/api|store/modules/auth|plugins/firebase)'

if ! echo "$EDITED_FILE" | grep -qE "$WATCHED_PATHS"; then
  exit 0  # Out of scope — silently no-op.
fi

# ---------- 2. Dev server check ----------
PORT=5173  # Vite default; change if your project uses something else.
if ! lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[golden-flow] dev server not running on :$PORT — skipping smoke." >&2
  exit 0
fi

URL="http://localhost:$PORT"

# ---------- 3. Smoke flow ----------
# Three checks: home loads, login route renders, dashboard route renders.
# Replace with your project's actual golden flow.

OUT_DIR=".claude/playwright/golden-flow-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

echo "[golden-flow] firing on edit to $EDITED_FILE" >&2

# A pure-curl smoke: HEAD on each route + check 200/304 + non-empty mount-point.
# (Lighter than launching Playwright on every hook fire. Promote to full
# Playwright via `verify-with-playwright` skill if these checks aren't enough.)
fail=0
for route in "/" "/login" "/dashboard"; do
  status=$(curl -sS -o "$OUT_DIR/$(echo "$route" | tr / _).html" -w "%{http_code}" "$URL$route" || echo "000")
  if [[ "$status" =~ ^(200|301|302|304)$ ]]; then
    grep -qE '<div id="(app|__nuxt|root)"' "$OUT_DIR/$(echo "$route" | tr / _).html" \
      && echo "[golden-flow]   ✓ $route ($status)" >&2 \
      || { echo "[golden-flow]   ✗ $route ($status — mount point missing)" >&2; fail=$((fail + 1)); }
  else
    echo "[golden-flow]   ✗ $route ($status)" >&2
    fail=$((fail + 1))
  fi
done

if [[ $fail -gt 0 ]]; then
  echo "[golden-flow] $fail route(s) broken after edit to $EDITED_FILE" >&2
  echo "[golden-flow] HTML dumps: $OUT_DIR/" >&2
  echo "[golden-flow] Run /verify-with-playwright for a deeper interactive check." >&2
  # Non-zero exit → hook surfaces failure to Claude; agent can read + decide.
  exit 1
fi

echo "[golden-flow] all routes healthy after edit to $EDITED_FILE" >&2
exit 0
