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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
do_or_dry() {
  if [[ "$APPLY" -eq 1 ]]; then
    eval "$@"
  else
    log "DRY  $*"
  fi
}

case "$MIGRATION" in
  v1-to-v2)
    log "=== migrate $MIGRATION on $TARGET ==="
    [[ "$APPLY" -eq 0 ]] && log "(dry run — pass --apply to execute)"

    # Step 1 — backup
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="$TARGET/.claude/backups/v1-pre-migration-$ts"
    log "step 1: backup -> $backup"
    do_or_dry "mkdir -p '$backup'"
    for path in CLAUDE.md AGENTS.md .claude ai; do
      if [[ -e "$TARGET/$path" ]]; then
        do_or_dry "cp -R '$TARGET/$path' '$backup/' 2>/dev/null || true"
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

    # Step 3 — stamp version
    log "step 3: stamp Setup version: 2.0.0 in .claude/codebase-profile.md"
    if [[ -f "$TARGET/.claude/codebase-profile.md" ]]; then
      if ! grep -q "^## Setup version" "$TARGET/.claude/codebase-profile.md"; then
        do_or_dry "printf '\n## Setup version\nsetup_command: 2.0.0\nmigrated_at: %s\n' '$ts' >> '$TARGET/.claude/codebase-profile.md'"
      fi
    else
      do_or_dry "mkdir -p '$TARGET/.claude' && printf '# Codebase profile\n\n## Setup version\nsetup_command: 2.0.0\nmigrated_at: %s\n' '$ts' > '$TARGET/.claude/codebase-profile.md'"
    fi

    # Step 4 — bootstrap derived files
    log "step 4: bootstrap derived files (curator agent runs lazily on next /setup-project)"
    for f in ai/_session-digest.md ai/_convention-cheatsheet.md ai/_decision-index.md; do
      if [[ ! -f "$TARGET/$f" ]]; then
        do_or_dry "mkdir -p '$TARGET/$(dirname "$f")' && touch '$TARGET/$f'"
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
    log "  rm -rf '$TARGET/CLAUDE.md' '$TARGET/AGENTS.md' '$TARGET/.claude' '$TARGET/ai'"
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
