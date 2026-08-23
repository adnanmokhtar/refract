#!/usr/bin/env bash
# migration-doctor.sh — cross-repo migration health check.
#
# Walks every workspace-registered repo that has ai/migration/ledger.md, runs
# validate-migration-artifacts.sh --all per repo, aggregates results.
#
# Usage:
#   migration-doctor.sh [--workspace=<dir>] [--strict] [--quiet]
#
# Defaults to current directory as workspace root. Reads PROJECTS.md (or
# falls back to scanning sibling directories) for the repo list.
#
# Exit codes:
#   0  — all repos green
#   1  — at least one repo has failures
#   2  — usage / no repos found

set -euo pipefail
export LC_ALL=C

WORKSPACE="$(pwd)"
STRICT=0
QUIET=0
# Resolve validator relative to this script (works regardless of whether the
# script is run from a sync'd ~/.claude or directly from the repo).
# Symlink-resolved: ~/.claude/scripts/<name> links into this repo, so an unresolved
# BASH_SOURCE puts this dir at ~/.claude/scripts and every sibling asset below resolves only
# if it too was linked (see CONTRIBUTING § "Scripts run from two places").
# Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SCRIPT_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd
VALIDATOR="$SCRIPT_DIR/validate-migration-artifacts.sh"
[[ -x "$VALIDATOR" ]] || VALIDATOR="${HOME}/.claude/scripts/validate-migration-artifacts.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace=*) WORKSPACE="${1#--workspace=}"; shift ;;
    --strict)      STRICT=1; shift ;;
    --quiet)       QUIET=1; shift ;;
    --validator=*) VALIDATOR="${1#--validator=}"; shift ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -x "$VALIDATOR" ]]; then
  echo "FATAL: validator not found / not executable at $VALIDATOR" >&2
  exit 2
fi

# ── Discover repos ─────────────────────────────────────────────────────────
discover_repos() {
  # Strategy 1: parse PROJECTS.md table for repo names
  if [[ -f "$WORKSPACE/PROJECTS.md" ]]; then
    # Extract repo names from PROJECTS.md table — path is the 3rd `|`-delimited
    # column (after the row number), surrounded by backticks. Format:
    #   | 1 | `<backend-v1>/` | API v1 ... |
    awk -F'|' '
      /\|[[:space:]]*`[a-z0-9_-]+\/`[[:space:]]*\|/ {
        for (i=2; i<=NF; i++) {
          if (match($i, /`[a-z0-9_-]+\/`/)) {
            s = substr($i, RSTART+1, RLENGTH-2)
            sub(/\/$/, "", s)
            print s
            break
          }
        }
      }
    ' "$WORKSPACE/PROJECTS.md" 2>/dev/null | sort -u
  else
    # Strategy 2: scan subdirectories that look like git repos with ai/migration/.
    # The ledger sits at <repo>/ai/migration/ledger.md — 4 path components below the
    # workspace root (repo/ai/migration/ledger.md), so -maxdepth must be ≥4 or the
    # find matches zero repos. (Was 2 → silently found nothing.)
    find "$WORKSPACE" -maxdepth 4 -name 'ledger.md' -path '*/ai/migration/*' 2>/dev/null \
      | sed -E 's|/ai/migration/ledger.md$||' \
      | sed -E "s|^${WORKSPACE}/||" \
      | sort -u
  fi
}

