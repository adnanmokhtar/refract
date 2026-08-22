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
#                     Kimi / Qwen / Gemini / OpenCode / Codex GLOBAL dirs maps to a core
#                     command name. All FIVE generated surfaces are scanned. Qwen and Codex
#                     were unaudited here: Qwen because its artifacts carried no generation
#                     marker at all (verbatim `cp`, so nothing to recognise) and Codex because
#                     ~/.agents/skills was simply never added to the loop. Two of the six
#                     surfaces could take a pack-command leak with nothing noticing.
#   [5] SHIP INTEGRITY  (static, CI-safe): every helper a script in scripts/ sources is
#                     present on disk (FAIL) and tracked in git (WARN). `git commit -a`
#                     stages tracked modifications but never adds an untracked file, so a
#                     newly extracted shared helper can be left behind while its consumers
#                     ship — the three adapter scripts then die at the `.` line, exit 1,
#                     before doing any work. Every other gate reads the working tree, where
#                     the helper is present, so the suite stays green over a lane that is
#                     broken on a fresh clone. This is the only check that looks at what
#                     actually ships rather than at what is merely on disk.
#   [6] TARGET WRITE SAFETY (static, CI-safe): every analysis script whose report sink is
#                     a path under `$TARGET` offers a read-only mode (`--stdout` /
#                     `--no-write`). Without one, RUNNING the analysis IS a write to the
#                     analysed repo, so "check this project without touching it" is not an
#                     operation that exists. Observed 2026-08-22: three audit scripts
#                     regenerated their reports inside a project declared read-only,
#                     purely because someone ran them to verify a fix. `apply-*` scripts
#                     are exempt — writing is their job, and they are dry-run by default.
#
# Exit codes: 0 ok / 1 scope violation.
# Notes: bash 3.2 (macOS) compatible — no associative arrays, mapfile, or ${var,,}.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
KIMI_HOME="${KIMI_HOME:-$HOME/.kimi}"
QWEN_HOME="${QWEN_HOME:-$HOME/.qwen}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/.gemini}"
OPENCODE_HOME="${OPENCODE_HOME:-$HOME/.config/opencode}"
# Codex's user-level Agent Skills live under ~/.agents, NOT ~/.codex.
# Source: https://developers.openai.com/codex/skills (308 -> learn.chatgpt.com/docs/build-skills),
# which lists discovery precedence $CWD/.agents/skills -> $REPO_ROOT/.agents/skills ->
# $HOME/.agents/skills (user) -> /etc/codex/skills (admin), each skill being "a directory with a
# SKILL.md file". Fetched 2026-08-21; URL recorded in codex/_version.json docs_urls. Cite the
# vendor doc, not codex/adapter.md — an internal doc is not a source for a vendor path.
CODEX_SKILLS_HOME="${CODEX_SKILLS_HOME:-$HOME/.agents}"

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
echo "[4] downstream global surfaces (Kimi / Qwen / Gemini / OpenCode / Codex) — repo-managed artifacts map to a core command"
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

# Qwen: ~/.qwen/commands/<name>.md
if [ -d "$QWEN_HOME/commands" ]; then
  downstream_seen=1
  for f in "$QWEN_HOME"/commands/*.md; do
    [ -f "$f" ] || continue
    has_mark "$f" || continue
    flag_downstream "Qwen" "~/.qwen/commands/$(basename "$f")" "$(basename "$f" .md)"
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

# Codex: ~/.agents/skills/<name>/SKILL.md
if [ -d "$CODEX_SKILLS_HOME/skills" ]; then
  downstream_seen=1
  for d in "$CODEX_SKILLS_HOME"/skills/*/; do
    [ -d "$d" ] || continue
    sf="${d%/}/SKILL.md"
    [ -f "$sf" ] || continue
    has_mark "$sf" || continue
    flag_downstream "Codex" "~/.agents/skills/$(basename "$d")" "$(basename "$d")"
  done
fi

if [ "$downstream_seen" -eq 0 ]; then
  echo "  skip — no downstream global tool dirs present"
  warns=$((warns + 1))
elif [ "$downstream_ok" -eq 1 ]; then
  echo "  ok — downstream global surfaces carry only core commands"
fi

