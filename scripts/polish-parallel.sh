#!/usr/bin/env bash
# polish-parallel.sh — drive `/polish`-equivalent parallelism on tools that
# lack native sub-agent dispatch. Reads pending findings from
# `ai/polish/ledger.md`, fans out one tool process per finding.
#
# Usage:
#   polish-parallel.sh --tool=<kimi|qwen|aider|opencode|codex|claude> --parallel=<N> [--dry-run]
#
# Optional:
#   --ledger=<path>         (default: ai/polish/ledger.md)
#   --status=<states>       comma-separated (default: detected,in-progress,halted)
#   --max-tasks=<N>         cap on tasks dispatched
#   --log-dir=<path>        (default: ai/_parallel-runs/polish-<iso>)
#
# Stack-conditional: detectors + closure verbs vary by PROJECT_KIND.
#   frontend-* — visual hierarchy / spacing / tokens / states / motion / focus / type-scale
#   backend-*  — API consistency (envelope / errors / pagination / naming / idempotency / log-fields / metric-names)
#   data-*     — schema consistency (column naming / types / indexes / audit fields / migration patterns)
#   mobile-*   — frontend polish + iOS HIG / Material conventions
#
# Each worker reads its row's class and applies the matching closure verb.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOOL=""
PARALLEL=""
LEDGER="ai/polish/ledger.md"
STATES="detected,in-progress,halted"
MAX_TASKS=""
LOG_DIR=""
DRY_RUN=0

usage() {
  sed -n '2,21p' "$0"
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
  echo "     run /polish first (with Claude Code) to build it, OR pass --ledger=<path>." >&2
  exit 2
fi

TASK_FILE="$(mktemp -t polish-tasks.XXXXXX)"
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

LOG_DIR="${LOG_DIR:-ai/_parallel-runs/polish-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOG_DIR"

PROMPT_TEMPLATE='Read the project profile (_extracted-codebase.md § Stack — drives PROJECT_KIND, _extracted-idioms.md, ai/conventions.md, ai/architecture.md). Pick row {{TASK}} from ai/polish/ledger.md. Apply the stack-conditional closure verb the row specifies. For frontend-*: apply-token / extract-token / add-empty-state / add-loading-skeleton / add-error-state / unify-cta-placement / consolidate-icon / apply-type-scale / add-focus-animation. For backend-*: unify-envelope / unify-error-contract / unify-naming / unify-pagination / unify-versioning / unify-auth-header / add-idempotency-key / unify-log-fields / unify-metric-names / unify-trace-spans / add-openapi-doc. For data-*: unify-column-naming / unify-type-choice / unify-index-naming / unify-fk-naming / unify-migration-pattern / unify-timestamp-cols / add-soft-delete / add-audit-fields. For mobile-*: all frontend verbs + platform-conformance fixes (iOS HIG / Material). Behavior-preserving for structural fixes; visual change allowed for visual polish. VERIFY: lint+typecheck+scoped tests + re-detect green. RECORD: one commit per finding; update ledger row with file lock.'

ARGS=(
  --tool="$TOOL"
  --parallel="$PARALLEL"
  --task-file="$TASK_FILE"
  --prompt-template="$PROMPT_TEMPLATE"
  --log-dir="$LOG_DIR"
  --ledger="$LEDGER"
)
[[ "$DRY_RUN" -eq 1 ]] && ARGS+=(--dry-run)

echo "Polish parallel fan-out:"
echo "  tool       : $TOOL"
echo "  parallel   : $PARALLEL"
echo "  ledger     : $LEDGER"
echo "  picked     : $TASK_COUNT rows (status in $STATES)"
echo "  log dir    : $LOG_DIR"
echo

exec "$SCRIPT_DIR/parallel-fan-out.sh" "${ARGS[@]}"
