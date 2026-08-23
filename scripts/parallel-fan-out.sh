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
#     [--ledger=<path>] \
#     [--log-dir=<path>] \
#     [--dry-run]
#
# Ledger lock: pass --ledger=ai/optimize/ledger.md (etc.) so flock targets the pack ledger.
# Default lock file is ai/migration/ledger.md when --ledger is omitted.
# Set LEDGER_LOCK="" to disable flock entirely.
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

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo, so an unresolved
# BASH_SOURCE puts this dir at ~/.claude/scripts and every sibling asset below resolves only
# if it too was linked (see CONTRIBUTING § "Scripts run from two places").
# Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SCRIPT_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd

# shellcheck source=./_parallel-tool-config.sh
source "$SCRIPT_DIR/_parallel-tool-config.sh"

# ---- argument parsing ----

TOOL=""
PARALLEL=""
TASK_FILE=""
PROMPT_TEMPLATE=""
LOG_DIR=""
DRY_RUN=0
CLI_LEDGER=""

usage() {
  sed -n '2,35p' "$0"
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --tool=*)             TOOL="${arg#*=}" ;;
    --parallel=*)         PARALLEL="${arg#*=}" ;;
    --task-file=*)        TASK_FILE="${arg#*=}" ;;
    --prompt-template=*)  PROMPT_TEMPLATE="${arg#*=}" ;;
    --ledger=*)           CLI_LEDGER="${arg#*=}" ;;
    --log-dir=*)          LOG_DIR="${arg#*=}" ;;
    --dry-run)            DRY_RUN=1 ;;
    -h|--help)            usage ;;
    *) echo "ERR: unknown arg: $arg" >&2; usage ;;
  esac
done

# Lock file for optional flock: CLI --ledger wins; else env LEDGER_LOCK; else migration default.
# Single-dash (unset-only) is intentional: an explicit `LEDGER_LOCK=""` must be
# preserved so it disables flock (per usage header), which colon-dash would clobber
# back to the default.
if [[ -n "${CLI_LEDGER:-}" ]]; then
  LEDGER_LOCK="$CLI_LEDGER"
else
  LEDGER_LOCK="${LEDGER_LOCK-ai/migration/ledger.md}"
fi

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

# Count non-blank task lines robustly. `grep -cve` (BSD) drops a final line that
# has no trailing newline, so a 1-line task file with no EOL counted as 0 → a
# silent no-op exit 0 even though the fan-out feed below WOULD run it. Reuse the
# exact feed pattern and count emitted lines via awk's NR (counts the last line
# whether or not it ends in a newline).
TASK_COUNT=$(grep -ve '^[[:space:]]*$' "$TASK_FILE" | awk 'END { print NR }')
if [[ "$TASK_COUNT" -eq 0 ]]; then
  echo "INFO: task file is empty; nothing to do."
  exit 0
fi

echo "Plan:"
echo "  tool       : $TOOL"
echo "  parallel   : $PARALLEL"
echo "  tasks      : $TASK_COUNT (from $TASK_FILE)"
echo "  log dir    : $LOG_DIR"
echo "  ledger lock: ${LEDGER_LOCK:-<disabled>}"
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
export TOOL PROMPT_TEMPLATE LOG_DIR LEDGER_LOCK
export -f "tool_${TOOL}_invoke"

run_one() {
  local task="$1"
  [[ -z "$task" ]] && return 0

  local prompt="${PROMPT_TEMPLATE//\{\{TASK\}\}/$task}"
  # Slug = readable prefix + short checksum of the FULL task. The prefix alone
  # collides when two tasks differ only past char 80 or only in stripped chars
  # (one worker's log would clobber the other's). cksum (POSIX; on macOS + CI)
  # disambiguates while keeping the prefix human-readable.
  local slug prefix hash
  prefix="$(echo "$task" | tr '/ ' '__' | tr -cd 'A-Za-z0-9_.-' | cut -c1-72)"
  hash="$(printf '%s' "$task" | cksum | cut -d' ' -f1)"
  slug="${prefix}-${hash}"
  local log="$LOG_DIR/$slug.log"

  echo "[$(date +%H:%M:%S)] START $task"
  local rc=0
  if [[ -n "${LEDGER_LOCK:-}" && -f "${LEDGER_LOCK}" ]] && command -v flock >/dev/null 2>&1; then
    # NOTE (serialization): this lock wraps the entire tool invocation, so on
    # flock hosts the fan-out runs effectively serial. The correct scope is the
    # ledger-append critical section only, but this dispatcher never appends to
    # the ledger itself — the spawned tool does, inside its own opaque run (see
    # migrate-parallel.sh header: "the tool, not this script, holds the lock").
    # Narrowing the lock here is not possible without that broader redesign, so
    # we keep the conservative coarse lock rather than risk interleaved edits.
    exec {LOCK_FD}>>"${LEDGER_LOCK}"
    flock "$LOCK_FD"
    if "tool_${TOOL}_invoke" "$prompt" > "$log" 2>&1; then rc=0; else rc=$?; fi
    flock -u "$LOCK_FD" 2>/dev/null || true
    exec {LOCK_FD}>&- 2>/dev/null || true
  else
    if "tool_${TOOL}_invoke" "$prompt" > "$log" 2>&1; then rc=0; else rc=$?; fi
  fi
  if [[ "$rc" -eq 0 ]]; then
    echo "[$(date +%H:%M:%S)] OK    $task ($log)"
    return 0
  else
    # Drop a sentinel so the summary can count failures reliably. The FAIL line
    # below goes to stdout (xargs-aggregated), never into "$log" — so grepping
    # the per-task logs for it always found 0 (PFO-02). Count these markers.
    : > "$log.failed"
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
  # Count the per-task .failed sentinels dropped by run_one (the FAIL marker is
  # emitted to stdout, never written into the per-task .log — so the old grep
  # over *.log always counted 0). ls is null-safe via the nullglob-free guard.
  FAILED_TASKS="$(find "$LOG_DIR" -maxdepth 1 -name '*.log.failed' 2>/dev/null | awk 'END { print NR }')"
  echo
  echo "Done. Some workers failed. Logs: $LOG_DIR/"
  echo "Failed task count: $FAILED_TASKS"
  exit 1
fi

echo
echo "All workers exited 0. Logs: $LOG_DIR/"
