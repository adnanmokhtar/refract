#!/usr/bin/env bash
# apply-baseline-sync.sh — deterministic ai/ + .claude/ baseline synchronizer.
#
# Walks every file in templates/repo-baseline/ and ensures the target has it
# AND that the managed regions are up-to-date with the latest pack source. This
# is the missing third leg of the propagation tripod:
#
#   apply-study-decisions.sh — packs/<track>/{commands,agents,skills,rules}/   (Phase 4.2)
#   apply-anchors.sh         — `## Project-specific` blocks in pack-derived    (Phase 4.6)
#   apply-baseline-sync.sh   — repo-baseline/{ai/,.claude/}/                   (Phase 4.1)  ← THIS
#
# Why this exists: the agent often regens .claude/agents (via apply-study-
# decisions.sh) but skips ai/_session-digest.md / ai/conventions.md / ai/stack.md
# / ai/modules.md — the knowledge layer. That ships incomplete refresh runs.
# This script is shell-deterministic; the agent CANNOT skip it once invoked.
#
# Modes:
#   - file MISSING in target              → ADD (cp from baseline)
#   - file PRESENT, no managed markers    → KEEP-OURS (user owns it; never overwrite)
#   - file PRESENT, managed markers exist → SYNC managed region only (preserve user content outside markers)
#   - file PRESENT, identical to baseline → NO-OP
#
# Usage:
#   apply-baseline-sync.sh <target-repo> [--apply] [--strict]
#
# Flags:
#   --apply   write changes (without it: dry-run, prints decisions only)
#   --strict  exit 1 on any KEEP-OURS row (use only when you EXPECT a clean slate)
#
# Exit codes:
#   0 — clean (dry-run by default, or --apply succeeded)
#   1 — target missing OR --strict tripped on KEEP-OURS
#   2 — usage error

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_ROOT="$REPO_ROOT/templates/repo-baseline"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply] [--strict]" >&2
  exit 2
fi

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET="$1"; shift
APPLY=0
STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)  APPLY=1; shift ;;
    --strict) STRICT=1; shift ;;
    *)        echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }
[[ -d "$BASELINE_ROOT" ]] || { echo "ERR: baseline source missing: $BASELINE_ROOT" >&2; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
backup_dir="$TARGET/.claude/backups/baseline-sync-$ts"

added=0
synced=0
kept=0
nooped=0
processed=0
strict_violations=0

# Markers used by Phase 4 idempotency.
MARK_OPEN='<!-- setup-project:managed start'
MARK_CLOSE='<!-- setup-project:managed end -->'

# Detect whether file has managed markers (sync-eligible) or not (KEEP-OURS).
has_markers() {
  grep -qF "$MARK_OPEN" "$1" 2>/dev/null
}

# Compare two files; returns 0 if identical (NO-OP), else non-zero.
files_identical() {
  cmp -s "$1" "$2"
}

# Sync only the managed region from baseline → target. Unmanaged content in
# target is preserved verbatim.
#
# This is the "merge" path: we replace each `<!-- managed start id=X v=Y -->...`
# block in target with the corresponding block from baseline, by id. Blocks in
# target with no matching id in baseline are left alone (user-defined sections).
sync_managed_regions() {
  local baseline="$1" target="$2" tmp
  tmp=$(mktemp)
  awk -v BASELINE="$baseline" '
    BEGIN {
      # Pre-load baseline blocks keyed by id="X"
      while ((getline line < BASELINE) > 0) {
        if (line ~ /<!-- setup-project:managed start id=/) {
          id = ""
          if (match(line, /id=[^ >]+/)) {
            id = substr(line, RSTART, RLENGTH)
            sub(/^id=/, "", id)
          }
          if (id != "") {
            current_id = id
            blocks[current_id] = line "\n"
            in_block = 1
            continue
          }
        }
        if (in_block) {
          blocks[current_id] = blocks[current_id] line "\n"
          if (line ~ /<!-- setup-project:managed end -->/) {
            in_block = 0
            current_id = ""
          }
        }
      }
      close(BASELINE)
    }
    /<!-- setup-project:managed start id=/ {
      id = ""
      if (match($0, /id=[^ >]+/)) {
        id = substr($0, RSTART, RLENGTH)
        sub(/^id=/, "", id)
      }
      if (id != "" && (id in blocks)) {
        printf "%s", blocks[id]
        in_skip = 1
        skip_id = id
        next
      }
    }
    in_skip && /<!-- setup-project:managed end -->/ {
      in_skip = 0
      skip_id = ""
      next
    }
    in_skip { next }
    { print }
  ' "$target" > "$tmp"
  if ! files_identical "$target" "$tmp"; then
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$backup_dir/$(dirname "${target#$TARGET/}")"
      cp "$target" "$backup_dir/${target#$TARGET/}"
      mv "$tmp" "$target"
    else
      rm -f "$tmp"
    fi
    return 0  # changes were made (or would be in --apply)
  fi
  rm -f "$tmp"
  return 1  # no changes needed
}

echo "=== apply-baseline-sync ==="
echo "Target:   $TARGET"
echo "Baseline: $BASELINE_ROOT"
echo "Mode:     $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo ""

# Walk every file under repo-baseline (preserves dir structure relative to root).
while IFS= read -r src; do
  rel="${src#$BASELINE_ROOT/}"
  # Skip *.tpl files — those are templated by the agent at scaffold time
  # (PROJECTS.md.tpl, CLAUDE.md.tpl) and are not direct copies.
  [[ "$rel" == *.tpl ]] && continue

  tgt="$TARGET/$rel"
  processed=$((processed + 1))

  if [[ ! -f "$tgt" ]]; then
    # ADD
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$(dirname "$tgt")"
      cp "$src" "$tgt"
    fi
    echo "  ADD       $rel"
    added=$((added + 1))
    continue
  fi

  if files_identical "$src" "$tgt"; then
    nooped=$((nooped + 1))
    continue
  fi

  if has_markers "$tgt" && has_markers "$src"; then
    # Both sides have managed markers — sync managed regions only.
    if sync_managed_regions "$src" "$tgt"; then
      echo "  SYNC      $rel  (managed regions updated; user content preserved)"
      synced=$((synced + 1))
    else
      nooped=$((nooped + 1))
    fi
    continue
  fi

  # File exists, differs from baseline, no managed markers → user-owned.
  echo "  KEEP-OURS $rel  (no managed markers; user content preserved verbatim)"
  kept=$((kept + 1))
  if [[ $STRICT -eq 1 ]]; then
    strict_violations=$((strict_violations + 1))
  fi
done < <(find -L "$BASELINE_ROOT" -type f \( -name '*.md' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.sh' \) | sort)

echo ""
echo "=== summary ==="
echo "Processed:        $processed"
echo "ADD:              $added"
echo "SYNC (managed):   $synced"
echo "KEEP-OURS:        $kept"
echo "NO-OP:            $nooped"

if [[ $APPLY -eq 1 && ($added -gt 0 || $synced -gt 0) ]]; then
  echo ""
  # Only announce a backup directory that EXISTS. HISTORY: this line printed unconditionally
  # from the counters, and the counters include rows whose write path never created the dir —
  # so a user who trusted the message and went to roll back found nothing at the advertised
  # path. Two scripts shipped that bug; both now check.
  if [[ -d "$backup_dir" ]]; then
    echo "Backups: $backup_dir/"
  else
    echo "Backups: (none taken — every change was an ADD of a file that did not exist)"
  fi
fi

# --- Make the rules this script just installed actually LOAD -------------------------------
# `.claude/rules/` is inert without `@.claude/rules/…` imports in the project CLAUDE.md — see
# .claude/rules/README.md and scripts/wire-rule-imports.sh for the full history. Baseline sync
# is where a CLAUDE.md is decided, so it is where the imports belong. This never rewrites the
# user's CLAUDE.md: wire-rule-imports.sh only maintains one clearly-marked managed block.
if [[ -d "$TARGET/.claude/rules" ]]; then
  echo ""
  echo "=== rule imports (a rule nothing imports never loads) ==="
  if [[ -x "$SELF_DIR/wire-rule-imports.sh" || -f "$SELF_DIR/wire-rule-imports.sh" ]]; then
    bash "$SELF_DIR/wire-rule-imports.sh" "$TARGET" $([[ $APPLY -eq 1 ]] && echo --apply) || true
  else
    echo "  WARN wire-rule-imports.sh not found beside this script — run it manually or .claude/rules/ will not load."
  fi
fi

if [[ $APPLY -eq 0 ]]; then
  echo ""
  echo "Dry run — pass --apply to execute."
fi

if [[ $STRICT -eq 1 && $strict_violations -gt 0 ]]; then
  echo ""
  echo "REFUSED — --strict + $strict_violations KEEP-OURS row(s)." >&2
  exit 1
fi

exit 0
