#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit) — blocks writes to sensitive, generated,
# or non-hand-editable files. Exit 2 = block. Exit 0 = allow.
#
# Opt out per project: create .claude/.no-pre-edit-guard

set -uo pipefail

[ -f ".claude/.no-pre-edit-guard" ] && exit 0

payload=$(cat)
if command -v jq >/dev/null 2>&1; then
  file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  file_path=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi
[ -z "$file_path" ] && exit 0

base=$(basename -- "$file_path")

block() {
  echo "Blocked by pre-edit-guard: $1" >&2
  exit 2
}

# ── Secrets, credentials, certificates, keys ────────────────────────────
case "$base" in
  .env|.env.*|*.pem|*.key|*.crt|*.p12|*.pfx|id_rsa|id_ed25519|credentials.json|.npmrc|.pypirc)
    block "editing a secret/credential/key file ($file_path) — ask the user first" ;;
esac
case "$file_path" in
  *.env|*/.env|*/.env.*|*/secrets/*|secrets/*)
    block "editing a secret file ($file_path) — ask the user first" ;;
  */.git/*|.git/*)
    block "editing files inside .git/ ($file_path)" ;;
esac

# ── Self-protection: hooks + settings that enforce boundaries ───────────
case "$file_path" in
  */.claude/hooks/*|.claude/hooks/*)
    block "editing hook scripts ($file_path) — these enforce safety boundaries; edit them in the source repo" ;;
esac

# ── Generated / minified code (regenerate from source, don't hand-edit) ─
case "$base" in
  *.gen.ts|*.generated.*|*.min.js|*.min.css)
    block "editing generated/minified output ($file_path) — change the source instead" ;;
esac

# ── Build output & dependency directories ───────────────────────────────
case "$file_path" in
  */node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/.next/*|*/.nuxt/*|*/target/*|*/__pycache__/*|*/.venv/*|venv/*|*/venv/*)
    block "editing build output or dependencies ($file_path)" ;;
esac

# ── Lock files (mutate via the package manager) ─────────────────────────
case "$base" in
  package-lock.json|bun.lockb|yarn.lock|pnpm-lock.yaml|Cargo.lock|poetry.lock|uv.lock)
    block "editing a lock file directly ($file_path) — use the package manager" ;;
esac

# ── Binary / archive / media (should be compiled or added outside the agent)
case "$base" in
  *.wasm|*.so|*.dylib|*.dll|*.exe|*.o|*.a|*.pyc|*.pyo|*.class)
    block "writing a binary/compiled file ($file_path) — these are built, not hand-written" ;;
  *.zip|*.tar|*.tar.gz|*.tar.bz2|*.tgz|*.rar|*.7z)
    block "writing an archive file ($file_path)" ;;
  *.mp4|*.mov|*.avi|*.mkv|*.mp3|*.wav|*.flac)
    block "writing a media file ($file_path) — add these outside the agent" ;;
esac

exit 0
