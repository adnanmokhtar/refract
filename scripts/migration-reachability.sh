#!/usr/bin/env bash
# migration-reachability.sh — scaffold / lint 6-axis dead-V1 reachability doc.
#
# migration-discipline.md requires documenting whether V1 code is reachable via:
#   cron | queue consumer | HTTP route | admin tool | deploy hook | runbook path
#
# Usage:
#   migration-reachability.sh [--lint] <feature-slug>
#
# Without --lint: writes ai/migration/reachability/<feature>.md if missing (template).
# With --lint: fails if file missing or fewer than 4 axis keywords present.
#
# Exit: 0 ok / 1 lint fail / 2 usage

set -euo pipefail
export LC_ALL=C

LINT=0
FEATURE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lint) LINT=1; shift ;;
    -h|--help)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *)
      FEATURE="$1"
      shift
      ;;
  esac
done

[[ -z "$FEATURE" ]] && { echo "Usage: $0 [--lint] <feature-slug>" >&2; exit 2; }

OUT="ai/migration/reachability/${FEATURE}.md"
mkdir -p "$(dirname "$OUT")"

# Lint the EVIDENCE, not the axis labels (#8). The OLD keyword scorer grepped the whole file,
# but the template's own labels (Cron / Queue / route / admin / deploy / runbook) match all 6
# keyword groups — so a BLANK, unfilled template scored 6/6 and passed. Instead, parse each axis
# ROW: its decision cell must be a real choice (yes|no|n/a, NOT the literal "yes / no / n/a"
# placeholder), and every decided axis must carry non-empty evidence/reason. Prints "<filled>/<total>"
# on stdout; per-axis problems go to stderr (so they survive command substitution).
reachability_lint() {
  local f="$1" total=0 filled=0
  while IFS= read -r line; do
    echo "$line" | grep -qiE '^\|[[:space:]]*Axis\b' && continue              # header
    echo "$line" | grep -qE  '^\|[-: |]+\|[[:space:]]*$' && continue          # separator
    local axis dec ev
    axis=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    dec=$(echo  "$line" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    ev=$(echo   "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [[ -z "$axis" ]] && continue
    total=$((total + 1))
    if [[ -z "$dec" ]] || echo "$dec" | grep -qiE 'yes[[:space:]]*/[[:space:]]*no'; then
      echo "  '$axis': no decision (still the 'yes / no / n/a' placeholder)" >&2; continue
    fi
    if ! echo "$dec" | grep -qiE '^(yes|no|n/?a)$'; then
      echo "  '$axis': decision '$dec' is not one of yes/no/n/a" >&2; continue
    fi
    if [[ -z "$ev" ]]; then
      echo "  '$axis' = $dec but the Evidence cell is empty (cite path:line / job name, or the n/a reason)" >&2; continue
    fi
    filled=$((filled + 1))
  done < <(grep -E '^\|' "$f" 2>/dev/null)
  echo "$filled/$total"
}

if [[ ! -f "$OUT" ]]; then
  if [[ $LINT -eq 1 ]]; then
    echo "ERR: missing $OUT" >&2
    exit 1
  fi
  cat > "$OUT" << EOF
# Reachability — ${FEATURE}

Document each axis for **V1** symbol reachability (dead-code gate per migration-discipline.md).

| Axis | Reachable from V1? | Evidence (path:line or job name) |
|------|--------------------|-------------------------------------|
| Cron / scheduled job | yes / no / n/a | |
| Queue consumer | yes / no / n/a | |
| HTTP route / RPC | yes / no / n/a | |
| Admin tool / internal | yes / no / n/a | |
| Deploy hook / migration runner | yes / no / n/a | |
| Runbook / on-call doc | yes / no / n/a | |

**Notes:** If an axis is \`n/a\`, cite why (e.g. pure library helper only called from tests).

EOF
  echo "Wrote template $OUT — fill before advancing ledger row."
  exit 0
fi

if [[ $LINT -eq 1 ]]; then
  # Problems stream to stderr from inside the function; capture only the count from stdout.
  echo "Reachability lint — $OUT:" >&2
  result=$(reachability_lint "$OUT")   # "<filled>/<total>"
  filled="${result%%/*}"; total="${result##*/}"
  if [[ "${total:-0}" -lt 6 ]]; then
    echo "ERR: $OUT has only $total axis rows (need all 6: cron / queue / route / admin / deploy / runbook)" >&2
    exit 1
  fi
  if [[ "$filled" -ne "$total" ]]; then
    echo "ERR: $OUT incompletely filled — $filled/$total axes have a real decision + evidence (a blank template no longer passes)." >&2
    exit 1
  fi
  echo "OK: reachability doc fully documented ($filled/$total axes decided with evidence)"
fi
exit 0
