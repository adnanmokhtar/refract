#!/usr/bin/env bash
# sync-to-global.sh — universal cross-tool configuration synchronizer
#
# Source of truth: this repo. Detects ALL installed AI coding tools and syncs
# commands/skills/rules to each one in its native format. Never edit tool dirs
# directly — they are managed by this script.
#
# Tools supported (auto-detected):
#   Claude Code  -> ~/.claude/{commands,templates,scripts}/  (symlinks)
#   Kimi Code    -> ~/.kimi/skills/<cmd>/SKILL.md            (copies with frontmatter)
#   Qwen Code    -> ~/.qwen/commands/*.md                    (copies)
#   Cursor       -> ~/.cursor/skills/                        (if global skills dir exists)
#   OpenCode     -> ~/.opencode/skills/                      (if global skills dir exists)
#   Codex        -> ~/.codex/skills/                         (if global skills dir exists)
#
# Auto-detection: checks for tool config dirs. No flags needed.
#
# Behavior:
#   - Default: dry-run. Prints planned actions; makes no changes.
#   - --apply: actually sync.
#   - --force: replace existing files/symlinks.
#   - --unlink: remove all repo-owned artifacts from tool dirs.
#
# Exit codes: 0 ok / 1 drift detected without --force / 2 usage error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLY=0
FORCE=0
UNLINK=0

for arg in "$@"; do
  case "$arg" in
    --apply)   APPLY=1 ;;
    --force)   FORCE=1 ;;
    --unlink)  UNLINK=1 ;;
    -h|--help)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERR:  %s\n' "$*" >&2; }

drift=0

# ── Claude Code ─────────────────────────────────────────────────────────────
sync_claude() {
  local target="${CLAUDE_HOME:-$HOME/.claude}"
  [ -d "$target" ] || return 0

  log ""
  log "=== Claude Code (~/.claude) ==="

  local sync_map=("commands:commands" "templates:templates" "scripts:scripts")
  for entry in "${sync_map[@]}"; do
    local src_rel="${entry%%:*}" dst_rel="${entry##*:}"
    local src_dir="$REPO_ROOT/$src_rel" dst_dir="$target/$dst_rel"
    [ -d "$src_dir" ] || continue
    mkdir -p "$dst_dir"

    while IFS= read -r child; do
      [ -z "$child" ] && continue
      local name; name="$(basename "$child")"
      [[ "$name" == ".gitkeep" || "$name" == ".DS_Store" ]] && continue

      local dst="$dst_dir/$name"
      if [ "$UNLINK" -eq 1 ]; then
        [ -L "$dst" ] && [ "$(readlink "$dst")" = "$child" ] && rm "$dst" && log "unlink $dst"
        continue
      fi

      if [ -L "$dst" ]; then
        if [ "$(readlink "$dst")" = "$child" ]; then
          log "ok     $dst"
        elif [ "$FORCE" -eq 1 ]; then
          [ "$APPLY" -eq 1 ] && rm "$dst" && ln -s "$child" "$dst"
          log "relink $dst"
        else
          warn "drift  $dst -> $(readlink "$dst")"
          drift=1
        fi
      elif [ -e "$dst" ]; then
        if [ "$FORCE" -eq 1 ]; then
          [ "$APPLY" -eq 1 ] && rm -rf "$dst" && ln -s "$child" "$dst"
          log "replace $dst"
        else
          warn "exists $dst (real file, not symlink); use --force"
          drift=1
        fi
      else
        if [ "$APPLY" -eq 1 ]; then
          ln -s "$child" "$dst"
          log "link   $dst -> $child"
        else
          log "would  $dst -> $child"
        fi
      fi
    done < <(find "$src_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) | sort)
  done
}

# ── Kimi Code ───────────────────────────────────────────────────────────────
sync_kimi() {
  local target="${KIMI_HOME:-$HOME/.kimi}"
  [ -d "$target" ] || return 0

  log ""
  log "=== Kimi Code (~/.kimi/skills) ==="

  local skills_dir="$target/skills"
  mkdir -p "$skills_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local skill_name; skill_name="$(echo "$name" | tr '[:upper:]_' '[:lower:]-' | sed 's/[^a-z0-9-]//g')"
    local skill_dir="$skills_dir/$skill_name"
    local skill_file="$skill_dir/SKILL.md"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -d "$skill_dir" ] && [ -f "$skill_file" ]; then
        # Check if managed by us (has our metadata marker)
        if grep -q "source: claude-config/commands/" "$skill_file" 2>/dev/null; then
          [ "$APPLY" -eq 1 ] && rm -rf "$skill_dir"
          log "unlink $skill_dir"
        fi
      fi
      continue
    fi

    # Extract description from source frontmatter
    local description
    description="$(awk '/^description:/{gsub(/^description:[[:space:]]*/,""); print; exit}' "$cmd_file")"
    [ -z "$description" ] && description="Global command: $skill_name"

    if [ "$APPLY" -eq 1 ]; then
      mkdir -p "$skill_dir"
      {
        echo "---"
        echo "name: $skill_name"
        echo "description: $description"
        echo "metadata:"
        echo "  source: claude-config/commands/$name.md"
        echo "---"
        echo ""
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2' "$cmd_file"
      } > "$skill_file"
      log "skill  $skill_name"
    else
      log "would  $skill_name -> $skill_file"
    fi
    count=$((count + 1))
  done < <(find "$REPO_ROOT/commands" -maxdepth 1 -name "*.md" -type f | sort)

  log "       ($count skills)"
}

