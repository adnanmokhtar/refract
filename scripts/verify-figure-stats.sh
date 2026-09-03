#!/usr/bin/env bash
# verify-figure-stats.sh — the numbers drawn INTO the README figures must match disk.
#
# WHY. verify-readme-stats.sh checks the README's prose and table, and verify-pack-matrix.sh
# checks assets/pack-matrix.svg. Nothing checked the other three figures, and they carry
# counts too — drawn as text inside the SVG, where no reader can tell they are two days old.
#
# MEASURED 2026-08-24, two days after the figures were last re-derived:
#   assets/architecture.svg   "73 validators + sync scripts"  — actual 74
#   assets/command-map.svg    "25 of the 133 pack commands advertise it" (--plan) — actual 27
# Both are on the front page. A figure is the first thing a reader trusts and the last thing
# anyone regenerates, which is exactly why it needs a gate rather than a habit.
#
# Only counts that are DERIVABLE are checked. A figure may legitimately carry a dated capture
# ("2026-08-22 · macOS 26.5.1", the elided-line notes in terminal-sync.svg) — that is a record
# of a real run, not a live claim, and it does not go stale. Those are left alone deliberately.
#
# Usage: verify-figure-stats.sh [--quiet]
# Exit:  0 every derivable figure count matches disk / 1 one does not
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
cd "$REPO_ROOT" || exit 1

QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

# ── derive from disk, the same way verify-readme-stats.sh does ────────────────
PACKS=$(find templates/packs -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
ADAPTERS=$(find templates/tool-adapters -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
GLOBCMD=$(find commands -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
PACKCMD=$(find templates/packs -path '*/commands/*' -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
# "validators + sync scripts" is scripts/ minus the test harnesses — the figure's own wording.
TOOLING=$(find scripts -maxdepth 1 \( -name '*.sh' -o -name '*.py' \) 2>/dev/null | grep -v '/test-' | wc -l | tr -d ' ')
PLANCMD=$(grep -rl -- '--plan' templates/packs/*/commands/*.md 2>/dev/null | wc -l | tr -d ' ')

fail=0
# check <file> <regex with one capture> <expected> <label>
check() {
  local f="$1" re="$2" want="$3" label="$4" got
  [ -f "$f" ] || { printf '  FAIL %s is missing\n' "$f"; fail=$((fail+1)); return; }
  got=$(grep -oE "$re" "$f" 2>/dev/null | head -1 | grep -oE '^[0-9]+')
  if [ -z "$got" ]; then
    printf '  FAIL %s: no "%s" figure found — did the wording change?\n' "${f#./}" "$label"
    printf '       This gate is keyed to the drawn text; update the pattern with the wording.\n'
    fail=$((fail+1)); return
  fi
  if [ "$got" = "$want" ]; then
    say "  ok   ${f#./}: $label = $got"
  else
    printf '  FAIL %s: %s reads %s, disk says %s\n' "${f#./}" "$label" "$got" "$want"
    fail=$((fail+1))
  fi
}

check assets/architecture.svg '[0-9]+ adapters'                  "$ADAPTERS" 'adapters'
check assets/architecture.svg '[0-9]+ global commands'           "$GLOBCMD"  'global commands'
check assets/architecture.svg '[0-9]+ role-based packs'          "$PACKS"    'role-based packs'
check assets/architecture.svg '[0-9]+ validators \+ sync scripts' "$TOOLING" 'validators + sync scripts'
# `check` keeps only the FIRST integer it finds, so in "N of the M pack commands" the M was
# compared to nothing. It was wrong the whole time: the SVG read "27 of the 133" while disk had
# 134 — and this gate printed "every derivable count matches disk" over it. Check both numbers.
check assets/command-map.svg  '[0-9]+ of the [0-9]+ pack commands' "$PLANCMD" 'pack commands advertising --plan'
got_t=$(grep -oE '[0-9]+ of the [0-9]+ pack commands' assets/command-map.svg 2>/dev/null | head -1 | grep -oE '[0-9]+' | sed -n '2p')
if [ -z "$got_t" ]; then
  printf '  FAIL assets/command-map.svg: the "N of the M pack commands" sentence is gone or reworded — the M can no longer be checked\n'; fail=$((fail+1))
elif [ "$got_t" != "$PACKCMD" ]; then
  printf '  FAIL assets/command-map.svg: "of the %s pack commands" — disk says %s\n' "$got_t" "$PACKCMD"; fail=$((fail+1))
else say "  ok   assets/command-map.svg: total in the --plan sentence = $got_t"; fi
# the "Another N commands ship inside the M packs" sentence carries two numbers
got_a=$(grep -oE 'Another [0-9]+ commands ship' assets/command-map.svg 2>/dev/null | head -1 | grep -oE '[0-9]+')
# Both arms used to be guarded on `-n "$got_a"`, so rewording the sentence away made the check
# vanish silently — unlike `check`, which FAILs when its pattern is missing. A figure that stops
# being checked because someone edited the prose around it is the drift this gate exists to catch.
if [ -z "$got_a" ]; then
  printf '  FAIL assets/command-map.svg: the "Another N commands ship" sentence is gone or reworded — nothing verifies that figure now\n'; fail=$((fail+1))
elif [ "$got_a" != "$PACKCMD" ]; then
  printf '  FAIL assets/command-map.svg: "Another %s commands ship" — disk says %s\n' "$got_a" "$PACKCMD"; fail=$((fail+1))
else say "  ok   assets/command-map.svg: pack commands = $got_a"; fi

say ""
if [ "$fail" -eq 0 ]; then say "  figure-stats: every derivable count matches disk"
else printf '  figure-stats: %d figure count(s) disagree with disk\n' "$fail"; fi
[ "$fail" -eq 0 ]
