#!/usr/bin/env bash
# align-parallel.sh — drive `/align`-equivalent parallelism on tools that lack
# native sub-agent dispatch. Reads pending findings from `ai/align/ledger.md`,
# fans out one tool process per finding.
#
# Usage:
#   align-parallel.sh --tool=<kimi|qwen|aider|opencode|codex|claude> --parallel=<N> [--dry-run]
#
# Optional:
#   --ledger=<path>         (default: ai/align/ledger.md)
#   --status=<states>       comma-separated (default: detected,in-progress,halted)
#   --max-tasks=<N>         cap on tasks dispatched
#   --log-dir=<path>        (default: ai/_parallel-runs/align-<iso>)
#
# Each tool process is told to claim one finding row, run find-and-align's
# 5-step loop on it (DETECT → DECIDE → FIX → VERIFY → RECORD), and update the
# ledger row.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOOL=""
PARALLEL=""
LEDGER="ai/align/ledger.md"
STATES="detected,in-progress,halted"
MAX_TASKS=""
LOG_DIR=""
DRY_RUN=0

usage() {
  sed -n '2,18p' "$0"
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --tool=*)       TOOL="${arg#*=}" ;;
    --parallel=*)   PARALLEL="${arg#*=}" ;;
    --ledger=*)     LEDGER="${arg#*=}" ;;
    --status=*)     STATES="${arg#*=}" ;;
    --max-tasks=*)  MAX_TASKS="${arg#*=}" ;;
    --log-dir=*)    LOG_DIR="${arg#*=}" ;;
    --dry-run)      DRY_RUN=1 ;;
    -h|--help)      usage ;;
    *) echo "ERR: unknown arg: $arg" >&2; usage ;;
  esac
done

[[ -z "$TOOL" || -z "$PARALLEL" ]] && usage

if [[ ! -f "$LEDGER" ]]; then
  echo "ERR: ledger not found: $LEDGER" >&2
  echo "     run /align-scan first to build it." >&2
  exit 2
fi

TASK_FILE="$(mktemp -t align-tasks.XXXXXX)"
trap 'rm -f "$TASK_FILE"' EXIT

awk -v states="$STATES" '
  BEGIN {
    n = split(states, arr, ",")
    for (i = 1; i <= n; i++) want[arr[i]] = 1
  }
  /^## [A-Za-z0-9_-]+/ {
    current = $2
    have_status = 0
    next
  }
  /^status: / && current && !have_status {
    s = $2
    have_status = 1
    if (s in want) print current
    current = ""
  }
' "$LEDGER" > "$TASK_FILE"

if [[ -n "$MAX_TASKS" ]]; then
  head -n "$MAX_TASKS" "$TASK_FILE" > "$TASK_FILE.capped"
  mv "$TASK_FILE.capped" "$TASK_FILE"
fi

TASK_COUNT=$(wc -l < "$TASK_FILE" | tr -d ' ')

if [[ "$TASK_COUNT" -eq 0 ]]; then
  echo "INFO: no rows in $LEDGER match status ($STATES). Nothing to do."
  exit 0
fi

LOG_DIR="${LOG_DIR:-ai/_parallel-runs/align-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOG_DIR"

PROMPT_TEMPLATE='Read align-discipline.md and align-ledger.md. Pick row {{TASK}} from ai/align/ledger.md. Run the find-and-align 5-step loop on that row only: DETECT (re-verify the fingerprint at the cited path:line still exists), DECIDE (pick the closure verb from align-discipline.md vocabulary), FIX (mechanical edit; touch only the scope), VERIFY (lint+typecheck+scoped tests+re-detect green), RECORD (one commit; update ledger row with file lock; gaps_in must equal gaps_closed). Halt only on genuine blockers (cross-repo dependency, security regression, ambiguous fix without ADR). Net-lines on structural classes must be ≤ 0; functional adds must cite an idiom from _extracted-idioms.md.'

ARGS=(
  --tool="$TOOL"
  --parallel="$PARALLEL"
  --task-file="$TASK_FILE"
  --prompt-template="$PROMPT_TEMPLATE"
  --log-dir="$LOG_DIR"
)
[[ "$DRY_RUN" -eq 1 ]] && ARGS+=(--dry-run)

echo "Align parallel fan-out:"
echo "  tool       : $TOOL"
echo "  parallel   : $PARALLEL"
echo "  ledger     : $LEDGER"
echo "  picked     : $TASK_COUNT rows (status in $STATES)"
echo "  log dir    : $LOG_DIR"
echo

exec "$SCRIPT_DIR/parallel-fan-out.sh" "${ARGS[@]}"