# ── Qwen Code ───────────────────────────────────────────────────────────────
sync_qwen() {
  local target="${QWEN_HOME:-$HOME/.qwen}"
  [ -d "$target" ] || return 0

  log ""
  log "=== Qwen Code (~/.qwen/commands) ==="

  local cmds_dir="$target/commands"
  mkdir -p "$cmds_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file")"
    local dst="$cmds_dir/$name"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -f "$dst" ] && cmp -s "$cmd_file" "$dst" 2>/dev/null; then
        [ "$APPLY" -eq 1 ] && rm "$dst"
        log "unlink $dst"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      cp "$cmd_file" "$dst"
      log "cmd    $name"
    else
      log "would  $name -> $dst"
    fi
    count=$((count + 1))
  done < <(find "$REPO_ROOT/commands" -maxdepth 1 -name "*.md" -type f | sort)

  log "       ($count commands)"
}

# ── Cursor (global skills, if supported) ────────────────────────────────────
sync_cursor_global() {
  local target="${CURSOR_HOME:-$HOME/.cursor}"
  [ -d "$target" ] || return 0
  # Cursor doesn't have a standard global skills dir, but some users create one
  local skills_dir="$target/skills"
  [ -d "$skills_dir" ] || return 0

  log ""
  log "=== Cursor (global skills) ==="
  log "       (Cursor is primarily project-scoped; global skills at $skills_dir)"
}

# ── OpenCode (global skills, if supported) ──────────────────────────────────
sync_opencode_global() {
  local target="${OPENCODE_HOME:-$HOME/.opencode}"
  [ -d "$target" ] || return 0
  local skills_dir="$target/skills"
  [ -d "$skills_dir" ] || return 0

  log ""
  log "=== OpenCode (global skills) ==="
  log "       (OpenCode reads ~/.claude/skills/ directly; no sync needed)"
}

# ── Main ────────────────────────────────────────────────────────────────────

log "════════════════════════════════════════════════════════════════"
log "  Universal cross-tool sync"
log "  Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo dry-run)"
log "════════════════════════════════════════════════════════════════"

sync_claude
sync_kimi
sync_qwen
sync_cursor_global
sync_opencode_global

log ""
if [ "$APPLY" -eq 0 ]; then
  log "DRY RUN — re-run with --apply to perform the actions above."
fi

if [ "$drift" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
  exit 1
fi
