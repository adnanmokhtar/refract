#!/usr/bin/env bash
# migrate-parallel.sh — drive `/migrate`-equivalent parallelism on tools that
# lack native sub-agent dispatch (Kimi, Aider, Codex). Reads pending rows from
# `ai/migration/ledger.md`, fans out one tool process per row.
#
# Usage:
#   migrate-parallel.sh --tool=<kimi|qwen|aider|opencode|codex|claude> --parallel=<N> [--dry-run]
#
# Optional:
#   --ledger=<path>         (default: ai/migration/ledger.md)
#   --status=<states>       comma-separated states to pick (default: V1-only,unverified,detected)
#   --max-tasks=<N>         cap on tasks dispatched (default: no cap)
#   --log-dir=<path>        (default: ai/_parallel-runs/migrate-<iso>)
#
# Per-row invocation: spawns one tool process per ledger row whose `status:`
# matches the picker. Each process receives a prompt asking it to run the
# per-feature port loop on that row id, following migration-discipline.md.
#
# Coordination: workers update the ledger row independently. The ledger file
# is small enough that flock(1) on the file gates concurrent edits cleanly
# inside each tool's own update step (the tool, not this script, holds the
# lock — this script only dispatches).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOOL=""
PARALLEL=""
LEDGER="ai/migration/ledger.md"
STATES="V1-only,unverified,detected"
MAX_TASKS=""
LOG_DIR=""
DRY_RUN=0

usage() {
  sed -n '2,20p' "$0"
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
  echo "     run /migration-scan first to build it." >&2
  exit 2
fi

# ---- extract pending row ids from the ledger ----
#
# Format expected (per migration-ledger.md ai-pattern):
#
#   ## <ROW-ID>
#   status: V1-only
#   class: ...
#   ...
#
# Strategy: same fenced-yaml ledger blocks as validate-migration-artifacts.sh discover_features.
# Emits ledger row ids (F001, …) whose status:/state: matches --status.

TASK_FILE="$(mktemp -t migrate-tasks.XXXXXX)"
trap 'rm -f "$TASK_FILE"' EXIT

awk -v states="$STATES" '
  BEGIN {
    n = split(states, arr, ",")
    for (i = 1; i <= n; i++) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", arr[i])
      want[arr[i]] = 1
    }
  }
  /^id: F[0-9]+[a-z]?$/ {
    if (id != "") emit()
    id = $2
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
  in_block && /^status: / { st = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", st); next }
  in_block && /^state: / { if (st == "") { st = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", st) }; next }
  function emit() {
    if (id != "" && st != "" && (st in want)) print id
  }
  END { if (id != "") emit() }
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

LOG_DIR="${LOG_DIR:-ai/_parallel-runs/migrate-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOG_DIR"

PROMPT_TEMPLATE='Read migration-discipline.md and migration-ledger.md. Pick row {{TASK}} from ai/migration/ledger.md. Run the per-feature port loop on that row only: read V1 contract, port to V2 (V2 structure, V1 behaviour), verify (lint+typecheck+scoped tests), commit one change per fix, update the ledger row (with file lock on ai/migration/ledger.md). Halt only on cross-repo blockers, security regressions, or genuinely unreadable V1 source. Otherwise: just port. Re-detect after each fix; gaps_in must equal gaps_closed before status advances.'

ARGS=(
  --tool="$TOOL"
  --parallel="$PARALLEL"
  --task-file="$TASK_FILE"
  --prompt-template="$PROMPT_TEMPLATE"
  --log-dir="$LOG_DIR"
)
[[ "$DRY_RUN" -eq 1 ]] && ARGS+=(--dry-run)

echo "Migration parallel fan-out:"
echo "  tool       : $TOOL"
echo "  parallel   : $PARALLEL"
echo "  ledger     : $LEDGER"
echo "  picked     : $TASK_COUNT rows (status in $STATES)"
echo "  log dir    : $LOG_DIR"
echo

exec "$SCRIPT_DIR/parallel-fan-out.sh" "${ARGS[@]}"
