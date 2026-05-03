#!/usr/bin/env bash
# optimize-parallel.sh — drive `/optimize`-equivalent parallelism on tools that
# lack native sub-agent dispatch. Reads pending findings from
# `ai/optimize/ledger.md`, fans out one tool process per finding.
#
# Usage:
#   optimize-parallel.sh --tool=<kimi|qwen|aider|opencode|codex|claude> --parallel=<N> [--dry-run]
#
# Optional:
#   --ledger=<path>         (default: ai/optimize/ledger.md)
#   --status=<states>       comma-separated (default: detected,in-progress,halted)
#   --max-tasks=<N>         cap on tasks dispatched
#   --log-dir=<path>        (default: ai/_parallel-runs/optimize-<iso>)
#
# Each worker handles one architectural OR tactical finding from /optimize:
# layer violations, god modules, missing abstractions, cyclic dependencies,
# cross-cutting duplication, clean-code, refactoring, SOLID, performance,
# dead code, dedup, over-abstraction.
#
# IMPORTANT: foundation-first ordering matters. Architectural fixes cascade
# (one fix dissolves dozens of tactical findings). For best results:
#   1. Run with --status=architectural FIRST (sequential, --parallel=1).
#   2. Re-scan via /optimize-scan (Claude) or equivalent.
#   3. Run with --status=tactical SECOND (parallel-safe, --parallel=6+).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOOL=""
PARALLEL=""
LEDGER="ai/optimize/ledger.md"
STATES="detected,in-progress,halted"
MAX_TASKS=""
LOG_DIR=""
DRY_RUN=0

usage() {
  sed -n '2,22p' "$0"
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
  echo "     run /optimize first (with Claude Code) to build it, OR pass --ledger=<path> to a custom ledger." >&2
  exit 2
fi

TASK_FILE="$(mktemp -t optimize-tasks.XXXXXX)"
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

LOG_DIR="${LOG_DIR:-ai/_parallel-runs/optimize-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOG_DIR"

PROMPT_TEMPLATE='Read the project profile (_extracted-codebase.md, _extracted-idioms.md, ai/architecture.md, ai/conventions.md). Pick row {{TASK}} from ai/optimize/ledger.md. Apply the closure verb the row specifies (architectural classes: move-responsibility, introduce-abstraction, fix-layering, centralize-cross-cutting, split-god-module, decouple-cycle, merge-anemic-module; tactical classes: extract-method, flatten-conditional, parameter-object, magic-to-constant, replace-loop-with-pipeline, rename-for-clarity, etc.). Behavior-preserving — observable behavior unchanged. VERIFY: lint+typecheck+scoped tests must stay green; re-detect at the source path must show fingerprint resolved. RECORD: one commit per finding; update ledger row with file lock; gaps_in must equal gaps_closed.'

ARGS=(
  --tool="$TOOL"
  --parallel="$PARALLEL"
  --task-file="$TASK_FILE"
  --prompt-template="$PROMPT_TEMPLATE"
  --log-dir="$LOG_DIR"
)
[[ "$DRY_RUN" -eq 1 ]] && ARGS+=(--dry-run)

echo "Optimize parallel fan-out:"
echo "  tool       : $TOOL"
echo "  parallel   : $PARALLEL"
echo "  ledger     : $LEDGER"
echo "  picked     : $TASK_COUNT rows (status in $STATES)"
echo "  log dir    : $LOG_DIR"
echo
echo "Reminder: architectural fixes cascade — run with --status=architectural first (--parallel=1),"
echo "          re-scan, then run again with tactical findings (--parallel=6+)."
echo

exec "$SCRIPT_DIR/parallel-fan-out.sh" "${ARGS[@]}"