# ── Per-repo validate ──────────────────────────────────────────────────────
validate_repo() {
  local repo="$1"
  local repo_path="$WORKSPACE/$repo"
  local ledger="$repo_path/ai/migration/ledger.md"

  if [[ ! -d "$repo_path" ]]; then
    echo "SKIP $repo (path not found at $repo_path)"
    return 0
  fi
  if [[ ! -f "$ledger" ]]; then
    echo "SKIP $repo (no migration ledger — not a migration target)"
    return 0
  fi

  local out exitcode
  # Run validator inside the repo (subshell — never cd in main shell). Capture the REAL
  # exit status: no `|| true` swallow (that pinned $? to 0 and let a failing validator
  # report HEALTHY). `set -e` is disabled around the capture so a nonzero exit doesn't
  # abort the doctor before we can read + act on $?.
  set +e
  out=$( cd "$repo_path" && "$VALIDATOR" --all --quiet 2>&1 )
  exitcode=$?
  set -e
  local features pass fail
  features=$(echo "$out" | grep -E '^[[:space:]]*features checked:' | awk -F: '{print $2}' | tr -d ' ' || echo 0)
  pass=$(echo "$out"     | grep -E '^[[:space:]]*checks passed:'    | awk -F: '{print $2}' | tr -d ' ' || echo 0)
  fail=$(echo "$out"     | grep -E '^[[:space:]]*checks failed:'    | awk -F: '{print $2}' | tr -d ' ' || echo 0)
  features=${features:-0}; pass=${pass:-0}; fail=${fail:-0}
  printf "  %-22s | %8s | %4s | %6s\n" "$repo" "$features" "$pass" "$fail"
  # Fail the repo on a nonzero validator exit OR a parsed failure count > 0. The exit
  # status is authoritative: env errors (exit 3) and unparseable output still fail here
  # even when the summary line that feeds $fail is absent.
  if [[ "$exitcode" -ne 0 ]] || [[ ${fail:-0} -gt 0 ]]; then
    if [[ "$exitcode" -ne 0 && ${fail:-0} -eq 0 ]]; then
      echo "    [$repo] validator exited $exitcode (no failure summary parsed — env/usage error?)"
    fi
    echo "$out" | grep -E '^[[:space:]]*✗|Failures:' | sed "s|^|    [$repo] |" | head -20
    return 1
  fi
  return 0
}

