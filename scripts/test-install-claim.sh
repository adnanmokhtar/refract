#!/usr/bin/env bash
# test-install-claim.sh — fixtures for scripts/install-claim.sh (PLAN.md §6 rule 2).
#
# Stages throwaway packs in a temp dir and asserts the four outcomes:
#   collision   two packs ship agents/x.md with different bytes in ONE run → exit 4, and NOTHING
#               of the second pack is copied (its non-colliding y.md is absent too: no partial copy)
#   identical   two packs ship identical bytes → exit 0, one file, no skip line
#   owner-file  the file was on disk before the run (not claimed in it) → exit 0, the owner's
#               bytes kept, a `-skip` line reported (an owner edit is not a collision)
#   new-run     --reset starts a new run: the earlier run's claim no longer counts → skip, not halt
# Exit: 0 all pass · 1 a case failed.
set -uo pipefail
export LC_ALL=C
# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd
IC="$SELF_DIR/install-claim.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/test-install-claim.XXXXXX")"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok() { if [ "$1" = "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL  $3 — want '$2', got '$1'"; fi; }

mk() { mkdir -p "$W/$1/agents"; printf -- '---\nname: %s\ndescription: %s\n---\n%s\n' "$2" "$3" "$4" > "$W/$1/agents/$2.md"; }
mk packA x "x from A" "body A"
mk packB x "x from B" "body B"
mk packB y "y from B" "body y"
mk packC x "x from A" "body A"                     # byte-identical to packA's x

# collision
P="$W/proj1"; mkdir -p "$P"
bash "$IC" "$P" --reset
rc=0; bash "$IC" "$P" agents packA "$W/packA/agents" >/dev/null 2>&1 || rc=$?
ok "$rc" 0 "first pack copies"
rc=0; err="$(bash "$IC" "$P" agents packB "$W/packB/agents" 2>&1 >/dev/null)" || rc=$?
ok "$rc" 4 "different-content same-name agent halts with exit 4"
ok "$(printf '%s' "$err" | grep -c "COLLISION agent 'x': packA and packB")" 1 "collision names both sources"
ok "$(cat "$P/.claude/agents/x.md" | grep -c 'body A')" 1 "the first claim is untouched"
ok "$([ -e "$P/.claude/agents/y.md" ] && echo present || echo absent)" absent "no partial copy of the colliding pack"

# identical
rc=0; out="$(bash "$IC" "$P" agents packC "$W/packC/agents" 2>&1)" || rc=$?
ok "$rc" 0 "identical bytes are a no-op"
ok "$(printf '%s' "$out" | grep -c skip)" 0 "identical bytes report no skip"

# owner-file (on disk before the run, not claimed in it)
P2="$W/proj2"; mkdir -p "$P2/.claude/agents"; printf 'owner edit\n' > "$P2/.claude/agents/x.md"
bash "$IC" "$P2" --reset
rc=0; out="$(bash "$IC" "$P2" agents packB "$W/packB/agents" 2>&1)" || rc=$?
ok "$rc" 0 "an owner's file is not a collision"
ok "$(cat "$P2/.claude/agents/x.md")" "owner edit" "the owner's bytes are kept"
ok "$(printf '%s' "$out" | grep -c "agent-skip: 'x'")" 1 "the skip is reported"
ok "$([ -e "$P2/.claude/agents/y.md" ] && echo present || echo absent)" present "the rest of the pack installs"

# new-run: an earlier run's claim does not make a later run collide
bash "$IC" "$P" --reset
rc=0; bash "$IC" "$P" agents packB "$W/packB/agents" >/dev/null 2>&1 || rc=$?
ok "$rc" 0 "after --reset the earlier run's file is the project's (skip, not halt)"

# lenses are a kind too
mkdir -p "$W/packD/lenses"; printf 'lens\n' > "$W/packD/lenses/l.md"
rc=0; bash "$IC" "$P" lenses packD "$W/packD/lenses" >/dev/null 2>&1 || rc=$?
ok "$rc/$([ -f "$P/.claude/lenses/l.md" ] && echo y)" "0/y" "lenses install to .claude/lenses"

# commands are refused (the variant rule owns them)
rc=0; bash "$IC" "$P" commands packD "$W/packD" >/dev/null 2>&1 || rc=$?
ok "$rc" 2 "commands are not handled here"

# Staged install with the real templates (PLAN.md §4 link 4): the code-quality pack's agents, then the
# payment domain's lenses → .claude/lenses/payment-review.md exists, and the installed code-reviewer's
# generated Lenses block names it.
RT="$(cd "$SELF_DIR/.." && pwd)/templates"
if [ -d "$RT/domains/payment/lenses" ]; then
  P3="$W/proj3"; mkdir -p "$P3"; bash "$IC" "$P3" --reset
  bash "$IC" "$P3" agents code-quality "$RT/packs/code-quality/agents" >/dev/null 2>&1
  rc=0; bash "$IC" "$P3" lenses domain:payment "$RT/domains/payment/lenses" >/dev/null 2>&1 || rc=$?
  ok "$rc/$([ -f "$P3/.claude/lenses/payment-review.md" ] && echo y)" "0/y" "--include=payment installs .claude/lenses/payment-review.md"
  ok "$(grep -c '`.claude/lenses/payment-review.md`' "$P3/.claude/agents/code-reviewer.md")" 1 "the installed code-reviewer's Lenses block names the payment lens"
fi

echo "install-claim fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
