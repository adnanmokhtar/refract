#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit) — auto-formats the edited file.
# Stack-agnostic: detects the project's formatter and runs it on the touched file.
# Always exits 0 — formatting must never block the agent (lint gating lives in post-edit-check.sh).
#
# Opt out per project: create .claude/.no-format

set -uo pipefail

[ -f ".claude/.no-format" ] && exit 0

payload=$(cat)
file_path=$(echo "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

run() { "$@" >/dev/null 2>&1 || true; }   # never fail the hook

case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.html|*.vue|*.svelte)
    if command -v biome >/dev/null 2>&1 && [ -f "biome.json" ]; then
      run biome format --write "$file_path"
    elif command -v prettier >/dev/null 2>&1; then
      run prettier --write "$file_path"
    elif command -v npx >/dev/null 2>&1 && [ -f "package.json" ]; then
      run npx --no-install prettier --write "$file_path"
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      run ruff format "$file_path"
    elif command -v black >/dev/null 2>&1; then
      run black -q "$file_path"
    fi
    ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && run gofmt -w "$file_path"
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && run rustfmt "$file_path"
    ;;
  *.rb)
    command -v rubocop >/dev/null 2>&1 && run rubocop -A "$file_path"
    ;;
esac

exit 0
