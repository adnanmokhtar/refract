#!/usr/bin/env bash
# validate-refactor-artifacts.sh — mechanical gates for /refactor ledger rows.
#
# Usage:
#   validate-refactor-artifacts.sh [--ledger=PATH] [--findings-dir=PATH]
#   validate-refactor-artifacts.sh [--strict] [--quiet] [--phase-base=<git-ref>]
#   validate-refactor-artifacts.sh --self-test
#
# Exit: 0 pass, 1 failures, 2 usage

set -euo pipefail
export LC_ALL=C

# Symlink-resolved (Rule 10) — see CONTRIBUTING § "Scripts run from two places".
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
THIS_SCRIPT="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"; unset _ss _sd

LEDGER_PATH="${LEDGER_PATH:-ai/refactor/ledger.md}"
FINDINGS_DIR="${FINDINGS_DIR:-ai/refactor/findings}"

STRICT=0
QUIET=0
PHASE_BASE=""
SELF_TEST=0

TOTAL_PASS=0
TOTAL_FAIL=0
FAILURES=()

log_pass() {
  TOTAL_PASS=$((TOTAL_PASS + 1))
  [[ $QUIET -eq 0 ]] && echo "  ✓ $1" || true
}

log_fail() {
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
  FAILURES+=("$1")
  echo "  ✗ $1" >&2
}

log_warn() {
  if [[ $STRICT -eq 1 ]]; then
    log_fail "[strict] $1"
  elif [[ $QUIET -eq 0 ]]; then
    echo "  ⚠ $1"
  fi
}

log_section() {
  [[ $QUIET -eq 0 ]] && echo && echo "── $1 ──" || true
}

is_valid_refactor_verb() {
  case "${1:-}" in
    extract-method|extract-class|extract-param-object|flatten-conditional|move-to-module|replace-magic-with-constant|replace-temp-with-query|replace-loop-with-pipeline|rename|encapsulate)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

is_terminal_status() {
  case "${1:-}" in
    verified|done|fixed)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Same fenced-YAML row shape as validate-optimize-artifacts.sh (id: blocks).
