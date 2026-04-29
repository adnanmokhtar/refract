#!/usr/bin/env bash
# audit-setup.sh — Phase 5 deterministic audit. Read the 4 reports + verify completeness.
#
# Solves the "agent forgot to run Phase 5 audit" risk: this is a single script the
# orchestrator MUST invoke at the end of every refresh/refine/enhance/migration run.
# Returns 0 if all checks pass; non-zero with a numbered report otherwise.
#
# Usage:
#   audit-setup.sh <target-repo> [--mode=refresh|refine|enhance|create]
#
# Exits:
#   0 — all checks pass; safe to report success
#   1 — at least one mandatory check failed; agent must NOT report success
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--mode=...]" >&2
  exit 2
fi

TARGET="$1"; shift
MODE="refresh"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#--mode=}"; shift ;;
    *)        shift ;;
  esac
done

CL="$TARGET/.claude"
fail=0
warn=0

err() { echo "  ERR  $*"; fail=$((fail + 1)); }
warn_msg() { echo "  WARN $*"; warn=$((warn + 1)); }
ok() { echo "  ok   $*"; }

echo "=== Phase 5 audit — target=$TARGET mode=$MODE ==="
echo ""

# C2b — required reports exist
echo "C2b: deterministic-coverage reports present"
for rpt in _pack-coverage-report.md _study-existing-report.md _codebase-scan.md; do
  if [[ -f "$CL/$rpt" ]]; then
    ok "$rpt"
  else
    err "$rpt missing — Phase 0.0 / Phase 4.0 didn't run"
  fi
done
if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
  if [[ -f "$CL/_refresh-extract.md" ]]; then
    ok "_refresh-extract.md (REFRESH/REFINE mode requires this)"
  else
    err "_refresh-extract.md missing — REFRESH/REFINE didn't run extract checklist"
  fi
fi
echo ""

