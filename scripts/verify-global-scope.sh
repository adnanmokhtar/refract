#!/usr/bin/env bash
# verify-global-scope.sh — the GLOBAL command surface is core-only; pack commands stay per-project.
#
# Enforces the invariant restored when the migration suite was de-globalised: the
# cross-tool GLOBAL command set == this repo's commands/ directory ONLY. Pack commands
# (templates/packs/<pack>/commands/*) are PROJECT-scoped — /setup-project installs them
# per-repo and apply-adapter-sync.sh ports them per-repo. They must NEVER appear on a
# global surface, or a single stray `ln -s` re-bloats every tool (the exact defect this
# gate was written to prevent recurring).
#
# Checks:
#   [1] CONTRACT      (static, CI-safe): sync-to-global.sh sources the global set from
#                     commands/ — NOT ~/.claude/commands — so stray symlinks can't leak.
#   [2] SOURCE PURITY (static, CI-safe): no pack command file is duplicated into commands/.
#   [3] CLAUDE SURFACE   (live; skipped if ~/.claude absent): no ~/.claude/commands entry
#                     resolves into templates/packs/ (a pack command leaked into global).
#   [4] DOWNSTREAM       (live; skipped per absent tool): every repo-managed artifact in the
#                     Kimi / Gemini / OpenCode GLOBAL dirs maps to a core command name.
#
# Exit codes: 0 ok / 1 scope violation.
# Notes: bash 3.2 (macOS) compatible — no associative arrays, mapfile, or ${var,,}.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
KIMI_HOME="${KIMI_HOME:-$HOME/.kimi}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/.gemini}"
OPENCODE_HOME="${OPENCODE_HOME:-$HOME/.config/opencode}"

SYNC_SCRIPT="$REPO_ROOT/scripts/sync-to-global.sh"
CORE_DIR="$REPO_ROOT/commands"
MARK="source: refract/commands/"
# Pre-rename marker (the project was called claude-config). Artifacts generated before
# the rename still carry it, so scope checks must recognise both or older installs go
# silently unaudited.
MARK_LEGACY="source: claude-config/commands/"

# True when a downstream file carries the current OR the pre-rename sync marker.
has_mark() {
  grep -qF "$MARK" "$1" 2>/dev/null || grep -qF "$MARK_LEGACY" "$1" 2>/dev/null
}

fails=0
warns=0

# Core command name set (basenames, no .md) — the canonical global allow-list.
core_names="$(cd "$CORE_DIR" && ls -1 *.md 2>/dev/null | sed 's/\.md$//' || true)"

is_core() {  # $1 = command basename without extension
  printf '%s\n' "$core_names" | grep -qxF "$1"
}

# ── [1] contract ────────────────────────────────────────────────────────────
echo "[1] sync contract — global set sourced from commands/, not ~/.claude/commands"
if grep -qE '^SRC_COMMANDS=.*\$REPO_ROOT/commands' "$SYNC_SCRIPT"; then
  echo "  ok — SRC_COMMANDS defaults to \$REPO_ROOT/commands"
else
  echo "  FAIL — sync-to-global.sh SRC_COMMANDS no longer defaults to \$REPO_ROOT/commands"
  echo "         (sourcing the global set from ~/.claude/commands re-leaks pack commands to every tool)"
  fails=$((fails + 1))
fi
if grep -qE '^SRC_COMMANDS=.*\.claude/commands' "$SYNC_SCRIPT"; then
  echo "  FAIL — sync-to-global.sh still defaults the command source to ~/.claude/commands"
  fails=$((fails + 1))
fi

# ── [2] source purity ───────────────────────────────────────────────────────
# A name may legitimately exist in BOTH commands/ (core, global) and a pack — the
# sanctioned override pattern, where the core command routes to a pack's stack-specific
# variant (e.g. /refactor → templates/packs/<track>/commands/refactor.md). That is NOT a
# leak. A leak is a genuinely pack-scoped command appearing in commands/ (it would be
# globally installed). So: flag any commands/ file whose name is ALSO a pack command,
# UNLESS it is an explicitly sanctioned override below.
OVERRIDE_OK="refactor"
echo "[2] source purity — commands/ holds only core commands + sanctioned overrides ($OVERRIDE_OK)"
purity_ok=1
pack_names="$(find "$REPO_ROOT/templates/packs" -path '*/commands/*.md' -type f 2>/dev/null \
  | sed 's#.*/commands/##; s/\.md$//' | sort -u || true)"
