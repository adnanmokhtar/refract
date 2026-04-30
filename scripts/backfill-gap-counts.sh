#!/usr/bin/env bash
# Backfill gaps_in / gaps_closed fields on done ledger rows that pre-date the
# gap-count parity rule (added 2026-04-30). For each `status: done` row that
# lacks the fields, reads the audit's gap inventory and inserts the matching
# gaps_in / gaps_closed values.
#
# Strategy:
# 1. Find rows with status=done AND missing gaps_in/gaps_closed
# 2. For each, read the row's audit file and count gaps
# 3. If audit's classification is "parity-clean" or marks gaps as closed → set
#    gaps_in == gaps_closed == <count>
# 4. If audit shows open/divergent gaps → leave fields blank, halt that row
#    (user must investigate)
#
# Usage:
#   backfill-gap-counts.sh [--dry-run]
#
# Run from a project root that has ai/migration/ledger.md.

set -euo pipefail
export LC_ALL=C

LEDGER_PATH="ai/migration/ledger.md"
AUDITS_DIR="ai/migration/audits"
DRY_RUN=0
VERBOSE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --verbose|-v) VERBOSE=1 ;;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0
      ;;
  esac
done

[[ ! -f "$LEDGER_PATH" ]] && { echo "FATAL: $LEDGER_PATH not found. Run from a project root."; exit 2; }
[[ ! -d "$AUDITS_DIR" ]] && { echo "WARNING: $AUDITS_DIR not found — no audits to read."; }

# Find rows with status=done lacking gaps_in (bash 3-compatible — no mapfile)
target_rows=()
while IFS= read -r line; do
  [[ -n "$line" ]] && target_rows+=("$line")
done < <(
  awk '
    /^id: F[0-9]+[a-z]?$/ {
      if (id != "" && status == "done" && gaps_in == "") {
        print id "|" feature
      }
      id=$2; feature=""; status=""; gaps_in=""
      next
    }
    /^feature: / { feature=$2 }
    /^status: /  { status=$2 }
    /^gaps_in: / { gaps_in=$2 }
    END {
      if (id != "" && status == "done" && gaps_in == "") print id "|" feature
    }
  ' "$LEDGER_PATH"
)

