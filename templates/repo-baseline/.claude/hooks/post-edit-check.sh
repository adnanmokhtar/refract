#!/usr/bin/env bash
# PostToolUse hook — runs lint/type-check scoped to the edited file.
# Customize LINT_CMD below for your stack.

set -uo pipefail

# Read hook payload from stdin (Claude Code passes JSON)
payload=$(cat)
file_path=$(echo "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

# Only check source files — adjust extensions to taste
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    if command -v bun >/dev/null 2>&1 && [ -f "package.json" ]; then
      bun run lint "$file_path" 2>&1 || exit 2
    elif command -v npx >/dev/null 2>&1 && [ -f "package.json" ]; then
      npx eslint "$file_path" 2>&1 || exit 2
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff check "$file_path" 2>&1 || exit 2
    fi
    ;;
  *.go)
    if command -v golangci-lint >/dev/null 2>&1; then
      golangci-lint run "$file_path" 2>&1 || exit 2
    fi
    ;;
  *.rs)
    # cargo check runs on the whole crate; skipping per-file
    ;;
esac

exit 0
