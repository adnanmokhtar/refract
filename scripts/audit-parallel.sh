#!/usr/bin/env bash
# audit-parallel.sh — generic parallel dispatcher for pack-level audits that
# produce per-finding ledgers. One wrapper, many packs.
#
# Usage:
#   audit-parallel.sh --pack=<name> --tool=<tool> --parallel=<N> [flags]
#
# Supported packs (one wrapper per pack-level audit):
#   security    → ai/security-audit/ledger.md (security pack — security-audit command)
#   perf        → ai/perf-audit/ledger.md (performance pack — perf-audit command)
#   i18n        → ai/i18n-audit/ledger.md (frontend pack — i18n-audit command)
#   a11y        → ai/a11y-audit/ledger.md (frontend pack — a11y-audit command)
#   db          → ai/db-audit/ledger.md (database pack — db-audit command)
#   ui-sweep    → ai/ui-sweep/ledger.md (ui-ux pack — ui-sweep command)
#
# Each pack runs its scan in Claude Code first to build the ledger, then this
# wrapper fans out per-row workers in any headless-capable tool.
#
# Optional flags:
#   --ledger=<path>         override default ledger path
#   --status=<states>       comma-separated states to pick (pack-specific defaults)
#   --max-tasks=<N>         cap on tasks dispatched
#   --log-dir=<path>        custom log dir
#   --dry-run               preview only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACK=""
TOOL=""
PARALLEL=""
LEDGER=""
STATES=""
MAX_TASKS=""
LOG_DIR=""
DRY_RUN=0

usage() {
  sed -n '2,28p' "$0"
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --pack=*)       PACK="${arg#*=}" ;;
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

[[ -z "$PACK" || -z "$TOOL" || -z "$PARALLEL" ]] && usage

# ---- pack configuration map ----
#
# Each pack defines:
#   default_ledger   — where the pack's audit ledger lives
#   default_states   — which row statuses to pick by default
#   prompt_template  — what each worker is told to do (with {{TASK}} placeholder)

