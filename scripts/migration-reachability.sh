#!/usr/bin/env bash
# migration-reachability.sh — the six-axis dead-V1 check of halt 11, scaffolded, computed, linted.
#
# migration-discipline.md halt 11: V1 code is dead only when it has zero callers on ALL SIX axes —
#   app source · downstream tests · cron/scheduler · route/API registration · infra/deploy config
#   · production telemetry (N/A when unwired)
# One live axis means port it. This script used to scaffold and lint a DIFFERENT six (cron / queue /
# route / admin / deploy / runbook), so a doc that passed its lint never answered halt 11, and it
# computed nothing: every decision was typed by hand. Now the axes are halt 11's, `--compute`
# counts callers per axis with rg over the named roots, and `--lint` re-runs that count when the doc
# names its symbols, so a "no" the code contradicts fails.
#
# Usage:
#   migration-reachability.sh <feature-slug>                    write the template (if missing) to
#                                                                ai/migration/reachability/<slug>.md
#   migration-reachability.sh --compute <feature-slug> --symbol=<name> [--symbol=<name>…]
#                             [--v1-root=<dir>] [--infra-root=<dir>…] [--telemetry=<file|dir>]
#                                                                print the six axes, read-only
#   migration-reachability.sh --lint <feature-slug>              check the doc (cwd-relative)
#
# The doc may carry two header lines the lint uses to re-compute:
#   symbols: <name>, <name>        (V1 function / class / job / route-name identifiers)
#   v1_root: <dir>                 (the V1 tree or its `git archive` snapshot; default .)
#
# rg runs with fixed-string word matching (-w -F), an explicit path, stdin closed, and node_modules /
# vendor / .git excluded. rg exit 2 (unreadable path, bad glob) is BLOCKED, never "0 callers".
#
# Exit: 0 ok / 1 lint fail / 2 usage / 4 an axis BLOCKED (--compute) or rg missing

set -euo pipefail
export LC_ALL=C

MODE=scaffold
FEATURE=""
V1_ROOT_ARG=""
TELEMETRY=""
declare -a SYMBOLS=()
declare -a INFRA_ROOTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lint)        MODE=lint; shift ;;
    --compute)     MODE=compute; shift ;;
    --symbol=*)    SYMBOLS+=("${1#--symbol=}"); shift ;;
    --v1-root=*)   V1_ROOT_ARG="${1#--v1-root=}"; shift ;;
    --infra-root=*) INFRA_ROOTS+=("${1#--infra-root=}"); shift ;;
    --telemetry=*) TELEMETRY="${1#--telemetry=}"; shift ;;
    -h|--help)     sed -n '2,32p' "$0"; exit 0 ;;
    -*)            echo "unknown flag: $1" >&2; exit 2 ;;
    *)             FEATURE="$1"; shift ;;
  esac
done
[[ -z "$FEATURE" ]] && { echo "Usage: $0 [--lint | --compute --symbol=<name>…] <feature-slug>" >&2; exit 2; }

OUT="ai/migration/reachability/${FEATURE}.md"

# The six axes, in halt 11's order. Each: label|lint keyword regex (case-insensitive).
AXES=(
  "App source (production callers)|app[[:space:]]*source|source"
  "Downstream tests|test"
  "Cron / scheduler|cron|schedul"
  "Route / API registration|route|api"
  "Infra / deploy config|infra|deploy"
  "Production telemetry|telemetry|traffic|access[[:space:]]*log"
)

# ── compute ─────────────────────────────────────────────────────────────────────────────────────
EXCL=(-g '!**/node_modules/**' -g '!**/vendor/**' -g '!**/.git/**' -g '!**/dist/**' -g '!**/build/**')
TESTG=(-g '**/tests/**' -g '**/test/**' -g '**/__tests__/**' -g '**/spec/**' -g '*.test.*' -g '*.spec.*'
       -g '*Test.php' -g '*Tests.cs' -g '*Test.java' -g '*_test.go' -g 'test_*.py' -g '*_test.py' -g '*_spec.rb')
NOTTEST=(-g '!**/tests/**' -g '!**/test/**' -g '!**/__tests__/**' -g '!**/spec/**' -g '!*.test.*' -g '!*.spec.*'
         -g '!*Test.php' -g '!*Tests.cs' -g '!*Test.java' -g '!*_test.go' -g '!test_*.py' -g '!*_test.py' -g '!*_spec.rb')
