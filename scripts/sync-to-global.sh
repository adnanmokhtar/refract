#!/usr/bin/env bash
# sync-to-global.sh — universal cross-tool configuration synchronizer
#
# Source of truth: this repo. Detects ALL installed AI coding tools and syncs
# commands/skills/rules to each one in its native format. Never edit tool dirs
# directly — they are managed by this script.
#
# Tools supported (auto-detected — each writes to the tool's NATIVE global
# command surface so /<command> works there even when Claude Code is unavailable):
#   Claude Code  -> ~/.claude/{commands,templates,scripts}/  (symlinks)
#   Kimi Code    -> ~/.kimi/skills/<cmd>/SKILL.md            (copies with frontmatter)
#   Qwen Code    -> ~/.qwen/commands/*.md                    (copies)
#   Gemini CLI   -> ~/.gemini/commands/<cmd>.toml           (TOML custom command)
#   OpenCode     -> ~/.config/opencode/commands/<cmd>.md    (native md + agent: field)
#   Codex CLI    -> ~/.agents/skills/<cmd>/SKILL.md         (Open Agent Skills, user-level)
#
# Honest no-ops (these tools have NO global command primitive — only global
# rules, which are out of scope for command sync):
#   Cursor / Windsurf / Codeium / Cline / Continue / Copilot / Aider
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
# Source of truth for the cross-tool GLOBAL command set = this repo's commands/
# directory ONLY — the core, stack-agnostic orchestration toolkit.
#
# Pack commands (the migration suite, add-feature, every templates/packs/<pack>/
# command) are PROJECT-scoped, NOT global: /setup-project installs them into a
# repo's .claude/commands/ when their pack is selected, and apply-adapter-sync.sh
# ports them to each tool PER-PROJECT. They must never appear in the global surface.
#
# Sourcing from commands/ (not ~/.claude/commands) makes the global set a
# deterministic contract: a stray `ln -s` of a pack command into ~/.claude/commands
# can no longer leak into every other tool's global surface. Override for tests.
SRC_COMMANDS="${CLAUDE_COMMANDS:-$REPO_ROOT/commands}"
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

# Marker written into every generated artifact so --unlink can recognise ours.
GEN_MARK="source: claude-config/commands/"

# Extract the one-line description from a command's frontmatter.
cmd_description() {
  local f="$1" d
  d="$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f")"
  [ -n "$d" ] && printf '%s' "$d" || printf 'Global command from claude-config'
}

# Print the command BODY (frontmatter stripped) prefixed with an EXECUTE-NOW
# preamble, so ported commands run instead of loading as inert reference.
# $1 = command file, $2 = name, $3 = args token for this tool (e.g. {{args}} or $ARGUMENTS)
emit_exec_body() {
  local f="$1" name="$2" args_tok="$3"
  printf '# EXECUTE NOW\n\n'
  printf 'You are running the /%s workflow, ported from Claude Code so it works in this\n' "$name"
  printf 'tool when Claude Code is unavailable. Do NOT summarise this document and ask the\n'
  printf 'user what to do — immediately begin executing the workflow below against the\n'
  printf 'scope: %s (default: the whole repo if no scope is given).\n\n' "$args_tok"
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2' "$f"
}

# Escape a string for embedding inside a TOML basic string / triple-quote body.
toml_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# OpenCode agent mode for a command: plan-only / audit commands run read-only,
# everything else needs build mode (full tool access) to actually execute.
opencode_agent_for() {
  case "$1" in
    refine-prompt|migration-plan|migration-replan|draft-phase-adrs|migration-scan) echo plan ;;
    audit|migration-status|migration-gate|migration-final|setup-project-health|compare-v1) echo plan ;;
    *) echo build ;;
  esac
}

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
  done < <(find -L "$SRC_COMMANDS" -maxdepth 1 -name "*.md" -type f | sort)

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
  done < <(find -L "$SRC_COMMANDS" -maxdepth 1 -name "*.md" -type f | sort)

  log "       ($count commands)"
}

# ── Gemini CLI ──────────────────────────────────────────────────────────────
# Native global custom-command primitive: ~/.gemini/commands/<name>.toml
sync_gemini() {
  local target="${GEMINI_HOME:-$HOME/.gemini}"
  [ -d "$target" ] || return 0

  log ""
  log "=== Gemini CLI (~/.gemini/commands) ==="

  local cmds_dir="$target/commands"
  mkdir -p "$cmds_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local dst="$cmds_dir/$name.toml"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -f "$dst" ] && grep -q "$GEN_MARK" "$dst" 2>/dev/null; then
        [ "$APPLY" -eq 1 ] && rm "$dst"
        log "unlink $dst"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      {
        printf '# %s%s.md\n' "$GEN_MARK" "$name"
        printf 'description = "%s"\n\n' "$(toml_escape "$(cmd_description "$cmd_file")")"
        # Literal multiline string ('''…''') — TOML processes NO escapes inside it,
        # so backslashes/quotes in the command body survive verbatim. Bodies are
        # pre-verified to contain no ''' sequence (which would terminate it early).
        printf "prompt = '''\n"
        emit_exec_body "$cmd_file" "$name" '{{args}}'
        printf "\n'''\n"
      } > "$dst"
      log "toml   $name.toml"
    else
      log "would  $name -> $dst"
    fi
    count=$((count + 1))
  done < <(find -L "$SRC_COMMANDS" -maxdepth 1 -name "*.md" -type f | sort)

  log "       ($count commands)"
}

