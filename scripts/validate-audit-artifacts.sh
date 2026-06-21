#!/usr/bin/env bash
# validate-audit-artifacts.sh — enforces /audit plan + finding gates.
#
# Mirrors validate-optimize-artifacts.sh in shape; targets ai/audit/ artifacts.
# The checks below are the ones commands/audit.md references as mechanical:
#   - check_no_handwaves_audit_plan   (§679) — no hand-wave language in ai/audit/plan.md
#   - check_p0_failure_mode_cited     (§675) — every P0 cites a concrete scale failure mode
#   - check_finding_citations (strict, §641) — every P0/P1/P2 cites <file:line>
#   - check_actionable_next_steps     — final-report ends with paste-ready commands
#   - check_ledger_gap_parity         — gaps_in == gaps_closed for terminal rows (if a ledger exists)
#
# Usage:
#   validate-audit-artifacts.sh [--plan=PATH] [--report=PATH] [--ledger=PATH] [--findings-dir=PATH]
#   validate-audit-artifacts.sh [--strict] [--quiet]
#
# Exit codes: 0 pass · 1 validation failures · 2 usage / fatal env
set -euo pipefail
export LC_ALL=C

PLAN_PATH="${PLAN_PATH:-ai/audit/plan.md}"
REPORT_PATH="${REPORT_PATH:-ai/audit/final-report.md}"
ASSESSMENT_PATH="${ASSESSMENT_PATH:-ai/audit/assessment.md}"
LEDGER_PATH="${LEDGER_PATH:-ai/audit/ledger.md}"
FINDINGS_DIR="${FINDINGS_DIR:-ai/audit/findings}"

STRICT=0
QUIET=0
TOTAL_PASS=0
TOTAL_FAIL=0
FAILURES=()

log_pass() { TOTAL_PASS=$((TOTAL_PASS + 1)); [[ $QUIET -eq 0 ]] && echo "  ✓ $1" || true; }
log_fail() { TOTAL_FAIL=$((TOTAL_FAIL + 1)); FAILURES+=("$1"); echo "  ✗ $1" >&2; }
log_warn() {
  if [[ $STRICT -eq 1 ]]; then log_fail "[strict] $1"
  elif [[ $QUIET -eq 0 ]]; then echo "  ⚠ $1"; fi
}
log_section() { [[ $QUIET -eq 0 ]] && echo && echo "── $1 ──" || true; }

# Strip fenced code + inline-code spans so we only scan prose.
_scrub_prose() {
  awk 'BEGIN{inf=0} /^```/{inf=1-inf; next} inf{next} {gsub(/`[^`]*`/,""); print}' "$1"
}

