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
#   Kimi Code    -> ~/.kimi/skills/<cmd>/SKILL.md             (generated skill)
#   Qwen Code    -> ~/.qwen/commands/<cmd>.md                 (generated command)
#   Gemini CLI   -> ~/.gemini/commands/<cmd>.toml             (TOML custom command)
#   OpenCode     -> ~/.config/opencode/commands/<cmd>.md      (native md + agent: field)
#   Codex CLI    -> ~/.agents/skills/<cmd>/SKILL.md           (Open Agent Skills, user-level)
#
# Every generated artifact goes through scripts/_adapter-emit.sh, which is also what
# the PER-PROJECT lane (apply-adapter-sync.sh) uses. Three invariants ride on that:
#   - EXECUTE NOW preamble on every ported command, or it loads as inert reference;
#   - GEN_MARK in every generated file, or --unlink cannot uninstall it;
#   - descriptions emitted as quoted YAML scalars, or one ": " upstream breaks the
#     frontmatter in four tools at once.
#
# Non-Claude tools also get <toolhome>/refract/{templates,scripts} — symlinks into
# this repo — because ported bodies link to ../templates/ and ../scripts/, which
# resolve only under ~/.claude. See "Companion payload" below.
#
# Honest no-ops (these tools have NO global command primitive — only global
# rules, which are out of scope for command sync). Each prints a pointer at its
# per-project surface via note_rules_only_tools():
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

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
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
      # Print the whole leading comment block. A fixed line range silently truncated
      # the help text every time this header grew.
      awk 'NR==1 { next } /^#/ { print; next } { exit }' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERR:  %s\n' "$*" >&2; }

# Shared emitters — GEN_MARK / GEN_MARK_LEGACY / is_generated / yaml_scalar /
# toml_escape / cmd_description / emit_exec_body / opencode_classify_command_agent /
# emit_<tool>_* . The PER-PROJECT lane (apply-adapter-sync.sh) sources the same file,
# so a shape fix lands on both surfaces in one commit and the two lanes cannot drift
# into emitting different bytes for the same command again.
# shellcheck source=scripts/_adapter-emit.sh
. "$REPO_ROOT/scripts/_adapter-emit.sh"

# ── Companion payload ───────────────────────────────────────────────────────
# Ported command bodies carry repo-relative links: 41 of them across 9 of the 15
# commands, led by ../templates/governance/core-discipline.md (x8),
# ../templates/snippets/plan-flag.md (x7) and ../scripts/delegate-relay.sh (x2).
#
# Under Claude Code they resolve, because ~/.claude/{templates,scripts} mirror the
# repo layout. Nowhere else. From ~/.kimi/skills/<n>/, ~/.agents/skills/<n>/,
# ~/.qwen/commands/, ~/.config/opencode/commands/ or a Gemini TOML body, every one
# of them resolves to nothing — while the EXECUTE NOW preamble has just instructed
# the tool to run a workflow whose mandatory reads 404.
#
# /delegate is the sharp case: templates/tool-adapters/_delegate-integration-coverage.md
# states "a translated /delegate with no relay on disk is a document, not a command",
# and sync_claude() is the only function that ever installed scripts/ — so a
# Kimi-only or Qwen-only user got exactly that document.
#
# Fix: every non-Claude tool home gets <toolhome>/refract/{templates,scripts} as
# symlinks back into this repo, and emit_exec_body() rewrites the ../ links to that
# absolute path. One symlink per tree — no copying, never stale, and --unlink can
# remove it because we only ever delete a symlink that points inside this repo.
COMPANION_SUBDIRS="templates scripts"

companion_root() { printf '%s/refract' "$1"; }