discover_refactor_rows() {
  awk '
    function emit() {
      if (id != "") print id "|" class "|" status "|" gaps_in "|" gaps_closed "|" verb
    }
    /^id: [A-Za-z0-9][A-Za-z0-9_-]*$/ {
      if (id != "") emit()
      id = $2
      class = ""; status = ""; gaps_in = ""; gaps_closed = ""; verb = ""
      in_block = 1
      next
    }
    /^```/ {
      if (in_block) emit()
      id = ""; class = ""; status = ""; gaps_in = ""; gaps_closed = ""; verb = ""
      in_block = 0
      next
    }
    in_block && /^status: / { status = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", status); next }
    in_block && /^state: / {
      if (status == "") { status = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", status) }
      next
    }
    in_block && /^class: / {
      class = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", class)
      next
    }
    in_block && /^gaps_in: / { gaps_in = $2; next }
    in_block && /^gaps_closed: / { gaps_closed = $2; next }
    in_block && /^closure_verb:/ {
      verb = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", verb)
      next
    }
    END { if (id != "") emit() }
  ' "$LEDGER_PATH"
}

check_no_handwaves_file() {
  local label="$1"
  local file="$2"
  [[ ! -f "$file" ]] && return 0

  local scrubbed handwaves
  scrubbed=$(mktemp -t refactor-scrub.XXXXXX)
  awk '
    BEGIN { inf = 0 }
    /^```/ { inf = 1 - inf; next }
    inf { next }
    {
      gsub(/`[^`]*`/, "")
      print
    }
  ' "$file" > "$scrubbed"
  # BSD grep: -c prints 0 but exits 1 when count is 0 — do not chain || echo 0 (duplicates "0").
  handwaves=$(grep -cE '\.\.\.[[:space:]]*$|, etc\.| etc\.\)|\band so on\b|\bby inspection\b' "$scrubbed" 2>/dev/null || true)
  rm -f "$scrubbed"
  handwaves=$(echo "$handwaves" | tail -1)
  handwaves=${handwaves:-0}

  if [[ "$handwaves" -gt 0 ]]; then
    log_fail "$label has $handwaves hand-wave(s) in $file"
    return 1
  fi
  log_pass "no hand-wave language in $label"
  return 0
}

check_gap_count_parity() {
  local id="$1" status="$2" gin="$3" gcl="$4"

  if ! is_terminal_status "$status"; then
    log_pass "$id: gap parity N/A (non-terminal status $status)"
    return 0
  fi

  local gi gc
  gi=$(echo "$gin" | tr -cd '0-9')
  gc=$(echo "$gcl" | tr -cd '0-9')
  gi=${gi:-0}
  gc=${gc:-0}

  if [[ "$gi" != "$gc" ]]; then
    log_fail "$id: gaps_in ($gi) != gaps_closed ($gc) — cannot advance to $status"
    return 1
  fi
  log_pass "$id: gap-count parity ($gi == $gc) for terminal status"
  return 0
}

_git_net_for_row() {
  local id="$1"
  local commits_shas added removed sha stat a r
  local range=()
  [[ -n "${PHASE_BASE:-}" ]] && range=("${PHASE_BASE}..HEAD")
  commits_shas=$(git log --grep="${id}:" --grep="refactor/${id}:" --format='%H' "${range[@]}" 2>/dev/null || true)
  added=0
  removed=0
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    stat=$(git show --shortstat "$sha" 2>/dev/null | tail -1 || true)
    a=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    r=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
    added=$((added + ${a:-0}))
    removed=$((removed + ${r:-0}))
  done <<< "$commits_shas"
  echo "$added $removed ${commits_shas:-}"
}

check_net_lines_refactoring() {
  local id="$1" cls="$2"

  if [[ "$cls" != "refactoring" ]]; then
    log_pass "$id: class '$cls' — refactoring net-lines rule N/A"
    return 0
  fi
  if [[ -z "${PHASE_BASE:-}" ]]; then
    log_warn "$id: --phase-base not provided; skipping structural net-lines check"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_warn "$id: git not on PATH; skipping structural net-lines check"
    return 0
  fi

  local added removed commits net
  read -r added removed commits <<< "$(_git_net_for_row "$id")"
  if [[ -z "$commits" ]]; then
    log_warn "$id: no commits matched grep '${id}:' / 'refactor/${id}:' — skipping net-lines"
    return 0
  fi

  net=$((added - removed))
  if (( net <= 0 )); then
    log_pass "$id: refactoring net-lines = $net (added=$added, removed=$removed)"
  else
    log_fail "$id: refactoring net-lines = $net > 0 — re-classify or justify in findings; route to /optimize if architectural"
  fi
}

check_actionable_next_steps() {
  # Per templates/snippets/actionable-next-steps.md: if a final-report.md exists,
  # it MUST end with an `## Actionable next steps` section containing paste-ready
  # commands for every deferred / out-of-scope finding.
  local report="${1:-ai/refactor/final-report.md}"
  [[ ! -f "$report" ]] && return 0

  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$report"; then
    log_fail "final-report missing '## Actionable next steps' section at $report — every deferred finding MUST be a paste-ready command (see templates/snippets/actionable-next-steps.md)"
    return 1
  fi

  local extracted bad=0
  extracted=$(awk '
    /^##[[:space:]]+Actionable next steps/ { in_sec=1; next }
    in_sec && /^##[[:space:]]/ { in_sec=0 }
    in_sec { print }
  ' "$report")

  if ! echo "$extracted" | grep -qE '^[[:space:]]*```'; then
    log_fail "actionable next steps section has no bash fence at $report — commands must be inside \`\`\`bash\`\`\` so they are paste-ready"
    return 1
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*/[a-z-]+ ]] || continue
    local clean args arg_count
    clean=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    args=$(echo "$clean" | cut -s -d' ' -f2-)
    arg_count=$(echo "$args" | wc -w | tr -d ' ')
    [[ "$arg_count" == "0" ]] && continue
    [[ "$arg_count" == "1" ]] && continue
    if echo "$args" | grep -qE '/|=|--|\.[a-zA-Z]+'; then
      continue
    fi
    log_fail "actionable next-step line looks like prose, not a paste-ready command (no path / flag / extension marker): $line"
    bad=$((bad + 1))
  done <<< "$extracted"

  [[ $bad -gt 0 ]] && return 1
  log_pass "final report ends with paste-ready actionable next steps"
  return 0
}

check_closure_verb() {
  local id="$1" verb="$2"

  if [[ -z "$verb" ]]; then
    log_fail "$id: closure_verb missing — set one of the 10 refactoring-sweep verbs"
    return 1
  fi
  if is_valid_refactor_verb "$verb"; then
    log_pass "$id: closure_verb '$verb' ∈ refactoring vocabulary"
    return 0
  fi
  log_fail "$id: closure_verb '$verb' NOT in refactoring vocabulary — re-classify; route to /optimize (e.g. parallelize, split-god-module)"
  return 1
}

validate_refactor_row() {
  local line="$1"
  local id cls status gin gcl verb
  IFS='|' read -r id cls status gin gcl verb <<< "$line"

  [[ -z "$id" ]] && return 0

  log_section "ledger row $id"

  check_closure_verb "$id" "$verb" || true
  check_gap_count_parity "$id" "$status" "$gin" "$gcl" || true
  check_net_lines_refactoring "$id" "$cls" || true

  local ffile="$FINDINGS_DIR/${id}.md"
  if [[ -f "$ffile" ]]; then
    check_no_handwaves_file "findings/$id" "$ffile" || true
  fi
}

