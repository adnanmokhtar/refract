#!/usr/bin/env bash
# PreToolUse hook — blocks writes to sensitive files.

set -uo pipefail

payload=$(cat)
file_path=$(echo "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

[ -z "$file_path" ] && exit 0

block() {
  echo "Blocked by pre-edit-guard: $1" >&2
  exit 2
}

case "$file_path" in
  *.env|*.env.*|*/.env|*/.env.*)
    block "editing .env file ($file_path) — ask the user first"
    ;;
  */node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/.next/*|*/.nuxt/*|*/target/*|*/__pycache__/*)
    block "editing build output or dependencies ($file_path)"
    ;;
  *package-lock.json|*bun.lockb|*yarn.lock|*pnpm-lock.yaml|*Cargo.lock|*poetry.lock|*uv.lock)
    block "editing lock file directly ($file_path) — use the package manager"
    ;;
esac

exit 0