for f in "$CORE_DIR"/*.md; do
  [ -e "$f" ] || continue
  b="$(basename "$f" .md)"
  printf '%s\n' "$pack_names" | grep -qxF "$b" || continue   # not a pack name → core-only → fine
  case " $OVERRIDE_OK " in
    *" $b "*) continue ;;                                     # sanctioned override → fine
  esac
  echo "  FAIL — commands/$b.md shares a name with a pack command and is not a sanctioned override"
  echo "         (it would be globally installed; keep it pack-only, or add '$b' to OVERRIDE_OK if promotion is intended)"
  purity_ok=0
  fails=$((fails + 1))
done
[ "$purity_ok" -eq 1 ] && echo "  ok — commands/ holds only core commands + sanctioned overrides"

# ── [3] Claude global surface ───────────────────────────────────────────────
echo "[3] Claude global surface — no ~/.claude/commands entry resolves into templates/packs/"
if [ -d "$CLAUDE_HOME/commands" ]; then
  surface_ok=1
  for l in "$CLAUDE_HOME"/commands/*.md; do
    { [ -e "$l" ] || [ -L "$l" ]; } || continue
    [ -L "$l" ] || continue
    tgt="$(readlink "$l")"
    case "$tgt" in
      */templates/packs/*)
        echo "  FAIL — $(basename "$l") -> $tgt"
        echo "         (pack command leaked into the global surface; remove this symlink — it installs per-project)"
        surface_ok=0
        fails=$((fails + 1))
        ;;
    esac
  done
  [ "$surface_ok" -eq 1 ] && echo "  ok — ~/.claude/commands carries no pack command"
else
  echo "  skip — ~/.claude/commands absent (CI or unsynced machine)"
  warns=$((warns + 1))
fi

# ── [4] downstream global surfaces ──────────────────────────────────────────
echo "[4] downstream global surfaces — repo-managed artifacts map to a core command"
downstream_seen=0
downstream_ok=1

flag_downstream() {  # $1 = tool label, $2 = artifact path, $3 = derived name
  if ! is_core "$3"; then
    echo "  FAIL — $1 $2 is repo-managed (carries the sync marker) but '$3' is not a core command"
    downstream_ok=0
    fails=$((fails + 1))
  fi
}

# Kimi: ~/.kimi/skills/<name>/SKILL.md
if [ -d "$KIMI_HOME/skills" ]; then
  downstream_seen=1
  for d in "$KIMI_HOME"/skills/*/; do
    [ -d "$d" ] || continue
    sf="${d%/}/SKILL.md"
    [ -f "$sf" ] || continue
    has_mark "$sf" || continue
    flag_downstream "Kimi" "~/.kimi/skills/$(basename "$d")" "$(basename "$d")"
  done
fi

# Gemini: ~/.gemini/commands/<name>.toml
if [ -d "$GEMINI_HOME/commands" ]; then
  downstream_seen=1
  for f in "$GEMINI_HOME"/commands/*.toml; do
    [ -f "$f" ] || continue
    has_mark "$f" || continue
    flag_downstream "Gemini" "~/.gemini/commands/$(basename "$f")" "$(basename "$f" .toml)"
  done
fi

# OpenCode: ~/.config/opencode/commands/<name>.md
if [ -d "$OPENCODE_HOME/commands" ]; then
  downstream_seen=1
  for f in "$OPENCODE_HOME"/commands/*.md; do
    [ -f "$f" ] || continue
    has_mark "$f" || continue
    flag_downstream "OpenCode" "~/.config/opencode/commands/$(basename "$f")" "$(basename "$f" .md)"
  done
fi

if [ "$downstream_seen" -eq 0 ]; then
  echo "  skip — no downstream global tool dirs present"
  warns=$((warns + 1))
elif [ "$downstream_ok" -eq 1 ]; then
  echo "  ok — downstream global surfaces carry only core commands"
fi

# ── summary ─────────────────────────────────────────────────────────────────
echo ""
echo "global-scope: FAIL=$fails WARN=$warns"
[ "$fails" -eq 0 ] || exit 1
