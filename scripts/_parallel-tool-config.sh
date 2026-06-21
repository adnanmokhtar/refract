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
#   qwen      — `qwen -p "<text>" --print` (Qwen Code; -p alias --prompt)
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

tool_qwen_invoke() {
  local prompt="$1"
  qwen -p "$prompt" --print
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

# ledger_extract_rows <ledger-path> <comma-separated-states>
#
# Shared canonical ledger-row parser for the *-parallel.sh fan-out drivers.
# Prints (one per line, to stdout) the id of every ledger row whose status:/state:
# matches one of the requested states.
#
# Canonical format = fenced-YAML, indented YAML-list rows (per migration-ledger.md):
#
#   ```yaml
#   - id: F001
#     status: V1-only        # or `state:` — either key accepted
#     dependencies: [...]
#   ```
#
# Also tolerates the flush-left variant (`id: ALIGN-0042` / `status: detected`
# with no leading indent) so non-fenced ledgers still parse. Ids are generic
# (`F001`, `ALIGN-0042`, `POLISH-7`); the `- ` list prefix and any indentation
# are optional. `status:` wins over `state:` when both appear in a row. A row is
# closed by the next id line, a fence (```), or EOF.
#
# bash-3.2 / BSD-awk safe: no gensub, no 3-arg match, no length-of-array tricks.
ledger_extract_rows() {
  local ledger="$1" states="$2"
  awk -v states="$states" '
    function emit() {
      if (id != "" && st != "" && (st in want)) print id
    }
    BEGIN {
      n = split(states, arr, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", arr[i])
        want[arr[i]] = 1
      }
    }
    /^[[:space:]]*(- )?id:[[:space:]]+[A-Za-z0-9][A-Za-z0-9_.-]*[[:space:]]*$/ {
      if (id != "") emit()
      id = $0
      sub(/^[[:space:]]*(- )?id:[[:space:]]*/, "", id)
      sub(/[[:space:]]+$/, "", id)
      st = ""
      in_block = 1
      next
    }
    /^```/ {
      if (in_block) emit()
      id = ""
      st = ""
      in_block = 0
      next
    }
    in_block && /^[[:space:]]*status:[[:space:]]/ {
      st = $0; sub(/^[[:space:]]*status:[[:space:]]*/, "", st); gsub(/^[[:space:]]+|[[:space:]]+$/, "", st); next
    }
    in_block && /^[[:space:]]*state:[[:space:]]/ {
      if (st == "") { st = $0; sub(/^[[:space:]]*state:[[:space:]]*/, "", st); gsub(/^[[:space:]]+|[[:space:]]+$/, "", st) }
      next
    }
    END { if (id != "") emit() }
  ' "$ledger"
}