# ── audit produced output but no plan → vacuous green ────────────────────────
# A run that emitted a final-report, findings, OR terminal ledger rows CLAIMS it
# audited the codebase — but with no ai/audit/plan.md there's no ranked-plan
# evidence any axis actually ran. Mirror validate-align / validate-optimize: an
# absent plan is only acceptable when the run makes NO output claim. Otherwise a
# skipped audit must NOT look like a clean codebase (Trusted-Summary) → FAIL.
check_plan_exists_when_output() {
  [[ -f "$PLAN_PATH" ]] && return 0   # plan present → other gates cover it

  local output_claimed=0 why=""
  if [[ -f "$REPORT_PATH" ]]; then
    output_claimed=1; why="final-report.md present at $REPORT_PATH"
  elif [[ -f "$ASSESSMENT_PATH" ]]; then
    output_claimed=1; why="assessment.md present at $ASSESSMENT_PATH"
  fi
  if [[ $output_claimed -eq 0 && -d "$FINDINGS_DIR" ]]; then
    local _ff
    for _ff in "$FINDINGS_DIR"/*.md; do
      [[ -f "$_ff" ]] && { output_claimed=1; why="findings present in $FINDINGS_DIR"; break; }
    done
  fi
  if [[ $output_claimed -eq 0 && -f "$LEDGER_PATH" ]]; then
    local terminal_rows
    terminal_rows=$(grep -cE '^[[:space:]]*(status|state):[[:space:]]*(verified|done|fixed)\b' "$LEDGER_PATH" 2>/dev/null || true)
    terminal_rows=$(printf '%s' "${terminal_rows:-0}" | tr -cd '0-9'); terminal_rows=${terminal_rows:-0}
    [[ "$terminal_rows" -gt 0 ]] && { output_claimed=1; why="$terminal_rows terminal ledger row(s) in $LEDGER_PATH"; }
  fi

  if [[ $output_claimed -eq 1 ]]; then
    log_fail "audit produced output ($why) but the ranked plan is ABSENT at $PLAN_PATH — a run that claims it audited the codebase MUST emit a plan with per-axis ranked findings; a skipped audit must not pass green (Trusted-Summary)."
    return 1
  fi
  [[ $QUIET -eq 0 ]] && echo "  ▸ no plan at $PLAN_PATH and no output claimed (no report / findings / terminal rows) — nothing to validate"
  return 0
}

# ── findings present → ledger MANDATORY (ported from validate-optimize) ───────
# The ledger is the only re-detect proof surface (gap-count parity). Any run that
# FIXED findings (findings/<id>.md present) MUST carry a ledger — otherwise parity
# is unprovable. Mirrors validate-optimize-artifacts.sh main()'s findings-present
# escalation.
check_ledger_mandatory_when_findings() {
  [[ -f "$LEDGER_PATH" ]] && return 0   # ledger present → check_ledger_gap_parity covers it

  local findings_present=0 _ff
  if [[ -d "$FINDINGS_DIR" ]]; then
    for _ff in "$FINDINGS_DIR"/*.md; do
      [[ -f "$_ff" ]] && { findings_present=1; break; }
    done
  fi
  if [[ $findings_present -eq 1 ]]; then
    log_fail "ledger MANDATORY at $LEDGER_PATH — findings were fixed (findings/*.md present) and the ledger is the only re-detect proof surface (gap-count parity)."
    return 1
  fi
  return 0
}

# ── §679 — no hand-waves in the ranked plan ──────────────────────────────────
check_no_handwaves_audit_plan() {
  local file="$1" label="$2"
  [[ ! -f "$file" ]] && return 0
  local scrubbed handwaves
  scrubbed=$(mktemp -t audit-scrub.XXXXXX)
  _scrub_prose "$file" > "$scrubbed"
  # audit-specific hand-waves + the generic ones from the optimize validator.
  handwaves=$(grep -ciE 'would be slow|at scale this is bad|slow at scale|doesn'"'"'t scale|, etc\.| etc\.\)|\.\.\.[[:space:]]*$|and so on|N\+ items|many (modules|queries|endpoints)|by inspection' "$scrubbed" 2>/dev/null || true)
  rm -f "$scrubbed"
  handwaves=$(printf '%s' "${handwaves:-0}" | tr -cd '0-9'); handwaves=${handwaves:-0}
  if [[ "$handwaves" -gt 0 ]]; then
    log_fail "$label has $handwaves hand-wave(s) in $file — every finding needs a citation + measured/estimated impact"
    return 1
  fi
  log_pass "no hand-wave language in $label"
}

# ── Finding-block extraction: a block starts at a P0/P1/P2/P3 marker ──────────
# Emits "SEV<TAB>blocktext" per finding, joining lines until the next marker/heading.
_emit_finding_blocks() {
  local file="$1"
  [[ ! -f "$file" ]] && return 0
  awk '
    function flush() { if (sev != "") { gsub(/\t/," ",buf); print sev "\t" buf } }
    /(^|[^A-Za-z0-9])P[0-3]([^A-Za-z0-9]|$)/ {
      flush()
      if (match($0, /P[0-3]/)) sev = substr($0, RSTART, 2)
      buf = $0
      next
    }
    /^#{1,4} / { flush(); sev=""; buf=""; next }
    sev != "" { buf = buf " " $0 }
    END { flush() }
  ' "$file"
}

# ── §675 — every P0 cites a concrete scale failure mode ──────────────────────
check_p0_failure_mode_cited() {
  local file="$PLAN_PATH"
  [[ ! -f "$file" ]] && { log_warn "plan not found at $file — skipping P0 failure-mode check"; return 0; }
  local bad=0 total=0 sev block
  while IFS=$'\t' read -r sev block; do
    [[ "$sev" == "P0" ]] || continue
    total=$((total + 1))
    # Concrete failure mode = a mechanism word AND a quantified trigger.
    if echo "$block" | grep -qiE 'deadlock|livelock|lock contention|OOM|out of memory|exhaust|saturat|starv|back-?pressure|thundering herd|N\+1|connection pool|file descriptor|unbounded|amplif|cascad|timeout|p9[59]|tail latency|head-of-line' \
       && echo "$block" | grep -qiE '[0-9][0-9,]*[[:space:]]*(RPS|qps|req|users|rows|connections|MB|GB|ms)|[0-9]+[[:space:]]*[kKmM][[:space:]]|at[[:space:]]+[0-9]|under[[:space:]]+(load|concurrency)'; then
      :
    else
      log_fail "P0 finding lacks a concrete scale failure mode (mechanism + quantified trigger): ${block:0:120}…"
      bad=$((bad + 1))
    fi
  done < <(_emit_finding_blocks "$file")
  if [[ $total -eq 0 ]]; then log_warn "no P0 findings detected in $file"; return 0; fi
  [[ $bad -eq 0 ]] && log_pass "all $total P0 finding(s) cite a concrete scale failure mode"
  [[ $bad -gt 0 ]] && return 1 || return 0
}

# ── §641 (strict) — every P0/P1/P2 cites <file:line> ─────────────────────────
check_finding_citations() {
  local file="$PLAN_PATH"
  [[ ! -f "$file" ]] && return 0
  local bad=0 total=0 sev block
  while IFS=$'\t' read -r sev block; do
    case "$sev" in P0|P1|P2) ;; *) continue ;; esac
    total=$((total + 1))
    # Accept <path:line>, `path:line`, or path.ext:line.
    if echo "$block" | grep -qE '<[^>]+:[0-9]+>|`[^`]+:[0-9]+`|[A-Za-z0-9_./-]+\.[A-Za-z0-9]+:[0-9]+'; then
      :
    else
      log_warn "$sev finding lacks a <file:line> citation: ${block:0:120}…"
      bad=$((bad + 1))
    fi
  done < <(_emit_finding_blocks "$file")
  [[ $total -eq 0 ]] && return 0
  [[ $bad -eq 0 ]] && log_pass "all $total P0/P1/P2 finding(s) cite <file:line>"
  return 0
}

# ── final-report actionable next steps (same contract as optimize) ───────────
check_actionable_next_steps() {
  local report="$REPORT_PATH"
  [[ ! -f "$report" ]] && return 0
  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$report"; then
    log_fail "final-report missing '## Actionable next steps' at $report (see templates/snippets/actionable-next-steps.md)"
    return 1
  fi
  local extracted
  extracted=$(awk '/^##[[:space:]]+Actionable next steps/{s=1;next} s&&/^##[[:space:]]/{s=0} s{print}' "$report")
  if ! echo "$extracted" | grep -qE '^[[:space:]]*```'; then
    log_fail "actionable next steps has no bash fence at $report — commands must be paste-ready"
    return 1
  fi
  log_pass "final report ends with paste-ready actionable next steps"
}

# ── ledger gap parity (optional) ─────────────────────────────────────────────
check_ledger_gap_parity() {
  [[ ! -f "$LEDGER_PATH" ]] && return 0
  local bad
  bad=$(awk '
    function flush() {
      if (id!="" && (st=="verified"||st=="done"||st=="fixed")) {
        g1=gi; g2=gc; gsub(/[^0-9]/,"",g1); gsub(/[^0-9]/,"",g2)
        if (g1+0 != g2+0) print id":"g1"!="g2
      }
      id=""; gi=""; gc=""; st=""
    }
    /^id: /        { id=$2; gi=""; gc=""; st="" }
    /^status: /    { st=$2 }
    /^state: /     { if (st=="") st=$2 }
    /^gaps_in: /   { gi=$2 }
    /^gaps_closed: /{ gc=$2 }
    /^```/         { flush() }
    END            { flush() }
  ' "$LEDGER_PATH")
  if [[ -n "$bad" ]]; then
    log_fail "ledger rows with gaps_in != gaps_closed on terminal status: $bad"
    return 1
  fi
  log_pass "ledger gap-count parity holds for terminal rows"
}

usage() { sed -n '2,18p' "$0"; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan=*)         PLAN_PATH="${1#*=}"; shift ;;
    --report=*)       REPORT_PATH="${1#*=}"; shift ;;
    --ledger=*)       LEDGER_PATH="${1#*=}"; shift ;;
    --findings-dir=*) FINDINGS_DIR="${1#*=}"; shift ;;
    --strict)         STRICT=1; shift ;;
    --quiet|-q)       QUIET=1; shift ;;
    -h|--help)        usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

main() {
  log_section "Ranked plan — existence"
  check_plan_exists_when_output || true

  log_section "Ranked plan — hand-waves"
  check_no_handwaves_audit_plan "$PLAN_PATH" "audit plan" || true
  check_no_handwaves_audit_plan "$ASSESSMENT_PATH" "assessment" || true

  log_section "Findings — P0 failure mode + citations"
  check_p0_failure_mode_cited || true
  check_finding_citations || true

  log_section "Ledger rows (optional)"
  check_ledger_mandatory_when_findings || true
  check_ledger_gap_parity || true

  log_section "Final report — actionable next steps"
  check_actionable_next_steps || true

  echo
  echo "── Summary ──"
  echo "  checks passed: $TOTAL_PASS"
  echo "  checks failed: $TOTAL_FAIL"
  if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo; echo "Failures:"
    for f in "${FAILURES[@]}"; do echo "  - $f"; done
    exit 1
  fi
  exit 0
}

main "$@"