# ── Cross-repo dependency check ────────────────────────────────────────────
check_cross_repo_deps() {
  # Parse each ledger row's `dependency:` field; resolve cross-repo refs.
  # A row like `dependency: <backend-v2>:auth-login` means: the other repo's
  # `auth-login` row must be `done` OR `intentional-break`.
  local repos="$1"
  local violations=0
  for repo in $repos; do
    local ledger="$WORKSPACE/$repo/ai/migration/ledger.md"
    [[ ! -f "$ledger" ]] && continue
    while IFS= read -r dep_line; do
      [[ -z "$dep_line" ]] && continue
      local dep_repo dep_feature
      dep_repo=$(echo "$dep_line" | awk -F: '{print $1}' | tr -d ' ')
      dep_feature=$(echo "$dep_line" | awk -F: '{print $2}' | tr -d ' ')
      [[ -z "$dep_repo" ]] || [[ -z "$dep_feature" ]] && continue
      # Look up dep_feature in dep_repo's ledger
      local dep_ledger="$WORKSPACE/$dep_repo/ai/migration/ledger.md"
      if [[ ! -f "$dep_ledger" ]]; then
        echo "  ✗ $repo depends on $dep_repo:$dep_feature — sibling ledger not found at $dep_ledger"
        violations=$((violations + 1))
        continue
      fi
      local dep_status
      dep_status=$(awk -v wanted="$dep_feature" '
        /^[[:space:]]*(- )?id: F[0-9]+[a-z]?[[:space:]]*$/ {
          if (in_block) try_emit()
          feat=""; status=""
          in_block = 1
          next
        }
        /^```/ {
          try_emit()
          feat=""; status=""
          in_block = 0
          next
        }
        in_block && /^[[:space:]]*feature: / { feat = $2; next }
        in_block && /^[[:space:]]*status: / { status = $2; next }
        in_block && /^[[:space:]]*state: / { if (status == "") status = $2; next }
        function try_emit() {
          if (feat == wanted && status != "") { print status; exit }
        }
        END { if (in_block) try_emit() }
      ' "$dep_ledger")
      if [[ "$dep_status" != "done" ]] && [[ "$dep_status" != "intentional-break" ]]; then
        echo "  ✗ $repo depends on $dep_repo:$dep_feature (status=$dep_status — blocker)"
        violations=$((violations + 1))
      else
        echo "  ✓ $repo depends on $dep_repo:$dep_feature ($dep_status)"
      fi
    done < <(grep -E '^[[:space:]]*dependenc(y|ies):' "$ledger" 2>/dev/null | sed -E 's/^[[:space:]]*dependenc(y|ies):[[:space:]]*//' | tr -d '"' | tr -d "'")
  done
  return $violations
}

# ── Date → epoch (tolerant) ─────────────────────────────────────────────────
# Parse an ISO-ish audit_date to epoch seconds across BSD (macOS) and GNU (CI) date,
# accepting: a literal `Z`, a numeric offset (`+02:00` / `-0500`), OR a bare datetime,
# AND a date-only value (`YYYY-MM-DD`). The old parser hard-coded a trailing-Z format
# string, so offset/date-only audits parsed to epoch 0 and the stale check was silently
# skipped on macOS. Echoes epoch seconds, or 0 if genuinely unparseable.
parse_date_epoch() {
  local raw="$1" norm
  norm="$raw"
  norm="${norm%Z}"                       # drop a trailing Z
  # drop a trailing numeric offset (+02:00 / -0500) — only when a time part is present,
  # so the date's own '-' separators are never eaten.
  case "$norm" in
    *T*) norm="$(printf '%s' "$norm" | sed -E 's/([+-][0-9]{2}:?[0-9]{2})$//')" ;;
  esac
  # BSD: date -j -f <fmt>. Try datetime (with/without seconds) then date-only.
  if [[ "$norm" == *T* ]]; then
    case "$norm" in
      *T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]) date -j -f "%Y-%m-%dT%H:%M:%S" "$norm" +%s 2>/dev/null && return 0 ;;
      *T[0-9][0-9]:[0-9][0-9])            date -j -f "%Y-%m-%dT%H:%M"    "$norm" +%s 2>/dev/null && return 0 ;;
    esac
  else
    date -j -f "%Y-%m-%d" "$norm" +%s 2>/dev/null && return 0
  fi
  # GNU fallback (CI / Linux): date -d handles all of the above (and the raw offset/Z).
  date -d "$raw" +%s 2>/dev/null && return 0
  echo 0
}

# ── Stale audit aggregate ──────────────────────────────────────────────────
check_stale_audits() {
  local repos="$1"
  local stale=0
  for repo in $repos; do
    local audits_dir="$WORKSPACE/$repo/ai/migration/audits"
    [[ ! -d "$audits_dir" ]] && continue
    while IFS= read -r audit; do
      local audit_date
      audit_date=$(grep -m1 '^audit_date:' "$audit" 2>/dev/null | sed 's/^audit_date:[[:space:]]*//' | tr -d '"' | tr -d "'")
      [[ -z "$audit_date" ]] && continue
      local audit_epoch now_epoch diff_days
      audit_epoch=$(parse_date_epoch "$audit_date")
      now_epoch=$(date +%s)
      if [[ $audit_epoch -eq 0 ]]; then
        echo "  ⚠ $repo:$(basename "$audit") could not parse audit_date=$audit_date — stale check skipped"
        continue
      fi
      diff_days=$(( (now_epoch - audit_epoch) / 86400 ))
      if [[ $diff_days -gt 30 ]]; then
        echo "  ⚠ $repo:$(basename "$audit") audit_date=$audit_date ($diff_days days old) — re-audit recommended"
        stale=$((stale + 1))
      fi
    done < <(find "$audits_dir" -maxdepth 1 -name '*.md' ! -name 'phase-*.md' ! -name '*-relook.md' 2>/dev/null)
  done
  [[ $stale -gt 0 ]] && return 1
  return 0
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  if [[ $QUIET -eq 0 ]]; then
    echo "migration-doctor — cross-repo health check"
    echo "  workspace: $WORKSPACE"
    echo "  validator: $VALIDATOR"
    echo
  fi

  local repos
  repos=$(discover_repos)
  if [[ -z "$repos" ]]; then
    echo "FATAL: no repos found. Workspace must contain PROJECTS.md OR sibling repos with ai/migration/ledger.md" >&2
    exit 2
  fi

  if [[ $QUIET -eq 0 ]]; then
    echo "Per-repo validator:"
    printf "  %-22s | %8s | %4s | %6s\n" "Repo" "Features" "Pass" "Failed"
    echo "  ---------------------- | -------- | ---- | ------"
  fi

  local total_failures=0
  for repo in $repos; do
    if ! validate_repo "$repo"; then
      total_failures=$((total_failures + 1))
    fi
  done

  local cross_rc=0 stale_rc=0
  echo
  echo "Cross-repo dependencies:"
  check_cross_repo_deps "$repos" || cross_rc=1

  echo
  echo "Stale audits (>30 days):"
  check_stale_audits "$repos" || stale_rc=1

  echo
  if [[ $total_failures -eq 0 && $cross_rc -eq 0 && $stale_rc -eq 0 ]]; then
    echo "Verdict: HEALTHY"
    exit 0
  else
    [[ $cross_rc -ne 0 ]] && echo "Verdict: UNHEALTHY — cross-repo dependency violations (see above)" >&2
    [[ $stale_rc -ne 0 ]] && echo "Verdict: UNHEALTHY — stale audits (>30 days) detected" >&2
    [[ $total_failures -ne 0 ]] && echo "Verdict: $total_failures repo(s) validator failures — fix before phase advance" >&2
    exit 1
  fi
}

main "$@"