echo "Found ${#target_rows[@]} done rows missing gaps_in / gaps_closed."
[[ ${#target_rows[@]} -eq 0 ]] && exit 0

backfilled=0
skipped=0
halted=0

for row in "${target_rows[@]}"; do
  id="${row%|*}"
  feature="${row#*|}"
  audit=""
  for cand in "$AUDITS_DIR/${id}-${feature}.md" "$AUDITS_DIR/${feature}.md"; do
    if [[ -f "$cand" ]]; then audit="$cand"; break; fi
  done
  # Sub-feature fallback: if row has `parent: FNNN`, fall back to the parent's audit
  if [[ -z "$audit" ]]; then
    parent=$(awk -v id="$id" '
      $0 ~ ("^id: " id "$") { in_block=1; next }
      in_block && /^parent:[[:space:]]/ { sub(/^parent:[[:space:]]*/, "", $0); print $0; exit }
      in_block && /^id:|^```$/ { exit }
    ' "$LEDGER_PATH" 2>/dev/null | tr -d ' \r')
    if [[ -n "$parent" ]]; then
      parent_audit=$(ls "$AUDITS_DIR/${parent}-"*.md 2>/dev/null | head -1)
      if [[ -n "$parent_audit" ]] && [[ -f "$parent_audit" ]]; then
        audit="$parent_audit"
      fi
    fi
  fi
  if [[ -z "$audit" ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "  ▸ $id ($feature): audit MISSING — skipped (cannot backfill)"
    ((skipped++))
    continue
  fi
  # Count gaps mentioned in audit. Heuristics in order:
  # 1. Prefer the "gaps_in: <N>" hint inside the audit body (some audits already document it)
  # 2. Otherwise count Gap headers / G1/G2/... markers / HALT-N rows
  gap_count=$(awk '/^gaps_in:/ { print $2; found=1; exit } END { if (!found) exit 1 }' "$audit" 2>/dev/null || true)
  if [[ -z "$gap_count" ]] || ! [[ "$gap_count" =~ ^[0-9]+$ ]]; then
    gap_count=$(grep -cE '^(### |#### )?(Gap [0-9]+|G[0-9]+\b|HALT-[0-9]+\b)' "$audit" 2>/dev/null || echo 0)
  fi
  # Final sanitize: must be a non-negative integer
  [[ "$gap_count" =~ ^[0-9]+$ ]] || gap_count=0
  # Check audit classification
  classification=$(awk '/^## Classification/{found=1; next} found && NF{print; exit}' "$audit" 2>/dev/null | tr -d '*' | sed 's/^[[:space:]]*//')
  if [[ -z "$classification" ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "  ▸ $id ($feature): no Classification section — halt for manual review"
    ((halted++))
    continue
  fi
  # Auto-backfill when:
  # (a) classification declares clean/closed/post-fix/resolved, OR
  # (b) audit body contains an explicit "all N gaps closed" / "N/N closed" marker, OR
  # (c) status=done AND audit lists no gaps (gap_count==0) — nothing to backfill, set 0/0
  is_clean=0
  if echo "$classification" | grep -qiE 'parity-?clean|^pass\b|all .* gaps closed|post-fix|RESOLVED|\(resolved\)|→[[:space:]]*parity-clean'; then
    is_clean=1
  elif echo "$classification" | grep -qiE 'auto-stub|pre-format-4'; then
    # Auto-stub Classification: defer to ledger status. Row is status=done → backfill from gap_count.
    is_clean=1
  elif grep -qiE 'all [0-9]+ (detected )?gaps closed|gaps_closed[[:space:]]*[:=][[:space:]]*[0-9]+|[0-9]+/[0-9]+ closed' "$audit" 2>/dev/null; then
    is_clean=1
  elif [[ $gap_count -eq 0 ]]; then
    # No gaps detected by audit + status=done → set 0/0 (legitimate parity-clean baseline)
    is_clean=1
  fi
  if [[ $is_clean -eq 0 ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "  ▸ $id ($feature): classification='$classification' — NOT auto-backfilling (manual review required)"
    ((halted++))
    continue
  fi
  # Backfill: write gaps_in = gaps_closed = gap_count
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [DRY] $id ($feature): would set gaps_in=$gap_count gaps_closed=$gap_count (audit: $audit)"
    ((backfilled++))
    continue
  fi
  # Insert two lines after `status: done` for this row
  awk -v id="$id" -v gc="$gap_count" '
    BEGIN { in_block=0; printed_gaps=0 }
    $0 ~ ("^id: " id "$") { in_block=1; printed_gaps=0 }
    in_block && /^```$/ {
      if (!printed_gaps) {
        # Block ended without inserting — append before the closing fence
        print "gaps_in: " gc
        print "gaps_closed: " gc
        printed_gaps=1
      }
      in_block=0
    }
    in_block && /^status:/ && !printed_gaps {
      print
      print "gaps_in: " gc
      print "gaps_closed: " gc
      printed_gaps=1
      next
    }
    { print }
  ' "$LEDGER_PATH" > "${LEDGER_PATH}.tmp"
  mv "${LEDGER_PATH}.tmp" "$LEDGER_PATH"
  echo "  ✓ $id ($feature): backfilled gaps_in=$gap_count gaps_closed=$gap_count"
  ((backfilled++))
done

echo
echo "── Summary ──"
echo "  rows scanned:    ${#target_rows[@]}"
echo "  backfilled:      $backfilled"
echo "  skipped (no audit): $skipped"
echo "  halted (manual review needed): $halted"
[[ $DRY_RUN -eq 1 ]] && echo "  (dry-run: no files modified)"