# True when $1 is a symlink resolving inside this repo (i.e. one we created).
is_our_symlink() {
  [ -L "$1" ] || return 1
  case "$(readlink "$1")" in
    "$REPO_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

install_companion() {  # $1 = tool home, $2 = label
  local home_dir="$1" label="$2" root sub src dst
  root="$(companion_root "$home_dir")"
  for sub in $COMPANION_SUBDIRS; do
    src="$REPO_ROOT/$sub"; dst="$root/$sub"
    [ -d "$src" ] || continue
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      log "ok     companion $label/refract/$sub"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
      if [ "$FORCE" -eq 1 ]; then
        if [ "$APPLY" -eq 1 ]; then rm -rf "$dst"; mkdir -p "$root"; ln -s "$src" "$dst"; fi
        log "relink companion $label/refract/$sub"
      else
        warn "exists $dst (not our symlink); use --force"
        drift=1
      fi
    else
      if [ "$APPLY" -eq 1 ]; then
        mkdir -p "$root"; ln -s "$src" "$dst"
        log "link   companion $label/refract/$sub -> $src"
      else
        log "would  companion $label/refract/$sub -> $src"
      fi
    fi
  done
}

remove_companion() {  # $1 = tool home
  local home_dir="$1" root sub dst
  root="$(companion_root "$home_dir")"
  [ -d "$root" ] || return 0
  for sub in $COMPANION_SUBDIRS; do
    dst="$root/$sub"
    if is_our_symlink "$dst"; then
      [ "$APPLY" -eq 1 ] && rm "$dst"
      log "unlink $dst"
    fi
  done
  if [ "$APPLY" -eq 1 ]; then rmdir "$root" 2>/dev/null || true; fi
  return 0
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
  local companion; companion="$(companion_root "$target")"
  if [ "$UNLINK" -eq 1 ]; then remove_companion "$target"; else install_companion "$target" "Kimi"; fi
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
        # Check if managed by us (current or pre-rename metadata marker)
        if is_generated "$skill_file"; then
          [ "$APPLY" -eq 1 ] && rm -rf "$skill_dir"
          log "unlink $skill_dir"
        fi
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      mkdir -p "$skill_dir"
      emit_kimi_skill "$cmd_file" "$skill_name" "$companion" > "$skill_file"
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
  local companion; companion="$(companion_root "$target")"
  if [ "$UNLINK" -eq 1 ]; then remove_companion "$target"; else install_companion "$target" "Qwen"; fi
  mkdir -p "$cmds_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local dst="$cmds_dir/$name.md"

    if [ "$UNLINK" -eq 1 ]; then
      # Marker-based, NOT content-hash. `cmp -s "$cmd_file" "$dst"` matched only a
      # byte-identical copy of the source, so ONE upstream edit orphaned the installed
      # file permanently: --unlink walked past it and every other tool cleaned to zero
      # while Qwen kept a file the user could not remove. Qwen was the only surface with
      # that property, and the only one verify-global-scope.sh check [4] could not see.
      if [ -f "$dst" ] && is_generated "$dst"; then
        [ "$APPLY" -eq 1 ] && rm "$dst"
        log "unlink $dst"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      emit_qwen_command "$cmd_file" "$name" "$companion" > "$dst"
      log "cmd    $name.md"
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
  local companion; companion="$(companion_root "$target")"
  if [ "$UNLINK" -eq 1 ]; then remove_companion "$target"; else install_companion "$target" "Gemini"; fi
  mkdir -p "$cmds_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local dst="$cmds_dir/$name.toml"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -f "$dst" ] && is_generated "$dst"; then
        [ "$APPLY" -eq 1 ] && rm "$dst"
        log "unlink $dst"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      emit_gemini_toml "$cmd_file" "$name" "$companion" > "$dst"
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
  local companion; companion="$(companion_root "$target")"
  if [ "$UNLINK" -eq 1 ]; then remove_companion "$target"; else install_companion "$target" "OpenCode"; fi
  mkdir -p "$cmds_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local dst="$cmds_dir/$name.md"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -f "$dst" ] && is_generated "$dst"; then
        [ "$APPLY" -eq 1 ] && rm "$dst"
        log "unlink $dst"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      emit_opencode_command "$cmd_file" "$name" "$companion" > "$dst"
      log "cmd    $name.md ($(opencode_classify_command_agent "$cmd_file"))"
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
  local agents_home="$HOME/.agents"
  local skills_dir="$agents_home/skills"

  log ""
  log "=== Codex CLI (~/.agents/skills) ==="

  local companion; companion="$(companion_root "$agents_home")"
  if [ "$UNLINK" -eq 1 ]; then remove_companion "$agents_home"; else install_companion "$agents_home" "Codex"; fi
  mkdir -p "$skills_dir"
  local count=0

  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    local name; name="$(basename "$cmd_file" .md)"
    local skill_name; skill_name="$(echo "$name" | tr '[:upper:]_' '[:lower:]-' | sed 's/[^a-z0-9-]//g')"
    local skill_dir="$skills_dir/$skill_name"
    local skill_file="$skill_dir/SKILL.md"

    if [ "$UNLINK" -eq 1 ]; then
      if [ -f "$skill_file" ] && is_generated "$skill_file"; then
        [ "$APPLY" -eq 1 ] && rm -rf "$skill_dir"
        log "unlink $skill_dir"
      fi
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      mkdir -p "$skill_dir"
      emit_codex_skill "$cmd_file" "$skill_name" "$companion" > "$skill_file"
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
  [ -d "${CURSOR_HOME:-$HOME/.cursor}" ] && notes+=("Cursor — local: .cursor/skills/<name>/SKILL.md (PRIMARY), .cursor/commands/<name>.md (fallback)")
  [ -d "$HOME/.windsurf" ] && notes+=("Windsurf — local: .windsurf/workflows/<name>.md")
  [ -d "$HOME/.codeium" ] && notes+=("Codeium — global RULES only; commands via local adapter if Windsurf")
  [ -d "$HOME/.continue" ] && notes+=("Continue — local: .continue/prompts/<name>.md")
  { [ -d "$HOME/.clinerules" ] || [ -d "$HOME/.cline" ]; } && notes+=("Cline — local: .cline/skills/<name>/SKILL.md (PRIMARY), .clinerules/workflows/<name>.md (fallback)")
  # Aider and Copilot were named in this script's header as honest no-ops but had no
  # branch here, so an Aider-only or Copilot-only user ran the sync and got nothing at
  # all — not even the pointer the other five print. Header and behaviour now agree.
  { [ -f "$HOME/.aider.conf.yml" ] || [ -d "$HOME/.aider" ]; } && notes+=("Aider — local: CONVENTIONS.md § User-invoked procedures (single-doc tool)")
  { [ -d "$HOME/.config/github-copilot" ] || [ -d "$HOME/.copilot" ]; } && notes+=("Copilot — local: .github/prompts/<name>.prompt.md")
  [ ${#notes[@]} -eq 0 ] && return 0
  log ""
  log "=== No GLOBAL command surface — installed PER-PROJECT at setup instead ==="
  log "       (run /setup-project-adapters in a repo → apply-adapter-sync.sh writes these)"
  log "       BOOTSTRAP CAVEAT: /setup-project-adapters is a Claude Code slash command and"
  log "       apply-adapter-sync.sh refuses without <repo>/.claude/, which only /setup-project"
  log "       creates. A user with NONE of the six global tools has no path to these files that"
  log "       does not route through Claude Code at least once. That is a real gap, not an"
  log "       oversight in this message — do not read the pointer as a promise it can be followed."
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