scan_findings_handwaves() {
  [[ ! -d "$FINDINGS_DIR" ]] && return 0
  local f
  shopt -s nullglob
  for f in "$FINDINGS_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    check_no_handwaves_file "findings/$(basename "$f")" "$f" || true
  done
  shopt -u nullglob
}

usage() {
  sed -n '2,12p' "$0"
  exit 2
}

run_self_test() {
  local td repo_root
  # Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
  # § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
  _ss="${BASH_SOURCE[0]}"
  while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
  repo_root="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
  mkdir -p "$repo_root/tmp"
  td=$(mktemp -d "$repo_root/tmp/refactor-selftest.XXXXXX")
  mkdir -p "$td/ai/refactor/findings"
  cat > "$td/ai/refactor/ledger.md" <<'EOF'
id: RF001
class: refactoring
status: verified
gaps_in: 1
gaps_closed: 1
closure_verb: extract-method
```
EOF
  echo "Mirror sibling helper per _extracted-idioms.md." > "$td/ai/refactor/findings/RF001.md"
  # Note: avoid `--quiet` on nested bash — macOS bash + pipefail can exit non-zero without stderr on `< <(discover_* rows)`.
  if ! ( cd "$td" && LEDGER_PATH="$td/ai/refactor/ledger.md" FINDINGS_DIR="$td/ai/refactor/findings" \
      bash "$THIS_SCRIPT" >/dev/null 2>&1 ); then
    rm -rf "$td"
    echo "self-test FAIL: expected pass case" >&2
    exit 1
  fi
  rm -rf "$td"

  td=$(mktemp -d "$repo_root/tmp/refactor-selftest.XXXXXX")
  mkdir -p "$td/ai/refactor"
  cat > "$td/ai/refactor/ledger.md" <<'EOF'
id: BAD001
class: refactoring
status: verified
gaps_in: 1
gaps_closed: 1
closure_verb: parallelize
```
EOF
  if ( cd "$td" && LEDGER_PATH="$td/ai/refactor/ledger.md" bash "$THIS_SCRIPT" >/dev/null 2>&1 ); then
    rm -rf "$td"
    echo "self-test FAIL: expected failure on invalid verb" >&2
    exit 1
  fi
  rm -rf "$td"

  echo "validate-refactor-artifacts.sh --self-test OK"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ledger=*)       LEDGER_PATH="${1#*=}"; shift ;;
    --findings-dir=*) FINDINGS_DIR="${1#*=}"; shift ;;
    --strict)         STRICT=1; shift ;;
    --quiet|-q)       QUIET=1; shift ;;
    --phase-base=*)   PHASE_BASE="${1#*=}"; shift ;;
    --self-test)      SELF_TEST=1; shift ;;
    -h|--help)        usage ;;
    *)
      echo "Unknown argument: $1" >&2
      usage ;;
  esac
done

if [[ $SELF_TEST -eq 1 ]]; then
  run_self_test
fi

main() {
  log_section "Ledger rows"
  if [[ ! -f "$LEDGER_PATH" ]]; then
    # findings present → ledger MANDATORY (ported from validate-optimize). The
    # ledger is the only re-detect proof surface (gap-count parity); a run that
    # FIXED findings without one cannot prove parity.
    local _findings_present=0 _ff
    if [[ -d "$FINDINGS_DIR" ]]; then
      shopt -s nullglob
      for _ff in "$FINDINGS_DIR"/*.md; do
        [[ -f "$_ff" ]] && { _findings_present=1; break; }
      done
      shopt -u nullglob
    fi
    if [[ $STRICT -eq 1 ]]; then
      log_fail "[strict] ledger required at $LEDGER_PATH"
    elif [[ $_findings_present -eq 1 ]]; then
      log_fail "ledger MANDATORY at $LEDGER_PATH — findings were fixed (findings/*.md present) and the ledger is the only re-detect proof surface (gap-count parity)."
    else
      log_warn "ledger not found at $LEDGER_PATH — skipping per-row checks"
    fi
  else
    local row _rows
    # Avoid `< <(discover_refactor_rows)` — bash 3 / pipefail can fault on function-in-process-substitution.
    _rows=$(discover_refactor_rows || true)
    while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      validate_refactor_row "$row" || true
    done <<< "$_rows"
  fi

  log_section "Findings directory hand-waves"
  scan_findings_handwaves || true

  log_section "Final report — actionable next steps"
  check_actionable_next_steps "ai/refactor/final-report.md" || true

  echo
  echo "── Summary ──"
  echo "  checks passed: $TOTAL_PASS"
  echo "  checks failed: $TOTAL_FAIL"

  if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
    exit 1
  fi
  exit 0
}

main "$@"
