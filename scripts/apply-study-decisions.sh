#!/usr/bin/env bash
# apply-study-decisions.sh — deterministic enforcer of study-existing decisions.
#
# Reads <target>/.claude/_study-existing-report.md.
# Applies REPLACE-OR-ENHANCE + ADD rows automatically (replace target file from
# pack source). MERGE + KEEP-OURS-PLUS-INJECT rows are LISTED for human review
# (they need partial / managed-section logic that's safer with human eyes).
#
# Solves: agent's Phase 4 was ignoring study-existing actionable rows under
# --include=<pack> narrow-scope interpretation. This script can't be skipped.
#
# Usage:
#   apply-study-decisions.sh <target-repo> [--apply] [--include=replace,add,merge]
#   apply-study-decisions.sh <target-repo> --reject='pack/kind/file.md:rationale'     (repeatable)
#                                          --keep-ours='pack/kind/file.md:rationale'
#                                          --resolve='pack/kind/file.md:note'
#                                          --keep='kind/file.md:rationale'
#
# Default mode: dry-run (lists actions; writes nothing).
# --apply executes.
# --include limits which decision classes to apply (default: replace,add).
#
# M35 ledger flags append durable decisions to <target>/.claude/_refresh-decisions.md:
#   --reject     permanent skip (artifact class is wrong for this project; never re-proposed)
#   --keep-ours  target file beats the CURRENT pack version (stamped pack@sha8; re-opens when pack changes)
#   --resolve    a MERGE / KEEP-OURS-PLUS-INJECT row was merged by hand (stamped pack@sha8; re-opens when pack changes)
#   --keep       project-only orphan is a keeper (key has no pack segment: kind/file.md)
# These are the ONLY sanctioned way to close an actionable row without applying it.
# audit-setup.sh C2k refuses success on rows that are neither applied nor recorded.
#
# Exit codes: 0 ok / 1 target not found / 2 usage / 3 study report missing

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply] [--include=replace,add,merge]" >&2
  exit 2
fi

TARGET="$1"; shift
APPLY=0
INCLUDE="replace,add"
declare -a LEDGER_OPS=()   # "VERB|key|rationale"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)       APPLY=1; shift ;;
    --include=*)   INCLUDE="${1#--include=}"; shift ;;
    --reject=*)    LEDGER_OPS+=("REJECTED|${1#--reject=}"); shift ;;
    --keep-ours=*) LEDGER_OPS+=("KEEP-OURS|${1#--keep-ours=}"); shift ;;
    --resolve=*)   LEDGER_OPS+=("RESOLVED|${1#--resolve=}"); shift ;;
    --keep=*)      LEDGER_OPS+=("KEEP|${1#--keep=}"); shift ;;
    *)             echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

