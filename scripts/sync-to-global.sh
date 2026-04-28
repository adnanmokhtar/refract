#!/usr/bin/env bash
# sync-to-global.sh — symlink claude-config artifacts into ~/.claude
#
# Source of truth: this repo. Edits in ~/.claude directly are NOT preserved
# and will be detected as drift by scripts/verify-sync.sh.
#
# What gets synced (symlinked):
#   commands/*           -> ~/.claude/commands/
#   templates/*          -> ~/.claude/templates/
#   docs/* (read-only)   -> ~/.claude/docs/claude-config/
#
# What is NEVER touched:
#   ~/.claude/settings.json          (user-managed; merge manually if needed)
#   ~/.claude/settings.local.json    (per-machine overrides — escape hatch)
#   ~/.claude/projects/              (session state)
#   ~/.claude/memory/                (auto memory)
#
# Behavior:
#   - Default: dry-run. Prints planned actions; makes no changes.
#   - --apply: actually create symlinks.
#   - --force: replace existing files/symlinks at target paths.
#       Without --force, existing non-symlink files are reported and SKIPPED.
#   - --unlink: remove all repo-owned symlinks from ~/.claude (revert).
#
# Exit codes: 0 ok / 1 drift detected without --force / 2 usage error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="${CLAUDE_HOME:-$HOME/.claude}"

APPLY=0
FORCE=0
UNLINK=0

usage() {
  sed -n '2,30p' "$0"
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --apply)  APPLY=1 ;;
    --force)  FORCE=1 ;;
    --unlink) UNLINK=1 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $arg" >&2; usage ;;
  esac
done

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERR:  %s\n' "$*" >&2; }

mkdir -p "$TARGET_ROOT"

# Each entry: SRC_REL:DST_REL — both relative to their roots.
# SRC_REL is a directory in the repo; DST_REL is the parent dir under ~/.claude
# in which each child of SRC_REL becomes a symlink.
SYNC_MAP=(
  "commands:commands"
  "templates:templates"
)

drift=0

link_child() {
  local src_path="$1"  # absolute
  local dst_path="$2"  # absolute
  local name; name="$(basename "$src_path")"

  if [[ -L "$dst_path" ]]; then
    local current; current="$(readlink "$dst_path")"
    if [[ "$current" == "$src_path" ]]; then
      log "ok    $dst_path -> $src_path"
      return 0
    fi
    if [[ "$FORCE" -eq 1 ]]; then
      [[ "$APPLY" -eq 1 ]] && rm "$dst_path"
      log "relink $dst_path (was -> $current)"
    else
      warn "drift $dst_path -> $current (expected $src_path); use --force"
      drift=1
      return 0
    fi
  elif [[ -e "$dst_path" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      [[ "$APPLY" -eq 1 ]] && rm -rf "$dst_path"
      log "replace $dst_path (was a real file/dir)"
    else
      warn "exists $dst_path is a real file/dir, not a symlink; use --force to replace"
      drift=1
      return 0
    fi
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    ln -s "$src_path" "$dst_path"
    log "link   $dst_path -> $src_path"
  else
    log "would-link $dst_path -> $src_path"
  fi
}

unlink_child() {
  local dst_path="$1"
  local src_path="$2"
  if [[ -L "$dst_path" ]]; then
    local current; current="$(readlink "$dst_path")"
    if [[ "$current" == "$src_path" ]]; then
      if [[ "$APPLY" -eq 1 ]]; then
        rm "$dst_path"
        log "unlinked $dst_path"
      else
        log "would-unlink $dst_path"
      fi
    fi
  fi
}

for entry in "${SYNC_MAP[@]}"; do
  src_rel="${entry%%:*}"
  dst_rel="${entry##*:}"
  src_dir="$REPO_ROOT/$src_rel"
  dst_dir="$TARGET_ROOT/$dst_rel"

  [[ -d "$src_dir" ]] || { err "missing source dir: $src_dir"; exit 1; }
  mkdir -p "$dst_dir"

  # Only sync top-level children (so each command file or template subdir is one symlink).
  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    name="$(basename "$child")"
    [[ "$name" == ".gitkeep" ]] && continue
    [[ "$name" == ".DS_Store" ]] && continue
    if [[ "$UNLINK" -eq 1 ]]; then
      unlink_child "$dst_dir/$name" "$child"
    else
      link_child "$child" "$dst_dir/$name"
    fi
  done < <(find "$src_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) | sort)
done

if [[ "$APPLY" -eq 0 ]]; then
  log ""
  log "DRY RUN — re-run with --apply to perform the actions above."
fi

if [[ "$drift" -eq 1 && "$FORCE" -eq 0 ]]; then
  exit 1
fi
