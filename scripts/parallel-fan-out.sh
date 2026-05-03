#!/usr/bin/env bash
# parallel-fan-out.sh — generic parallel CLI dispatcher for AI tool runners.
#
# Fans out N parallel headless CLI invocations of a chosen tool, one per task
# read from a task file. Each invocation gets the prompt template with
# `{{TASK}}` substituted by the line content.
#
# Use case: tools without native parallel sub-agent dispatch (Kimi, Aider,
# Codex, etc.) need external fan-out to match Claude Code's whole-project
# sweep speed. This script provides that.
#
# Usage:
#   parallel-fan-out.sh \
#     --tool=<kimi|qwen|aider|opencode|codex|claude> \
#     --parallel=<N> \
#     --task-file=<path> \
#     --prompt-template="<text with {{TASK}} placeholder>" \
#     [--log-dir=<path>] \
#     [--dry-run]
#
# Example:
#   echo "orders\nproducts\ncategories" > /tmp/features.txt
#   ./parallel-fan-out.sh \
#     --tool=kimi \
#     --parallel=6 \
#     --task-file=/tmp/features.txt \
#     --prompt-template='Run /find-and-fix {{TASK}} per migration-discipline.md'
#
# Exit codes:
#   0 — all workers exited 0
#   1 — at least one worker failed (failed-task list printed at end)
#   2 — invocation error (bad args, unsupported tool, missing files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./_parallel-tool-config.sh
source "$SCRIPT_DIR/_parallel-tool-config.sh"

# ---- argument parsing ----

TOOL=""
PARALLEL=""
TASK_FILE=""
PROMPT_TEMPLATE=""
LOG_DIR=""
DRY_RUN=0

usage() {
  sed -n '2,30p' "$0"
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --tool=*)             TOOL="${arg#*=}" ;;
    --parallel=*)         PARALLEL="${arg#*=}" ;;
    --task-file=*)        TASK_FILE="${arg#*=}" ;;
    --prompt-template=*)  PROMPT_TEMPLATE="${arg#*=}" ;;
    --log-dir=*)          LOG_DIR="${arg#*=}" ;;
    --dry-run)            DRY_RUN=1 ;;
    -h|--help)            usage ;;
    *) echo "ERR: unknown arg: $arg" >&2; usage ;;
  esac
done

[[ -z "$TOOL"            ]] && { echo "ERR: --tool required"            >&2; exit 2; }
[[ -z "$PARALLEL"        ]] && { echo "ERR: --parallel required"        >&2; exit 2; }
[[ -z "$TASK_FILE"       ]] && { echo "ERR: --task-file required"       >&2; exit 2; }
[[ -z "$PROMPT_TEMPLATE" ]] && { echo "ERR: --prompt-template required" >&2; exit 2; }

if ! [[ "$PARALLEL" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERR: --parallel must be a positive integer; got '$PARALLEL'" >&2; exit 2
fi

if ! tool_is_supported "$TOOL"; then
  echo "ERR: tool '$TOOL' is not in _parallel-tool-config.sh; add tool_${TOOL}_invoke" >&2
  exit 2
fi

if [[ ! -f "$TASK_FILE" ]]; then
  echo "ERR: task file does not exist: $TASK_FILE" >&2; exit 2
fi

if [[ "$PROMPT_TEMPLATE" != *'{{TASK}}'* ]]; then
  echo "ERR: --prompt-template must contain {{TASK}} placeholder" >&2; exit 2
fi

LOG_DIR="${LOG_DIR:-ai/_parallel-runs/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOG_DIR"

# ---- preview / dry-run ----

TASK_COUNT=$(grep -cve '^[[:space:]]*$' "$TASK_FILE" || true)
if [[ "$TASK_COUNT" -eq 0 ]]; then
  echo "INFO: task file is empty; nothing to do."
  exit 0
fi

echo "Plan:"
echo "  tool       : $TOOL"
echo "  parallel   : $PARALLEL"
echo "  tasks      : $TASK_COUNT (from $TASK_FILE)"
echo "  log dir    : $LOG_DIR"
echo "  template   : $PROMPT_TEMPLATE"
echo

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run — listing first 5 expanded prompts:"
  head -5 "$TASK_FILE" | while read -r task; do
    [[ -z "$task" ]] && continue
    echo "  → ${PROMPT_TEMPLATE//\{\{TASK\}\}/$task}"
  done
  exit 0
fi

# ---- worker function (exported to xargs subshell) ----

# We export everything xargs's subshell needs to run a single task.
export TOOL PROMPT_TEMPLATE LOG_DIR
export -f "tool_${TOOL}_invoke"

run_one() {
  local task="$1"
  [[ -z "$task" ]] && return 0

  local prompt="${PROMPT_TEMPLATE//\{\{TASK\}\}/$task}"
  local slug
  slug="$(echo "$task" | tr '/ ' '__' | tr -cd 'A-Za-z0-9_.-' | cut -c1-80)"
  local log="$LOG_DIR/$slug.log"

  echo "[$(date +%H:%M:%S)] START $task"
  if "tool_${TOOL}_invoke" "$prompt" > "$log" 2>&1; then
    echo "[$(date +%H:%M:%S)] OK    $task ($log)"
    return 0
  else
    echo "[$(date +%H:%M:%S)] FAIL  $task ($log)"
    return 1
  fi
}
export -f run_one

# ---- fan out via xargs -P ----

# `set +e` so a failing worker doesn't abort the whole batch.
set +e
grep -ve '^[[:space:]]*$' "$TASK_FILE" \
  | xargs -P "$PARALLEL" -I '{}' bash -c 'run_one "$@"' _ '{}'
EXIT=$?
set -e

# ---- summarize ----

if [[ "$EXIT" -ne 0 ]]; then
  FAILED_TASKS="$(grep -lE '^\[..:..:..\] FAIL' "$LOG_DIR"/*.log 2>/dev/null | wc -l | tr -d ' ')"
  echo
  echo "Done. Some workers failed. Logs: $LOG_DIR/"
  echo "Failed task count (approx): $FAILED_TASKS"
  exit 1
fi

echo
echo "All workers exited 0. Logs: $LOG_DIR/"
