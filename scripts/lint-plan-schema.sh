#!/usr/bin/env bash
# lint-plan-schema.sh — every file that states the plan contract must state the SAME contract.
#
# WHY. The plan file is the seam between an Opus planning pass and a Sonnet executor, and eight
# separate files tell a generator what shape to emit: five global commands (`<cmd> --plan`),
# `execute-plan.md`, `verify-plan.md`, and the canonical table in `plans/README.md`. Nothing joined
# them. One fact, eight places — the shape this repo pays for most often, and the reason a script
# count went red on CI twice in a day.
#
# It was already drifting in a quieter way: `plans/README.md` positioned the two OPTIONAL sections
# (`## Approach` after Context, `## Known unknowns` before Verification) while every other file
# listed the mandatory eight as a flat set and said nothing about where the optional ones go. Two
# valid plans could therefore differ in shape and both pass, which defeats the point of a contract
# whose whole job is that an executor knows what it is reading.
#
# WHAT CHANGED, and why it is not cosmetic. `## Constraints` now precedes `## Steps`. The executor
# reads top-down: `/execute-plan` calls Constraints "hard", halts when a Step as written would
# breach one, and hands the FULL list to every parallel sub-agent alongside only that agent's slice
# of the Steps. Prohibitions after the recipe means the recipe is read twice — once to learn it,
# once to re-read it through rules that arrived late.
#
# WRITERS ARE ORDERED, READERS ARE TOLERANT. This gate polices the generators. `/execute-plan` and
# `/verify-plan` still validate PRESENCE only, so a plan saved before this ordering, or written by
# hand in another sequence, still runs. Enforcing order on the reader would reject semantically
# fine plans already sitting in consuming repos to buy nothing.
#
#   [1] check_same_order   (FAIL) — every file stating the mandatory eight states them in the
#                                   canonical order.
#   [2] check_optionals    (FAIL) — the canonical table positions `## Approach` and
#                                   `## Known unknowns`. A contract that leaves an optional section
#                                   floating is a contract with two legal shapes.
#   [3] check_reader_open  (FAIL) — execute-plan.md must NOT claim to require an order. The
#                                   tolerance is deliberate and easy to "tidy away" later; this
#                                   pins it so a future edit cannot quietly break every saved plan.
#
# Usage:  lint-plan-schema.sh [--repo-root=<dir>]
# Exit:   1 on any FAIL.

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
REPO_ROOT="$(cd -P "$REPO_ROOT" && pwd)" || exit 1
cd "$REPO_ROOT" || exit 1

README="templates/repo-baseline/.claude/plans/README.md"
EXEC="templates/repo-baseline/.claude/commands/execute-plan.md"
CANON="Goal Context Inputs Outputs Constraints Steps Verification Status"

fails=0
echo "=== lint-plan-schema ==="
echo "Repo: $REPO_ROOT"
echo ""

echo "[1] every file states the mandatory eight in the canonical order"
# grep, not `git grep`: a validator that needs a git index cannot run against a fixture tree,
# and every other gate here is pinned by exactly such a tree.
files=$(grep -rl -- '`## Goal`' commands templates 2>/dev/null)
[ -n "$files" ] || { echo "  FAIL  no file states the plan schema at all"; exit 1; }
checked=0; ok1=1
while IFS= read -r f; do
  [ -n "$f" ] || continue
  # Read the LINE that enumerates the schema, never the whole file. execute-plan.md names
  # individual sections in prose all through its phases, so first-mention order across a document
  # is the order the author happened to explain things in — not the contract it states. The first
  # draft of this check did exactly that and reported execute-plan.md as drifted when it was not.
  # A line carrying eight or more of the tokens IS the enumeration; anything less is prose.
  file_ok=1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    seen=$(printf '%s\n' "$line" | grep -oE '`## (Goal|Context|Inputs|Outputs|Constraints|Steps|Verification|Status)`' \
           | sed 's/`## //; s/`//' | awk '!a[$0]++' | tr '\n' ' ' | sed 's/ *$//')
    n=$(echo "$seen" | wc -w | tr -d ' ')
    [ "$n" -ge 8 ] || continue
    checked=$((checked + 1))
    if [ "$seen" != "$CANON" ]; then
      echo "  FAIL  $f"
      echo "        states: $seen"
      echo "        canon:  $CANON"
      fails=$((fails + 1)); ok1=0; file_ok=0
    fi
  done < "$f"
done <<EOF
$files
EOF
[ "$ok1" -eq 1 ] && echo "  ok — $checked files, one order"

echo "[2] the canonical table positions both optional sections"
ok2=1
if [ ! -f "$README" ]; then
  echo "  FAIL  missing: $README"; fails=$((fails + 1)); ok2=0
else
  for s in "Approach" "Known unknowns"; do
    grep -qE "^\| \`## $s\` \*\*\(optional\)\*\*" "$README" \
      || { echo "  FAIL  $README — \`## $s\` has no positioned row in the contract table"; fails=$((fails + 1)); ok2=0; }
  done
  # and they must sit where the contract says: Approach after Context, Known unknowns before Verification
  ln_ctx=$(grep -n '^| `## Context`'        "$README" | head -1 | cut -d: -f1)
  ln_app=$(grep -n '^| `## Approach`'       "$README" | head -1 | cut -d: -f1)
  ln_ku=$(grep -n  '^| `## Known unknowns`' "$README" | head -1 | cut -d: -f1)
  ln_ver=$(grep -n '^| `## Verification`'   "$README" | head -1 | cut -d: -f1)
  if [ -n "$ln_ctx" ] && [ -n "$ln_app" ] && [ "$ln_app" -lt "$ln_ctx" ]; then
    echo "  FAIL  $README — \`## Approach\` precedes \`## Context\`; the design choice belongs after the background it rests on"
    fails=$((fails + 1)); ok2=0
  fi
  if [ -n "$ln_ku" ] && [ -n "$ln_ver" ] && [ "$ln_ku" -gt "$ln_ver" ]; then
    echo "  FAIL  $README — \`## Known unknowns\` follows \`## Verification\`; an unresolved one can stop the run, so it is read before anyone checks the work"
    fails=$((fails + 1)); ok2=0
  fi
fi
[ "$ok2" -eq 1 ] && echo "  ok — both optional sections have a fixed, justified position"

echo "[3] the executor still accepts any order"
ok3=1
if [ ! -f "$EXEC" ]; then
  echo "  FAIL  missing: $EXEC"; fails=$((fails + 1)); ok3=0
elif grep -qiE 'MUST contain.*in (this|that) order|headers?.*in order|order is (required|mandatory)' "$EXEC"; then
  echo "  FAIL  $EXEC now requires an order — that rejects every plan saved before this ordering and buys nothing"
  fails=$((fails + 1)); ok3=0
fi
[ "$ok3" -eq 1 ] && echo "  ok — presence is validated, order is not"

echo ""
echo "reach: $checked schema-stating files · 8 mandatory sections · 2 optional positions · 1 reader-tolerance pin"
echo "       not checked: plan files inside consuming repos — they are written there, and the reader accepts any order by design"
if [ "$fails" -gt 0 ]; then
  echo "FAIL  $fails plan-schema disagreement(s)."
  exit 1
fi
echo "PASS"