NOTDOCS=(-g '!*.md' -g '!**/docs/**' -g '!**/lang/**' -g '!**/locales/**' -g '!**/i18n/**' -g '!**/translations/**')
CRONG=(-g '**/Console/Kernel.php' -g '**/routes/console.php' -g '*cron*' -g '*Cron*' -g '*schedul*' -g '*Schedul*'
       -g '**/celery*.py' -g '*beat*' -g '**/sidekiq*.yml' -g '**/config/schedule.rb' -g 'crontab*')
ROUTEG=(-g '**/routes/**' -g '*route*' -g '*Route*' -g '**/urls.py' -g '*router*' -g '*Router*' -g '**/config/routes.rb')
INFRAG=(-g '*.yml' -g '*.yaml' -g 'Dockerfile*' -g '*.tf' -g 'Procfile*' -g 'Makefile' -g '*.sh' -g '*.conf'
        -g '*.ini' -g '*.service' -g '*.toml')

SYM_ARGS=()
build_sym_args() { local s; SYM_ARGS=(); for s in "${SYMBOLS[@]}"; do [[ -n "$s" ]] && SYM_ARGS+=(-e "$s"); done; }

# Definition lines are not callers: `function foo(`, `class Foo`, `def foo`, `func Foo` … for any symbol.
drop_definitions() {
  local syms="" s
  for s in "${SYMBOLS[@]}"; do syms="${syms}${s}|"; done
  awk -v syms="${syms%|}" '
    BEGIN { n = split(syms, S, "|") }
    {
      for (i = 1; i <= n; i++) {
        if ($0 ~ ("(function|class|def|fn|func|interface|trait|enum|const|let|var|public|private|protected)[[:space:]]+(static[[:space:]]+)?" S[i] "([^A-Za-z0-9_]|$)")) next
      }
      print
    }'
}

# axis_hits <axis-index> <root…> → prints "<hits>\t<first sites>" or "BLOCKED\t<why>"
axis_hits() {
  local idx="$1"; shift
  local -a roots=("$@") args=()
  local rc=0 out=""
  case "$idx" in
    0) args=("${NOTTEST[@]}" "${NOTDOCS[@]}") ;;
    1) args=("${TESTG[@]}") ;;
    2) args=("${CRONG[@]}" "${NOTTEST[@]}") ;;
    3) args=("${ROUTEG[@]}" -g '!**/routes/console.php' -g '!**/routes/channels.php' "${NOTTEST[@]}" "${NOTDOCS[@]}") ;;   # console.php is the scheduler axis
    4) args=("${INFRAG[@]}" "${NOTTEST[@]}") ;;
  esac
  out=$(rg -n --no-heading -w -F "${SYM_ARGS[@]}" "${args[@]}" "${EXCL[@]}" -- "${roots[@]}" </dev/null 2>/dev/null) || rc=$?
  if [[ $rc -eq 2 ]]; then printf 'BLOCKED\trg exit 2 over %s\n' "${roots[*]}"; return 0; fi
  [[ $idx -eq 0 || $idx -eq 3 ]] && out=$(printf '%s\n' "$out" | drop_definitions)
  out=$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' || true)
  local n sites
  n=$(printf '%s\n' "$out" | grep -c . || true)
  sites=$(printf '%s\n' "$out" | head -3 | awk -F: '{ printf "%s%s:%s", (NR > 1 ? ", " : ""), $1, $2 }')
  printf '%s\t%s\n' "${n:-0}" "$sites"
}

telemetry_hits() {
  [[ -z "$TELEMETRY" ]] && { printf 'N/A\tunwired: no telemetry export given (--telemetry=<access-log or APM export>)\n'; return 0; }
  [[ -e "$TELEMETRY" ]] || { printf 'BLOCKED\t%s does not exist\n' "$TELEMETRY"; return 0; }
  local rc=0 out
  out=$(rg -c -w -F "${SYM_ARGS[@]}" -- "$TELEMETRY" </dev/null 2>/dev/null) || rc=$?
  [[ $rc -eq 2 ]] && { printf 'BLOCKED\trg exit 2 over %s\n' "$TELEMETRY"; return 0; }
  local n
  n=$(printf '%s\n' "$out" | awk -F: '{ s += $NF } END { print s + 0 }')
  printf '%s\t%s\n' "$n" "$TELEMETRY"
}