# ── OpenCode ──────────────────────────────────────────────────────────────--
# Native global commands: ~/.config/opencode/commands/<name>.md (user-level)
sync_opencode_global() {
  local target="${OPENCODE_HOME:-$HOME/.config/opencode}"
  [ -d "$target" ] || return 0

  log ""
  log "=== OpenCode (~/.config/opencode/commands) ==="

  local cmds_dir="$target/commands"
  mkdir -p "$cmds_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local dst="$cmds_dir/$name.md"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -f "$dst" ] && grep -q "$GEN_MARK" "$dst" 2>/dev/null; then
        [ "$APPLY" -eq 1 ] && rm "$dst"
        log "unlink $dst"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      {
        printf -- '---\n'
        printf 'description: %s\n' "$(cmd_description "$cmd_file")"
        printf 'agent: %s\n' "$(opencode_agent_for "$name")"
        printf '%s%s.md\n' "$GEN_MARK" "$name"
        printf -- '---\n\n'
        emit_exec_body "$cmd_file" "$name" '$ARGUMENTS'
      } > "$dst"
      log "cmd    $name.md ($(opencode_agent_for "$name"))"
    else
      log "would  $name -> $dst"
    fi
    count=$((count + 1))
  done < <(find -L "$SRC_COMMANDS" -maxdepth 1 -name "*.md" -type f | sort)

  log "       ($count commands)"
}

# ── Codex CLI ─────────────────────────────────────────────────────────────--
# Open Agent Skills, user-level: ~/.agents/skills/<name>/SKILL.md
sync_codex() {
  ([ -d "$HOME/.codex" ] || [ -d "$HOME/.agents" ]) || return 0
  local skills_dir="$HOME/.agents/skills"

  log ""
  log "=== Codex CLI (~/.agents/skills) ==="

  mkdir -p "$skills_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local skill_name; skill_name="$(echo "$name" | tr '[:upper:]_' '[:lower:]-' | sed 's/[^a-z0-9-]//g')"
    local skill_dir="$skills_dir/$skill_name"
    local skill_file="$skill_dir/SKILL.md"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -f "$skill_file" ] && grep -q "$GEN_MARK" "$skill_file" 2>/dev/null; then
        [ "$APPLY" -eq 1 ] && rm -rf "$skill_dir"
        log "unlink $skill_dir"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      mkdir -p "$skill_dir"
      {
        printf -- '---\n'
        printf 'name: %s\n' "$skill_name"
        printf 'description: %s\n' "$(cmd_description "$cmd_file")"
        printf 'metadata:\n'
        printf '  %s%s.md\n' "$GEN_MARK" "$name"
        printf -- '---\n\n'
        emit_exec_body "$cmd_file" "$name" 'the scope you name'
      } > "$skill_file"
      log "skill  $skill_name"
    else
      log "would  $skill_name -> $skill_file"
    fi
    count=$((count + 1))
  done < <(find -L "$SRC_COMMANDS" -maxdepth 1 -name "*.md" -type f | sort)

  log "       ($count skills)"
}

# ── Cursor / Windsurf / others — no GLOBAL surface, but covered LOCALLY ────────
# These tools have no global command primitive (only global RULES). That is NOT
# a dead end: their commands are installed PER-PROJECT at setup time by
# apply-adapter-sync.sh (Phase 4.8 of /setup-project) into each tool's native
# local command surface — Cursor .cursor/commands/, Windsurf/Cline workflows/,
# Copilot .github/prompts/, Continue .continue/prompts/, Aider CONVENTIONS.md.
# This note points the user there instead of reading as "unsupported".
note_rules_only_tools() {
  local notes=()
  [ -d "${CURSOR_HOME:-$HOME/.cursor}" ] && notes+=("Cursor — local: .cursor/commands/<name>.md")
  [ -d "$HOME/.windsurf" ] && notes+=("Windsurf — local: .windsurf/workflows/<name>.md")
  [ -d "$HOME/.codeium" ] && notes+=("Codeium — global RULES only; commands via local adapter if Windsurf")
  [ -d "$HOME/.continue" ] && notes+=("Continue — local: .continue/prompts/<name>.md")
  { [ -d "$HOME/.clinerules" ] || [ -d "$HOME/.cline" ]; } && notes+=("Cline — local: .clinerules/workflows/<name>.md")
  [ ${#notes[@]} -eq 0 ] && return 0
  log ""
  log "=== No GLOBAL command surface — installed PER-PROJECT at setup instead ==="
  log "       (run /setup-project-adapters in a repo → apply-adapter-sync.sh writes these)"
  local n; for n in "${notes[@]}"; do log "       $n"; done
}

# ── Main ────────────────────────────────────────────────────────────────────

log "════════════════════════════════════════════════════════════════"
log "  Universal cross-tool sync"
log "  Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo dry-run)"
log "════════════════════════════════════════════════════════════════"

sync_claude
sync_kimi
sync_qwen
sync_gemini
sync_opencode_global
sync_codex
note_rules_only_tools

log ""
if [ "$APPLY" -eq 0 ]; then
  log "DRY RUN — re-run with --apply to perform the actions above."
fi

if [ "$drift" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
  exit 1
fi