# ---------- M35 ledger mode: record decisions, then exit ----------
LEDGER="$TARGET/.claude/_refresh-decisions.md"
if [[ ${#LEDGER_OPS[@]} -gt 0 ]]; then
  mkdir -p "$(dirname "$LEDGER")"
  if [[ ! -f "$LEDGER" ]]; then
    cat > "$LEDGER" <<'HDR'
# Refresh decisions ledger (M35)

Durable per-file decisions from /setup-project refresh runs. study-existing.sh
reconciles rows recorded here instead of re-proposing them every run.
KEEP-OURS / RESOLVED entries re-open automatically when the pack source changes
(pack@sha8 mismatch). REJECTED / KEEP are permanent until a human deletes the line.

Append via: apply-study-decisions.sh <target> --reject='pack/kind/file.md:rationale'
(or --keep-ours= / --resolve= / --keep=). Manual edits are fine — keep the line shape.

---
HDR
  fi
  today=$(date +%Y-%m-%d)
  recorded=0
  for op in "${LEDGER_OPS[@]}"; do
    verb="${op%%|*}"; rest="${op#*|}"
    key="${rest%%:*}"; why="${rest#*:}"
    if [[ -z "$key" || -z "$why" || "$key" == "$why" ]]; then
      echo "  ERR malformed ledger op (need key:rationale): $rest" >&2; continue
    fi
    stamp="($today)"
    if [[ "$verb" == "KEEP-OURS" || "$verb" == "RESOLVED" ]]; then
      pack_src="$REPO_ROOT/templates/packs/$key"
      if [[ -f "$pack_src" ]]; then
        sha=$(shasum "$pack_src" | cut -c1-8)
        stamp="($today, pack@$sha)"
      else
        echo "  WARN pack source not found for $key — stamping without pack@sha (entry will hold until manually removed)" >&2
      fi
    fi
    # Replace any prior entry for the same key (last-write-wins, one line per key)
    if grep -qF "\`$key\`" "$LEDGER" 2>/dev/null; then
      grep -vF "\`$key\`" "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"
    fi
    printf -- '- `%s` → %s %s — %s\n' "$key" "$verb" "$stamp" "$why" >> "$LEDGER"
    echo "  RECORDED $verb $key — $why"
    recorded=$((recorded + 1))
  done
  echo ""
  echo "$recorded decision(s) recorded in ${LEDGER#$TARGET/}. Re-run study-existing.sh to see them reconciled."
  exit 0
fi

# Pack commands use ../../../snippets/ + ../../../governance/ (valid under templates/packs/.../commands/).
# Targets receive files under .claude/commands/ — rewrite so links resolve to .claude/templates/{snippets,governance}/.
rewrite_deployed_command_links() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if command -v perl >/dev/null 2>&1; then
    perl -i -pe 's{\]\(\.\./\.\./\.\./snippets/}{](../templates/snippets/}g; s{\]\(\.\./\.\./\.\./governance/}{](../templates/governance/}g' "$f"
  else
    echo "  WARN perl missing — cannot rewrite snippet/governance links in ${f#$TARGET/}" >&2
  fi
}

REPORT="$TARGET/.claude/_study-existing-report.md"
[[ -f "$REPORT" ]] || { echo "ERR: study report not found at $REPORT — run scripts/study-existing.sh first" >&2; exit 3; }

# Helper: resolve target path relative to TARGET root for a given kind + base
target_dir_for_kind() {
  case "$1" in
    commands)    echo "$TARGET/.claude/commands" ;;
    agents)      echo "$TARGET/.claude/agents" ;;
    skills)      echo "$TARGET/.claude/skills" ;;
    rules)       echo "$TARGET/.claude/rules" ;;
    ai-patterns) echo "$TARGET/ai/patterns" ;;
    *)           echo "$TARGET/.claude/$1" ;;
  esac
}

# Parse the report: rows look like
#   - `<base.md>` — target X / pack Y lines → **DECISION**
#   - `<base.md>` — target MISSING / pack Y lines → **ADD**
# Inside ## <pack> section, ### <kind> sub-sections.

current_pack=""
current_kind=""
applied=0
listed=0
skipped=0
ledgered=0
errors=0

declare -a actions  # array of "decision|pack|kind|base|reason"