# compute_axes <v1-root> → six lines "<label>\t<hits|BLOCKED|N/A>\t<sites or why>"
compute_axes() {
  local v1="$1" i label res
  local -a roots=("$v1")
  for (( i = 0; i < 5; i++ )); do
    label="${AXES[$i]%%|*}"
    if [[ $i -eq 4 && ${#INFRA_ROOTS[@]} -gt 0 ]]; then
      res=$(axis_hits "$i" "$v1" "${INFRA_ROOTS[@]}")
    else
      res=$(axis_hits "$i" "${roots[@]}")
    fi
    printf '%s\t%s\n' "$label" "$res"
  done
  printf '%s\t%s\n' "${AXES[5]%%|*}" "$(telemetry_hits)"
}

require_rg() { command -v rg >/dev/null 2>&1 || { echo "BLOCKED: rg (ripgrep) is not installed — no axis can be computed" >&2; exit 4; }; }

if [[ "$MODE" == compute ]]; then
  [[ ${#SYMBOLS[@]} -eq 0 ]] && { echo "--compute needs at least one --symbol=<V1 identifier>" >&2; exit 2; }
  require_rg
  v1="${V1_ROOT_ARG:-.}"
  [[ -d "$v1" ]] || { echo "BLOCKED: V1 root '$v1' is not a directory" >&2; exit 4; }
  build_sym_args
  blocked=0
  echo "# Reachability — ${FEATURE} (computed $(date -u +%Y-%m-%dT%H:%MZ), read-only)"
  echo
  echo "symbols: $(IFS=,; echo "${SYMBOLS[*]}")"
  echo "v1_root: $v1"
  echo
  echo "| Axis | Reachable from V1? | Evidence (path:line or job name) |"
  echo "|------|--------------------|-------------------------------------|"
  while IFS=$'\t' read -r label hits sites; do
    case "$hits" in
      BLOCKED) blocked=1; echo "| $label | BLOCKED | $sites |" ;;
      N/A)     echo "| $label | n/a | $sites |" ;;
      0)       echo "| $label | no | 0 callers of ${SYMBOLS[*]} (rg -w -F) |" ;;
      *)       echo "| $label | yes | $hits caller line(s): $sites |" ;;
    esac
  done < <(compute_axes "$v1")
  echo
  echo "Any axis 'yes' → the code is live: port it (halt 11). All 'no' / 'n/a' → dead: status deprecated, deprecation_reason: dead-v1-no-callers."
  [[ $blocked -eq 1 ]] && { echo "BLOCKED axis present — the dead-code verdict cannot be reached until it runs." >&2; exit 4; }
  exit 0
fi

# ── write the template ──────────────────────────────────────────────────────────────────────────
if [[ ! -f "$OUT" ]]; then
  if [[ "$MODE" == lint ]]; then
    echo "ERR: missing $OUT" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$OUT")"
  cat > "$OUT" << EOF
# Reachability — ${FEATURE}

Halt 11 (migration-discipline.md): V1 code is dead only with zero callers on all six axes.
Fill the table from \`migration-reachability.sh --compute ${FEATURE} --symbol=<name> --v1-root=<dir>\`.

symbols: <comma-separated V1 identifiers>
v1_root: <path to the V1 tree or its git-archive snapshot>

| Axis | Reachable from V1? | Evidence (path:line or job name) |
|------|--------------------|-------------------------------------|
| App source (production callers) | yes / no / n/a | |
| Downstream tests | yes / no / n/a | |
| Cron / scheduler | yes / no / n/a | |
| Route / API registration | yes / no / n/a | |
| Infra / deploy config | yes / no / n/a | |
| Production telemetry | yes / no / n/a | |

**Notes:** an \`n/a\` cites why (telemetry: "unwired" is a valid reason, halt 11).

EOF
  echo "Wrote template $OUT — fill it (or paste --compute output) before advancing the ledger row."
  exit 0
fi
[[ "$MODE" == scaffold ]] && { echo "$OUT exists — nothing written."; exit 0; }

# ── lint ────────────────────────────────────────────────────────────────────────────────────────
# Lint the EVIDENCE, not the axis labels (#8): the old keyword scorer grepped the whole file and the
# template's own labels matched every group, so a blank template passed. Each axis ROW needs a real
# decision (yes|no|n/a, not the "yes / no / n/a" placeholder) and non-empty evidence; the six rows
# must be halt 11's six axes; and when the doc names its symbols, every "no" is re-computed.
echo "Reachability lint — $OUT:" >&2
total=0; filled=0
declare -a ROW_AXIS=() ROW_DEC=()
while IFS= read -r line; do
  echo "$line" | grep -qiE '^\|[[:space:]]*Axis\b' && continue
  echo "$line" | grep -qE  '^\|[-: |]+\|[[:space:]]*$' && continue
  axis=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  dec=$(echo  "$line" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  ev=$(echo   "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ -z "$axis" ]] && continue
  total=$((total + 1))
  ROW_AXIS+=("$axis"); ROW_DEC+=("$(echo "$dec" | tr '[:upper:]' '[:lower:]')")
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
done < <(grep -E '^\|' "$OUT" 2>/dev/null)

# Every halt-11 axis present, by name.
missing=""
for (( a = 0; a < ${#AXES[@]}; a++ )); do
  label="${AXES[$a]%%|*}"; kw="${AXES[$a]#*|}"; found=0
  for (( r = 0; r < ${#ROW_AXIS[@]}; r++ )); do
    echo "${ROW_AXIS[$r]}" | grep -qiE "$kw" && { found=1; break; }
  done
  [[ $found -eq 0 ]] && missing="${missing}${missing:+; }$label"
done
if [[ -n "$missing" ]]; then
  echo "ERR: $OUT lacks halt-11 axes: $missing (the six are app source / downstream tests / cron-scheduler / route-API registration / infra-deploy config / production telemetry; the old cron/queue/route/admin/deploy/runbook set does not answer halt 11)" >&2
  exit 1
fi
if [[ "$filled" -ne "$total" ]]; then
  echo "ERR: $OUT incompletely filled — $filled/$total axes have a real decision + evidence (a blank template does not pass)." >&2
  exit 1
fi

# Re-compute every "no" when the doc names its symbols.
syms_line=$(grep -m1 -iE '^symbols:' "$OUT" 2>/dev/null | sed 's/^[Ss]ymbols:[[:space:]]*//' || true)
if [[ -n "$syms_line" && "$syms_line" != *"<"* ]]; then
  require_rg
  IFS=',' read -r -a raw <<< "$syms_line"
  for s in "${raw[@]}"; do s=$(echo "$s" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'); [[ -n "$s" ]] && SYMBOLS+=("$s"); done
  v1=$(grep -m1 -iE '^v1_root:' "$OUT" 2>/dev/null | sed 's/^[Vv]1_root:[[:space:]]*//; s/[[:space:]]*$//' || true)
  [[ -z "$v1" || "$v1" == *"<"* ]] && v1="${V1_ROOT_ARG:-.}"
  if [[ ! -d "$v1" ]]; then
    echo "ERR: $OUT names symbols but v1_root '$v1' is not a directory — the 'no' decisions cannot be verified" >&2
    exit 1
  fi
  build_sym_args
  contradicted=0
  while IFS=$'\t' read -r label hits sites; do
    for (( r = 0; r < ${#ROW_AXIS[@]}; r++ )); do
      kw=""
      for (( a = 0; a < ${#AXES[@]}; a++ )); do [[ "${AXES[$a]%%|*}" == "$label" ]] && kw="${AXES[$a]#*|}"; done
      echo "${ROW_AXIS[$r]}" | grep -qiE "$kw" || continue
      if [[ "${ROW_DEC[$r]}" == "no" ]]; then
        if [[ "$hits" == BLOCKED ]]; then
          echo "  '${ROW_AXIS[$r]}' = no, but the re-count is BLOCKED ($sites)" >&2; contradicted=1
        elif [[ "$hits" =~ ^[0-9]+$ && "$hits" -gt 0 ]]; then
          echo "  '${ROW_AXIS[$r]}' = no, but rg finds $hits caller line(s): $sites" >&2; contradicted=1
        fi
      fi
      break
    done
  done < <(compute_axes "$v1")
  if [[ $contradicted -eq 1 ]]; then
    echo "ERR: $OUT says 'no' on an axis the code contradicts — one live axis means the V1 code is not dead (halt 11)." >&2
    exit 1
  fi
fi
echo "OK: reachability doc documents all six halt-11 axes ($filled/$total decided with evidence)"
exit 0