case "$PACK" in
  security)
    DEFAULT_LEDGER="ai/security-audit/ledger.md"
    DEFAULT_STATES="detected,in-progress,halted"
    PROMPT_TEMPLATE='Read security-principles.md (or the project security rule). Pick row {{TASK}} from ai/security-audit/ledger.md. Apply the closure verb the row specifies (add-auth-gate / parameterize-query / sanitize-input / rotate-secret / unify-error-response / add-csrf-token / add-rate-limit / add-tenant-scope / etc.). Security findings are ALWAYS at least standard tier; critical security ALWAYS heavy — no demotion. VERIFY: lint+typecheck+scoped tests + re-detect at the cited path:line + a focused security regression test. RECORD: one commit per finding; update ledger with file lock; gaps_in must equal gaps_closed.'
    ;;
  perf)
    DEFAULT_LEDGER="ai/perf-audit/ledger.md"
    DEFAULT_STATES="detected,in-progress,halted"
    PROMPT_TEMPLATE='Read performance-principles.md and the project profile. Pick row {{TASK}} from ai/perf-audit/ledger.md. Apply the closure verb (parallelize-independent / batch-load / project-columns / add-cache / add-index / push-filter-to-db / replace-loop-with-pipeline / lazy-load / debounce-call / etc.). Behavior-preserving — observable identical, faster. Capture before/after measurement (latency p50/p95, query count, payload size — whichever the row identifies). VERIFY: lint+typecheck+scoped tests; perf regression test if the row needs one. RECORD: one commit; ledger update with file lock; gaps_in must equal gaps_closed; record measurement in ai/perf-audit/measurements/<row-id>.md.'
    ;;
  i18n)
    DEFAULT_LEDGER="ai/i18n-audit/ledger.md"
    DEFAULT_STATES="detected,in-progress,halted"
    PROMPT_TEMPLATE='Read the project i18n rule (frontend/rules/i18n.md or equivalent). Pick row {{TASK}} from ai/i18n-audit/ledger.md. Apply the closure verb (add-missing-key / fix-key-namespace / extract-hardcoded-string / unify-key-shape / remove-stale-key). Every user-facing string MUST resolve in EVERY declared locale. VERIFY: lint+typecheck+scoped tests + check_i18n_locale_parity. RECORD: one commit; ledger update with file lock; gaps_in must equal gaps_closed.'
    ;;
  a11y)
    DEFAULT_LEDGER="ai/a11y-audit/ledger.md"
    DEFAULT_STATES="detected,in-progress,halted"
    PROMPT_TEMPLATE='Read the project a11y rule + WCAG baseline. Pick row {{TASK}} from ai/a11y-audit/ledger.md. Apply the closure verb (add-aria-label / fix-keyboard-trap / add-focus-management / fix-color-contrast / add-skip-link / fix-heading-order / add-form-label / etc.). Run axe-core (or project-equivalent) before/after; the resolved violation MUST disappear without introducing new ones. VERIFY: lint+typecheck+scoped tests + axe-core baseline diff. RECORD: one commit; ledger update with file lock; gaps_in must equal gaps_closed.'
    ;;
  db)
    DEFAULT_LEDGER="ai/db-audit/ledger.md"
    DEFAULT_STATES="detected,in-progress,halted"
    PROMPT_TEMPLATE='Read the project database conventions (database/rules/* or backend/rules/database). Pick row {{TASK}} from ai/db-audit/ledger.md. Apply the closure verb (unify-column-naming / unify-type-choice / add-index / parameterize-query / add-tenant-filter / add-soft-delete / add-audit-fields / unify-fk-naming / unify-migration-pattern / fix-timezone-drift / etc.). For schema changes: emit a reversible migration in the project migrations dir. Run EXPLAIN ANALYZE on touched queries against prod-sized data. VERIFY: lint+typecheck+migration tests + schema-consistency-audit. RECORD: one commit; ledger update with file lock; gaps_in must equal gaps_closed.'
    ;;
  ui-sweep)
    DEFAULT_LEDGER="ai/ui-sweep/ledger.md"
    DEFAULT_STATES="detected,in-progress,halted,pending-phase"
    PROMPT_TEMPLATE='Read the project UI-UX gold standard (_extracted-idioms.md § Design tokens / Spacing / Components). Pick row {{TASK}} from ai/ui-sweep/ledger.md. Each row is scoped to one user flow phase (auth / checkout / dashboard / etc.) OR one cross-cutting class (hierarchy / spacing / tokens / states / motion / focus / type-scale / icon-vocab). Apply the closure verb (apply-token / extract-token / add-empty-state / add-loading-skeleton / add-error-state / unify-cta-placement / consolidate-icon / apply-type-scale / add-focus-animation). Capture before/after screenshots to ai/ui-sweep/baseline/<iso>/<page>.png. VERIFY: visual regression diff, a11y baseline preserved, lint+typecheck. RECORD: one commit per finding; update ledger with file lock; gaps_in must equal gaps_closed.'
    ;;
  *)
    echo "ERR: unknown pack '$PACK'." >&2
    echo "Supported: security, perf, i18n, a11y, db, ui-sweep" >&2
    echo "(or use migrate-parallel.sh / align-parallel.sh / optimize-parallel.sh / polish-parallel.sh for those)" >&2
    exit 2
    ;;
esac

# Apply user overrides on top of pack defaults
LEDGER="${LEDGER:-$DEFAULT_LEDGER}"
STATES="${STATES:-$DEFAULT_STATES}"

if [[ ! -f "$LEDGER" ]]; then
  echo "ERR: ledger not found: $LEDGER" >&2
  echo "     run the pack's scan command in Claude Code first to build it." >&2
  echo "     pack='$PACK' expects: $DEFAULT_LEDGER" >&2
  exit 2
fi

# ---- extract pending row ids ----

TASK_FILE="$(mktemp -t audit-$PACK-tasks.XXXXXX)"
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

LOG_DIR="${LOG_DIR:-ai/_parallel-runs/$PACK-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$LOG_DIR"

ARGS=(
  --tool="$TOOL"
  --parallel="$PARALLEL"
  --task-file="$TASK_FILE"
  --prompt-template="$PROMPT_TEMPLATE"
  --log-dir="$LOG_DIR"
)
[[ "$DRY_RUN" -eq 1 ]] && ARGS+=(--dry-run)

echo "Audit parallel fan-out:"
echo "  pack       : $PACK"
echo "  tool       : $TOOL"
echo "  parallel   : $PARALLEL"
echo "  ledger     : $LEDGER"
echo "  picked     : $TASK_COUNT rows (status in $STATES)"
echo "  log dir    : $LOG_DIR"
echo

exec "$SCRIPT_DIR/parallel-fan-out.sh" "${ARGS[@]}"