# ── [5] ship integrity ──────────────────────────────────────────────────────
# The sync lane is only as installable as the files that actually ship. When the shared
# emitters were extracted out of sync-to-global.sh / apply-adapter-sync.sh /
# audit-adapter-coverage.sh into one sourced helper, the three consumers were tracked
# modifications but the helper was a NEW file — and `git commit -a` stages modifications
# to tracked files while never adding an untracked one. The three scripts could therefore
# land without their dependency and die at the `.` line, exit 1, before doing any work.
# Nothing caught it: every other gate reads the working tree, where the untracked helper
# is present, so the whole suite stayed green over a lane that was broken on a fresh clone.
#
# Two levels, because the two failure modes differ in certainty:
#   FAIL — a sourced helper is absent from disk. Always wrong, and the invariant that
#          keeps a rename or delete from silently decapitating its consumers.
#   WARN — the helper is on disk but untracked (and not ignored). Correct in this working
#          tree, broken for everyone who clones. Not a FAIL because the remedy is a git
#          write, which the gate must never perform and CI cannot assume has happened yet.
echo "[5] ship integrity — every helper the scripts source exists and is committed"
ship_ok=1
# `. "$VAR/path"` / `source "$VAR/path"`, where VAR is always a repo-root or script-dir
# anchor resolved from BASH_SOURCE. Strip the keyword and the variable, keep the literal
# tail, then resolve it against the repo root and against scripts/.
src_refs="$(grep -hoE '^[[:space:]]*(\.|source)[[:space:]]+"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/[^"]+"' \
              "$REPO_ROOT"/scripts/*.sh 2>/dev/null \
            | sed -E 's/^[[:space:]]*(\.|source)[[:space:]]+"//; s/^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?\///; s/"$//' \
            | sort -u || true)"
# Tracked-file lookups need a real git checkout; a tarball export or a vendored copy has
# none, so the WARN half is skipped there rather than firing on every file.
have_git=0
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  have_git=1
fi
for rel in $src_refs; do
  [ -n "$rel" ] || continue
  helper=""
  for cand in "$REPO_ROOT/$rel" "$REPO_ROOT/scripts/$rel"; do
    [ -f "$cand" ] && { helper="$cand"; break; }
  done
  if [ -z "$helper" ]; then
    echo "  FAIL — sourced helper '$rel' is not on disk"
    echo "         (every script that sources it dies at the '.' line, exit 1, before doing any work)"
    ship_ok=0
    fails=$((fails + 1))
    continue
  fi
  [ "$have_git" -eq 1 ] || continue
  path_rel="${helper#$REPO_ROOT/}"
  git -C "$REPO_ROOT" ls-files --error-unmatch -- "$path_rel" >/dev/null 2>&1 && continue
  # Ignored files are deliberately absent from the shipped set — not a ship defect.
  git -C "$REPO_ROOT" check-ignore -q -- "$path_rel" 2>/dev/null && continue
  echo "  WARN — $path_rel is sourced by a tracked script but is NOT tracked itself"
  base_re="$(basename "$helper" | sed 's/[.[\*^$]/\\&/g')"
  for consumer in $(grep -lE '^[[:space:]]*(\.|source)[[:space:]]+".*/'"$base_re"'"$' "$REPO_ROOT"/scripts/*.sh 2>/dev/null); do
    echo "         consumer: scripts/$(basename "$consumer") — exit 1 on a fresh clone"
  done
  echo "         fix: git add $path_rel   (must be in the SAME commit as its consumers)"
  ship_ok=0
  warns=$((warns + 1))
done
[ "$ship_ok" -eq 1 ] && echo "  ok — every sourced helper is present and tracked"

# ── [6] target write safety ─────────────────────────────────────────────────
# An analysis script that sinks its report INSIDE the repo it is analysing makes every
# invocation a modification of that repo. There is then no way to answer "is this project
# healthy?" without changing it — and the person most likely to run it is exactly the
# person who was told not to touch the target. That is not hypothetical: on 2026-08-22 an
# agent verifying a fix "against the real target, read-only" ran three of these scripts
# and regenerated three reports inside the protected project, because the verification
# WAS the write. The remedy is a flag, and this check is what keeps it from rotting away:
# a new analysis script with a $TARGET-side report sink and no read-only mode fails here.
#
# Detection is deliberately narrow and named as such: it matches the `REPORT*="$TARGET/…"`
# sink assignment, which is the shape every one of these scripts uses. It does not claim to
# find every possible write into a target — a script that writes by some other route is
# outside what this check can see, and the comment says so rather than implying coverage
# the code does not have.
echo "[6] target write safety — analysis scripts can run without writing to the target"
tws_ok=1
for f in "$REPO_ROOT"/scripts/*.sh; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  # apply-*: writing the target is the contract. They are dry-run by default and take
  # --apply to write, which is the read-only affordance in their idiom.
  case "$base" in apply-*) continue ;; esac
  grep -qE '^[A-Z_]*REPORT[A-Z_]*="\$TARGET/' "$f" || continue
  # The flag must exist as a real case arm, not merely be mentioned in a comment.
  if grep -qE '^[[:space:]]*--(stdout|no-write)[)|]' "$f"; then
    continue
  fi
  echo "  FAIL — scripts/$base sinks its report under \$TARGET but has no --stdout / --no-write arm"
  echo "         (running it to CHECK the target modifies the target; add the read-only mode)"
  tws_ok=0
  fails=$((fails + 1))
done
[ "$tws_ok" -eq 1 ] && echo "  ok — every \$TARGET-sinking analysis script offers a read-only mode"

# ── summary ─────────────────────────────────────────────────────────────────
echo ""
echo "global-scope: FAIL=$fails WARN=$warns"
[ "$fails" -eq 0 ] || exit 1
