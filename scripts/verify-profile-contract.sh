#!/usr/bin/env bash
# verify-profile-contract.sh — the fields three later phases READ must actually be in the profile.
#
# WHY. `templates/phases/phase-2-profile.md` § 17 calls these "the contract three later phases
# read": Phase 3 prints `repo_shape` as SHAPE:, Phase 4.0 gates sub-project recursion on it, and
# Phase 4.2 reads `is_multi_track` + `track_roots` to path-scope each track's rules.
#
# Phase 2 is LLM-executed. Phase 4.2's response to a missing field is an instruction — "do NOT
# default to false … Halt and complete the repo-shape block" — addressed to an agent. An
# instruction is not a check, and this one was not followed.
#
# 📏 MEASURED on the reference monorepo: the profile contains NONE of `repo_shape`, `is_multi_track` or
# `track_roots` — zero occurrences of all three. So Phase 4.2's condition was never true, the
# halt never fired, the scoping step was skipped in silence, and 14 of 36 installed rules ended
# up delivered on no turn. The phase file had predicted that exact outcome, in writing, one line
# above the branch that failed to prevent it.
#
# A CHECK, NOT A PROMISE. This exits non-zero and names what is missing. Run it before anything
# that reads the contract, and the failure arrives where it can still be fixed rather than three
# phases later as an absence nobody attributes to Phase 2.
#
# Usage: verify-profile-contract.sh <target-repo> [--quiet] [--warn-only]
# Exit:  0 contract complete / 1 a required field is missing / 2 no profile at all
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
unset _ss _sd

TARGET=""; QUIET=0; WARN_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet)     QUIET=1; shift ;;
    --warn-only) WARN_ONLY=1; shift ;;
    -h|--help)   sed -n '2,26p' "$0"; exit 0 ;;
    *)           TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] && [ -d "$TARGET" ] || { echo "usage: $0 <target-repo> [--quiet] [--warn-only]" >&2; exit 1; }

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

PROFILE="$TARGET/.claude/codebase-profile.md"
if [ ! -f "$PROFILE" ]; then
  echo "ERR  no .claude/codebase-profile.md in $TARGET — Phase 2 has not run." >&2
  exit 2
fi

# Each field, and the phase that breaks without it. Naming the consumer is the point: a missing
# key is abstract, "Phase 4.2 cannot scope your rules" is not.
missing=""
check() {
  local key="$1" consumer="$2"
  if grep -qE "^[[:space:]]*${key}:" "$PROFILE" 2>/dev/null; then
    say "  ok   ${key} present"
  else
    missing="$missing $key"
    printf '  MISSING  %-16s → %s\n' "$key" "$consumer"
  fi
}

say "profile contract — ${PROFILE#$TARGET/}"
check repo_shape     "Phase 3 prints it as SHAPE:; Phase 4.0 gates sub-project recursion on it"
check members        "every member absent from this list gets no rules, no adapters, no conventions row"
check is_multi_track "Phase 4.2 path-scopes each track's rules on it — absent, nothing is scoped"
check track_roots    "Phase 4.2 scopes TO these globs — absent, a scoped rule has nowhere to match"

# `is_multi_track: true` with no track_roots is worse than either alone: the true branch runs and
# scopes every rule to nothing, which reads as "scoped" everywhere and matches nowhere.
if grep -qE '^[[:space:]]*is_multi_track:[[:space:]]*true' "$PROFILE" 2>/dev/null \
   && ! grep -qE '^[[:space:]]*track_roots:' "$PROFILE" 2>/dev/null; then
  printf '  INCONSISTENT  is_multi_track: true with no track_roots — the scoping branch would scope every rule to nothing\n'
  missing="$missing track_roots(consistency)"
fi

say ""
if [ -z "$missing" ]; then
  say "  contract complete — Phase 3, 4.0 and 4.2 can all read what they need"
  exit 0
fi

n=$(printf '%s' "$missing" | wc -w | tr -d ' ')
echo "" >&2
echo "  $n contract field(s) missing from ${PROFILE#$TARGET/}:$missing" >&2
echo "" >&2
echo "  This is not cosmetic. Phase 4.2 reads is_multi_track to decide whether to path-scope" >&2
echo "  rules; absent, the branch never runs, nothing is scoped, and every rule over the" >&2
echo "  always-loaded budget is delivered on NO turn. Measured on a live repo: 14 of 36." >&2
echo "" >&2
echo "  Fix: complete § 17 of phase-2-profile.md in that file — repo_shape, members," >&2
echo "  is_multi_track and track_roots — then re-run the phase that needs them." >&2

[ "$WARN_ONLY" -eq 1 ] && exit 0
exit 1
