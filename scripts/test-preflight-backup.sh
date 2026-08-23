#!/usr/bin/env bash
# test-preflight-backup.sh — fixture suite for the ONE promise M35 makes: "the agent never
# decides whether to back up". run-preflight.sh decides, and this pins the decision.
#
# WHY. On the delivery run this suite was written for, the preflight announced
#   [backup] recent backup exists (<60 min): .claude/backups/20260823-0515 — not duplicating
# at 14:09. The directory's own NAME says 05:15 — 8 h 54 m earlier. The freshness test was
# `find -mmin -60`, which asks the filesystem how old the DIRECTORY is, and a `git reset` had
# just refreshed the mtimes of the tracked files inside it. The run then rewrote 107 files.
# The thing it deferred to held exactly one file, 683 bytes, against a setup of 286 — so the
# run proceeded with no usable backup of the layer it was about to rewrite.
#
# Two properties, therefore, and both are asserted here:
#   § 1  age comes from the NAME the script itself encoded, never from the mtime;
#   § 2  a candidate must actually HOLD a backup — a one-file directory is not one;
#   § 3  a genuinely fresh, genuinely populated backup is still skipped (no thrash).
#
# Everything runs under mktemp -d. Nothing is written outside it.
#
# Usage: test-preflight-backup.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

PREFLIGHT="$REPO_ROOT/scripts/run-preflight.sh"
QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }
pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

[ -f "$PREFLIGHT" ] || { echo "ERR: $PREFLIGHT not found" >&2; exit 1; }

TD=$(mktemp -d "${TMPDIR:-/tmp}/test-preflight-backup.XXXXXX")
trap 'rm -rf "$TD"' EXIT

# A target with a real setup surface to back up: 70 files under .claude/ + ai/.
seed_target() {
  local r="$1"
  mkdir -p "$r/.claude/commands" "$r/ai/patterns"
  local i
  for i in $(seq 1 40); do printf 'cmd %s\n' "$i" > "$r/.claude/commands/c$i.md"; done
  for i in $(seq 1 30); do printf 'pat %s\n' "$i" > "$r/ai/patterns/p$i.md"; done
  printf 'CLAUDE\n' > "$r/CLAUDE.md"
}

# Did a real backup of the setup surface land anywhere under .claude/backups/? Counting
# DIRECTORIES is not enough — two runs in the same minute used to share one directory name —
# so count FILES, and require the backup to cover most of the live setup.
backup_files() { find "$1/.claude/backups" -type f 2>/dev/null | grep -c . || true; }
live_files()   { find "$1/.claude" "$1/ai" -type f -not -path '*/backups/*' 2>/dev/null | grep -c . || true; }
# Compare against the setup size measured BEFORE the run: the preflight legitimately writes
# new files of its own (_codebase-scan.md, the coverage report…) after the backup is taken, and
# a backup is not required to contain files that did not exist when it ran.
backed_up()    { [ "$(backup_files "$1")" -ge "$2" ]; }

# ── § 1  old NAME + fresh mtime: the exact shape a git reset produces ─────────────────────
say "§ 1  a backup whose NAME is hours old is not recent, whatever its mtime says"
P1="$TD/mtime-lie"; seed_target "$P1"
PLANT1="20260101-0515"
mkdir -p "$P1/.claude/backups/$PLANT1/.claude/commands"
cp "$P1"/.claude/commands/*.md "$P1/.claude/backups/$PLANT1/.claude/commands/"
touch "$P1/.claude/backups/$PLANT1"        # the git-reset effect: mtime = now
LIVE1=$(live_files "$P1")
out1=$(bash "$PREFLIGHT" "$P1" --mode=ENHANCE-extend 2>&1)
if printf '%s' "$out1" | grep -q 'not duplicating'; then
  bad "§1 a stale-named backup is not treated as recent" "preflight said: $(printf '%s' "$out1" | grep 'not duplicating' | head -1)"
else
  ok "§1 a stale-named backup is not treated as recent"
fi
if backed_up "$P1" "$LIVE1"; then
  ok "§1 a real backup was taken ($(backup_files "$P1") files under backups/, $LIVE1 live before the run)"
else
  bad "§1 a real backup was taken" "only $(backup_files "$P1") file(s) under .claude/backups/ against $LIVE1 live setup files"
fi

# ── § 2  fresh name, but the directory holds one token file ───────────────────────────────
say "§ 2  a one-file directory is not a backup of a 70-file setup"
P2="$TD/token"; seed_target "$P2"
PLANT2="$(date +%Y%m%d-%H%M)"
mkdir -p "$P2/.claude/backups/$PLANT2/.claude"
printf '{"x":1}\n' > "$P2/.claude/backups/$PLANT2/.claude/settings.local.json"
LIVE2=$(live_files "$P2")
out2=$(bash "$PREFLIGHT" "$P2" --mode=ENHANCE-extend 2>&1)
if printf '%s' "$out2" | grep -q 'not duplicating'; then
  bad "§2 a partial snapshot is not accepted as the backup" "preflight deferred to a 1-file directory"
else
  ok "§2 a partial snapshot is not accepted as the backup"
fi
if backed_up "$P2" "$LIVE2"; then
  ok "§2 a real backup was taken ($(backup_files "$P2") files under backups/, $LIVE2 live before the run)"
else
  bad "§2 a real backup was taken" "only $(backup_files "$P2") file(s) under .claude/backups/ against $LIVE2 live setup files"
fi

# ── § 3  fresh AND populated: skipping is correct, and must still happen ──────────────────
say "§ 3  a genuinely fresh, genuinely populated backup is still skipped"
P3="$TD/genuine"; seed_target "$P3"
PLANT3="$(date +%Y%m%d-%H%M)"
mkdir -p "$P3/.claude/backups/$PLANT3/.claude/commands"
cp "$P3"/.claude/commands/*.md "$P3/.claude/backups/$PLANT3/.claude/commands/"
out3=$(bash "$PREFLIGHT" "$P3" --mode=ENHANCE-extend 2>&1)
if printf '%s' "$out3" | grep -q 'not duplicating'; then
  ok "§3 the fresh backup was reused"
else
  bad "§3 the fresh backup was reused" "preflight took a redundant backup"
fi

say ""
say "preflight-backup fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
