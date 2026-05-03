#!/usr/bin/env bash
# _parallel-tool-config.sh — tool invocation map for parallel-fan-out.sh
#
# Sourced by parallel-fan-out.sh + migrate-parallel.sh + align-parallel.sh.
# To add a tool: append a function `tool_<name>_invoke` that takes one arg
# (the prompt text) and runs the tool in headless / non-interactive mode.
#
# The function MUST:
#   1. Take exactly one positional arg: the prompt string.
#   2. Block until the tool finishes (no detach / no & background).
#   3. Exit 0 on success, non-zero on failure (caller checks exit code).
#   4. Print tool stdout/stderr; the caller redirects per-worker.
#
# Verified flags as of 2026-05-03:
#   kimi      — `kimi --headless --prompt "<text>"`  (Moonshot docs)
#   aider     — `aider --message "<text>" --no-stream --yes`
#   opencode  — `opencode run "<text>"` (CLI runner; verify against installed version)
#   codex     — `codex exec "<text>"`   (OpenAI CLI; verify against installed version)
#   claude    — `claude --print "<text>"` (Claude Code headless print mode)
#
# Replace any flag the script gets wrong against your installed CLI version.

tool_kimi_invoke() {
  local prompt="$1"
  kimi --headless --prompt "$prompt"
}

tool_aider_invoke() {
  local prompt="$1"
  aider --message "$prompt" --no-stream --yes
}

tool_opencode_invoke() {
  local prompt="$1"
  opencode run "$prompt"
}

tool_codex_invoke() {
  local prompt="$1"
  codex exec "$prompt"
}

tool_claude_invoke() {
  local prompt="$1"
  claude --print "$prompt"
}

# Validate that a tool function exists for a given name.
# Returns 0 if `tool_<name>_invoke` is defined, 1 otherwise.
tool_is_supported() {
  local tool="$1"
  declare -F "tool_${tool}_invoke" > /dev/null
}