while IFS= read -r line; do
  # Pack header: "## migration"
  if [[ "$line" =~ ^##\ ([a-z0-9-]+)$ ]]; then
    current_pack="${BASH_REMATCH[1]}"
    continue
  fi
  # Kind header: "### commands" / "### agents" etc.
  if [[ "$line" =~ ^###\ ([a-z-]+)$ ]]; then
    current_kind="${BASH_REMATCH[1]}"
    continue
  fi
  # Row: starts with "  - `<file>` "
  if [[ "$line" =~ ^[[:space:]]+-[[:space:]]\`([^\`]+)\`[[:space:]]+—[[:space:]](.*)$ ]]; then
    base="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    [[ -z "$current_pack" || -z "$current_kind" ]] && continue
    [[ "$current_pack" == "Decision legend" || "$current_kind" == "" ]] && continue

    # Extract decision (last **WORD-WORD** in rest). REVIEW rows contain
    # `**REVIEW: ...**` which won't match the strict pattern — that's fine,
    # we want to skip them. Use `|| true` so grep's exit-1 doesn't trip
    # `set -e` + `pipefail` and kill the whole script.
    decision=$(echo "$rest" | grep -oE '\*\*[A-Z-]+\*\*' | tail -1 | tr -d '*' || true)
    [[ -z "$decision" ]] && continue

    actions+=("$decision|$current_pack|$current_kind|$base|$rest")
  fi
done <<<"$(cat "$REPORT")"

echo "=== apply-study-decisions ==="
echo "Target:  $TARGET"
echo "Mode:    $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo "Include: $INCLUDE"
echo "Rows:    ${#actions[@]}"
echo ""

# One backup timestamp/dir per run so a single invocation's rollback set lives
# together (the summary below points at exactly one dir).
ts=$(date +%Y%m%d-%H%M%S)
bak_dir="$TARGET/.claude/backups/study-decisions-$ts"

# Apply per action
if [[ ${#actions[@]} -eq 0 ]]; then
  echo "  (no actionable rows parsed from report — either nothing to do, or report is malformed)"
fi
for action in "${actions[@]:-}"; do
  [[ -z "$action" ]] && continue
  IFS='|' read -r decision pack kind base rest <<<"$action"
  pack_src="$PACKS_ROOT/$pack/$kind/$base"
  tgt_dir=$(target_dir_for_kind "$kind")
  tgt="$tgt_dir/$base"

  case "$decision" in
    ADD)
      [[ "$INCLUDE" == *add* ]] || { listed=$((listed + 1)); continue; }
      [[ -f "$pack_src" ]] || { echo "  SKIP $pack/$kind/$base — pack source missing"; skipped=$((skipped + 1)); continue; }
      if [[ "$APPLY" -eq 1 ]]; then
        mkdir -p "$tgt_dir"
        cp "$pack_src" "$tgt"
        [[ "$kind" == "commands" || "$kind" == "agents" ]] && rewrite_deployed_command_links "$tgt"
        echo "  ADD     $pack/$kind/$base → $(basename "$tgt_dir")/$base"
      else
        echo "  would-ADD $pack/$kind/$base → $(basename "$tgt_dir")/$base"
      fi
      applied=$((applied + 1))
      ;;
    REPLACE-OR-ENHANCE)
      [[ "$INCLUDE" == *replace* ]] || { listed=$((listed + 1)); continue; }
      [[ -f "$pack_src" ]] || { echo "  SKIP $pack/$kind/$base — pack source missing"; skipped=$((skipped + 1)); continue; }
      [[ -f "$tgt" ]] || { echo "  SKIP $pack/$kind/$base — target missing (was ADD before report; now ADD instead of REPLACE)"; skipped=$((skipped + 1)); continue; }

      # Backup the existing file before replace (safety net). ts/bak_dir are
      # hoisted above the loop so all of this run's backups share one dir.
      if [[ "$APPLY" -eq 1 ]]; then
        mkdir -p "$bak_dir"
        rel="${tgt#$TARGET/}"
        bak_path="$bak_dir/$rel"
        mkdir -p "$(dirname "$bak_path")"
        cp "$tgt" "$bak_path"

        cp "$pack_src" "$tgt"
        [[ "$kind" == "commands" || "$kind" == "agents" ]] && rewrite_deployed_command_links "$tgt"
        echo "  REPLACE $rel  ($rest; backup: $bak_dir/$rel)"
      else
        echo "  would-REPLACE ${tgt#$TARGET/}  ($rest)"
      fi
      applied=$((applied + 1))
      ;;
    MERGE|KEEP-OURS-PLUS-INJECT)
      [[ "$INCLUDE" == *merge* ]] || { listed=$((listed + 1)); continue; }
      echo "  REVIEW  $pack/$kind/$base  ($decision; manual merge required — not auto-applied)"
      listed=$((listed + 1))
      ;;
    KEEP-OURS-DEEP|KEEP-OURS-ADD-SIDE-DOC|IDENTICAL-NO-OP)
      # No action needed
      ;;
    REJECTED-BY-LEDGER|KEEP-OURS-BY-LEDGER|RESOLVED-BY-LEDGER|KEEP-BY-LEDGER)
      # M35: reconciled by the decisions ledger — nothing to do
      ledgered=$((ledgered + 1))
      ;;
    *)
      # Unknown decision; warn
      echo "  WARN unknown decision '$decision' for $pack/$kind/$base"
      ;;
  esac
done

echo ""
echo "=== summary ==="
echo "Applied (or would-apply): $applied"
echo "Listed for human review:  $listed"
echo "Ledger-reconciled:        $ledgered"
echo "Skipped (source missing): $skipped"
echo ""

if [[ "$APPLY" -eq 1 && "$applied" -gt 0 ]]; then
  echo "Files modified. Backup at: ${bak_dir#$TARGET/}/"
  echo ""
  echo "Next steps:"
  echo "  1. Run /setup-project anchoring (Phase 4.6) to inject project-specific blocks into the replaced files."
  echo "  2. Re-run scripts/audit-setup.sh to verify Phase 5 audit passes."
fi

[[ "$APPLY" -eq 0 ]] && echo "Dry run — pass --apply to execute."
exit 0