# C2b — extract sections non-empty
if [[ -f "$CL/_refresh-extract.md" ]]; then
  echo "C2b: refresh-extract sections filled"
  for section in "ADRs preserved" "Validated user corrections" "Project intent" "Custom rules" "Custom agents" "Architecture decisions" "Detected stack"; do
    # Find section header, then check next non-empty non-blockquote line for <TBD>
    section_first_line=$(awk -v sec="$section" '
      $0 ~ "^## .*"sec"" { in_sec=1; next }
      in_sec && /^## / { exit }
      in_sec && /^>/ { next }
      in_sec && /^[[:space:]]*$/ { next }
      in_sec { print; exit }
    ' "$CL/_refresh-extract.md" 2>/dev/null || true)
    if echo "$section_first_line" | grep -q '<TBD>'; then
      err "_refresh-extract.md § \"$section\" is still <TBD>"
    else
      ok "_refresh-extract.md § \"$section\" filled"
    fi
  done
  # Section 9 only required when migration in scope
  if grep -q "include=migration\|migration_layout_detected" "$TARGET"/.claude/codebase-profile.md 2>/dev/null; then
    if awk '/^## 9\./ { in_sec=1; next } in_sec && /^## / { exit } in_sec && /^>/ { next } in_sec && /^[[:space:]]*$/ { next } in_sec { print; exit }' "$CL/_refresh-extract.md" | grep -q '<TBD>'; then
      err "_refresh-extract.md § 9 (migration mapping) is <TBD> but migration is in scope"
    fi
  fi
  echo ""
fi

# C2c — codebase-scan sections filled
if [[ -f "$CL/_codebase-scan.md" ]]; then
  echo "C2c: codebase-scan semantic sections filled"
  for section in "Module map" "Architecture pattern" "Conventions visible" "Patterns repeated" "Decisions implicit" "Drift between rules" "Stale references" "Recommended structural"; do
    section_first_line=$(awk -v sec="$section" '
      $0 ~ "^## .*"sec"" { in_sec=1; next }
      in_sec && /^## / { exit }
      in_sec && /^>/ { next }
      in_sec && /^[[:space:]]*$/ { next }
      in_sec { print; exit }
    ' "$CL/_codebase-scan.md" 2>/dev/null || true)
    if echo "$section_first_line" | grep -q '<TBD>'; then
      err "_codebase-scan.md § \"$section\" is <TBD>"
    else
      ok "_codebase-scan.md § \"$section\" filled"
    fi
  done

  # Section 15 must contain ≥3 structural recommendations
  recs=$(awk '
    /^## 15\./ { in_sec=1; next }
    in_sec && /^## / { exit }
    in_sec && /^- \*\*What\*\*:/ { count++ }
    END { print count + 0 }
  ' "$CL/_codebase-scan.md" 2>/dev/null || echo 0)
  recs="${recs:-0}"

  # Compute LOC from section 5 to gate "non-trivial" check
  loc_total=0
  if grep -q '^## 5\.' "$CL/_codebase-scan.md" 2>/dev/null; then
    loc_total=$({ awk '/^## 5\./ { in_sec=1; next } in_sec && /^## / { exit } in_sec' "$CL/_codebase-scan.md" 2>/dev/null || true; } \
      | { grep -oE '[0-9]+ lines' 2>/dev/null || true; } | { grep -oE '^[0-9]+' 2>/dev/null || true; } | awk '{s+=$1} END {print s+0}')
    loc_total="${loc_total:-0}"
  fi

  if [[ "$loc_total" -ge 1000 && "$recs" -lt 3 ]]; then
    err "_codebase-scan.md § 15 has $recs structural recommendations; minimum 3 required (LOC=$loc_total)"
  elif [[ "$loc_total" -lt 1000 ]]; then
    ok "_codebase-scan.md § 15 has $recs recommendations (small codebase, threshold relaxed)"
  else
    ok "_codebase-scan.md § 15 has $recs structural recommendations"
  fi
  echo ""
fi

# Pack coverage — every "Missing" row should be addressed (now present in target)
if [[ -f "$CL/_pack-coverage-report.md" ]]; then
  echo "C2b: pack coverage — Missing rows addressed"
  # Extract every "Missing" target path; check that each file now exists
  missing_unaddressed=0
  while IFS= read -r line; do
    # Lines look like: "- `<target-rel-path>` ← from `<src>`"
    target_rel=$(echo "$line" | sed -nE 's/^- `([^`]+)` ← from .*/\1/p')
    [[ -z "$target_rel" ]] && continue
    if [[ ! -f "$TARGET/$target_rel" ]]; then
      err "pack-coverage said missing → $target_rel still missing in target"
      missing_unaddressed=$((missing_unaddressed + 1))
    fi
  done < <(grep -E '^- `' "$CL/_pack-coverage-report.md" | grep '← from')
  [[ "$missing_unaddressed" -eq 0 ]] && ok "all 'Missing' rows addressed (or no missing rows)"
  echo ""
fi

# Anchoring audit (M25.4): per-artifact coverage of the canonical
# `<!-- project-specific:start --> ... :end -->` block + `path:line` citations.
# REFUSE when anchors are missing in REFRESH / REFINE / ENHANCE modes (Phase 4.6
# was supposed to inject them via apply-anchors.sh). CREATE mode warns only —
# the agent may still be mid-flow when this runs and the profile may not exist.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPTS_DIR/audit-anchoring.sh" ]]; then
  echo "C2d: artifact anchoring"
  "$SCRIPTS_DIR/audit-anchoring.sh" "$TARGET" --quiet >/dev/null 2>&1 || true
  if [[ -f "$CL/_anchoring-audit.md" ]]; then
    pct=$(grep -E '^Coverage: \*\*' "$CL/_anchoring-audit.md" 2>/dev/null \
          | grep -oE '[0-9]+' | head -1 || true)
    unanchored=$(grep -E '^Unanchored:' "$CL/_anchoring-audit.md" 2>/dev/null \
                 | grep -oE '[0-9]+$' | head -1 || true)
    # When audit-anchoring.sh detects 0 pack-derived files, no `Coverage:` line is
    # emitted (audit-anchoring.sh:180-183 only writes it when total_eligible > 0).
    # Treat that case as a pass: every eligible artifact is anchored when there
    # are zero eligible artifacts.
    if [[ -z "$pct" ]] && grep -qE '^Pack-derived artifacts:[[:space:]]+\*\*0\*\*' "$CL/_anchoring-audit.md" 2>/dev/null; then
      ok "anchoring coverage n/a — 0 pack-derived artifacts (all are project-specific orphans)"
    fi
    if [[ -n "$pct" ]]; then
      if [[ "$unanchored" == "0" ]]; then
        ok "anchoring coverage ${pct}% — every pack-derived artifact carries an anchor block"
      elif [[ "$MODE" == "create" ]]; then
        warn_msg "anchoring coverage ${pct}% — ${unanchored} unanchored (CREATE mode; Phase 4.6 may not have run yet — re-run apply-anchors.sh)"
      else
        err "anchoring coverage ${pct}% — ${unanchored} pack-derived artifact(s) lack project anchors. Phase 4.6 must run: ~/.claude/scripts/apply-anchors.sh \"$TARGET\" --apply"
      fi
    fi
  fi
  echo ""
fi

# Summary
echo "=== summary ==="
echo "fail: $fail"
echo "warn: $warn"

if [[ "$fail" -gt 0 ]]; then
  echo ""
  echo "REFUSED — $fail mandatory check(s) failed."
  echo "The agent MUST NOT declare 'no work to do' / 'idempotent' / 'success' until these are addressed."
  exit 1
fi

echo ""
echo "PASS — Phase 5 audit clean. Safe to report success."
exit 0
