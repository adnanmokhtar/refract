#!/usr/bin/env bash
# migrate-setup.sh — apply a /setup-project migration to a target repo.
#
# Usage:
#   migrate-setup.sh <migration-name> <target-repo> [--apply]
#
# Defaults to dry-run. --apply makes the changes.
#
# This runner is the deterministic shell counterpart of the migration's prose
# spec under templates/migrations/<migration-name>.md. The prose spec is the
# source of truth; this script implements it.
#
# Migrations available:
#   v1-to-v2   — M2 split (markers, version stamps, derived files)

set -euo pipefail

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
MIGRATIONS_ROOT="$REPO_ROOT/templates/migrations"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <migration-name> <target-repo> [--apply]"
  exit 2
fi

MIGRATION="$1"
TARGET="$2"
APPLY=0
[[ "${3:-}" == "--apply" ]] && APPLY=1

SPEC="$MIGRATIONS_ROOT/$MIGRATION.md"
if [[ ! -f "$SPEC" ]]; then
  echo "ERR: migration spec not found: $SPEC" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "ERR: target repo not found: $TARGET" >&2
  exit 1
fi

log() { printf '%s\n' "$*"; }
# Runs its arguments as ONE command — never through eval. $TARGET is a user path and an
# eval'd string breaks on its first apostrophe: `Adnan's repo` closed the quote, and
# `x'; touch /tmp/pwned; '` ran the touch. Compound steps are the functions below.
do_or_dry() {
  if [[ "$APPLY" -eq 1 ]]; then
    "$@"
  else
    log "DRY  $(printf '%q ' "$@")"
  fi
}
append_stamp() { printf '\n## Setup version\nsetup_command: %s\nmigrated_at: %s\n' "$SETUP_VERSION" "$ts" >> "$1"; }
create_stamp() { mkdir -p "$(dirname "$1")" && printf '# Codebase profile\n\n## Setup version\nsetup_command: %s\nmigrated_at: %s\n' "$SETUP_VERSION" "$ts" > "$1"; }
touch_file()   { mkdir -p "$(dirname "$1")" && touch "$1"; }

case "$MIGRATION" in
  v1-to-v2)
    log "=== migrate $MIGRATION on $TARGET ==="
    [[ "$APPLY" -eq 0 ]] && log "(dry run — pass --apply to execute)"

    # Step 1 — backup
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="$TARGET/.claude/backups/v1-pre-migration-$ts"
    log "step 1: backup -> $backup"
    do_or_dry mkdir -p "$backup"
    for path in CLAUDE.md AGENTS.md .claude ai; do
      if [[ -e "$TARGET/$path" ]]; then
        do_or_dry cp -R "$TARGET/$path" "$backup/" 2>/dev/null || true
      fi
    done

    # Step 2 — wrap managed regions
    log "step 2: wrap existing managed regions in markers"
    log "  (heuristic per spec; review the diff carefully before --apply)"
    if [[ -f "$TARGET/CLAUDE.md" ]] && ! grep -q "setup-project:managed start" "$TARGET/CLAUDE.md"; then
      log "  CLAUDE.md needs marker insertion"
      [[ "$APPLY" -eq 1 ]] && log "  [skipped — automated marker insertion is too risky for a non-interactive runner;"
      [[ "$APPLY" -eq 1 ]] && log "   open the file and add the marker pair around the regenerable section]"
    fi

    # Step 3 — stamp version (must match seed-versions.sh § SETUP_VERSION)
    SETUP_VERSION="3.0.0"
    log "step 3: stamp Setup version: $SETUP_VERSION in .claude/codebase-profile.md"
    if [[ -f "$TARGET/.claude/codebase-profile.md" ]]; then
      if ! grep -q "^## Setup version" "$TARGET/.claude/codebase-profile.md"; then
        do_or_dry append_stamp "$TARGET/.claude/codebase-profile.md"
      fi
    else
      do_or_dry create_stamp "$TARGET/.claude/codebase-profile.md"
    fi

    # Step 4 — bootstrap derived files
    log "step 4: bootstrap derived files (curator agent runs lazily on next /setup-project)"
    for f in ai/_session-digest.md ai/_convention-cheatsheet.md ai/_decision-index.md; do
      if [[ ! -f "$TARGET/$f" ]]; then
        do_or_dry touch_file "$TARGET/$f"
      fi
    done

    # Step 5 — adapters
    log "step 5: tool adapters (no-op unless adapter dirs exist)"
    for adapter_dir in .cursor .opencode .aider .clinerules; do
      [[ -d "$TARGET/$adapter_dir" ]] && log "  adapter detected: $adapter_dir — run /setup-project-adapters in target repo"
    done

    # Step 6 — verification
    log "step 6: run /setup-project-health in target repo to verify"

    log ""
    log "rollback command:"
    log "  # Restore FROM the backup first — the backup lives at $backup,"
    log "  # nested under .claude/, so do NOT 'rm -rf .claude' before restoring (that"
    log "  # deletes the backup and leaves the target unrecoverable). Remove only the"
    log "  # non-backup target paths, then copy the backup back over the target."
    log "  rm -rf '$TARGET/CLAUDE.md' '$TARGET/AGENTS.md' '$TARGET/ai'"
    log "  find '$TARGET/.claude' -mindepth 1 -maxdepth 1 ! -name backups -exec rm -rf {} +"
    log "  cp -R '$backup'/* '$TARGET/'"

    log ""
    if [[ "$APPLY" -eq 1 ]]; then
      log "MIGRATION APPLIED. Run /setup-project-health to verify."
    else
      log "DRY RUN COMPLETE. Re-run with --apply once you've reviewed the actions above."
    fi
    ;;
  *)
    echo "ERR: unknown migration '$MIGRATION'" >&2
    echo "Available:" >&2
    ls "$MIGRATIONS_ROOT"/*.md 2>/dev/null | xargs -I{} basename {} .md >&2
    exit 1
    ;;
esac
