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

axis_keywords() {
  local f="$1"
  local n=0
  grep -qiE 'cron|schedule|@Cron|crontab' "$f" && n=$((n+1))
  grep -qiE 'queue|consumer|worker|subscriber|kafka' "$f" && n=$((n+1))
  grep -qiE 'route|router|endpoint|handler|HTTP' "$f" && n=$((n+1))
  grep -qiE 'admin|internal.?tool|django\.admin' "$f" && n=$((n+1))
  grep -qiE 'deploy|pipeline|helm|terraform|docker' "$f" && n=$((n+1))
  grep -qiE 'runbook|playbook|on-?call' "$f" && n=$((n+1))
  echo "$n"
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
  score=$(axis_keywords "$OUT")
  if [[ "${score:-0}" -lt 4 ]]; then
    echo "ERR: $OUT documents only $score/6 axis signals (need ≥4 keyword hits or expand table)" >&2
    exit 1
  fi
  echo "OK: reachability doc passes lint ($score axis signals)"
fi
exit 0
