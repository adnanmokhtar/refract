#!/usr/bin/env bash
# lint-skill-budget.sh — a SKILL.md stays within the load budget, and its sidecars are real.
#
# WHY. A skill's `description` is paid every session (it is what routing reads); the BODY is
# paid only when the skill fires. So the budget here is not a session tax — it is the point at
# which one file stops being a procedure and starts being a manual, and the detail that is
# needed only sometimes should move to `references/` and be read on demand. Agent Skills
# guidance puts that line at ~500 lines. One skill crossed it (apply-pack-adaptation, 563)
# carrying two long anchor-block templates consulted on three of its decision rows.
#
# Three rules:
#   1. BUDGET    — SKILL.md ≤ MAX_LINES (override: SKILL_MAX_LINES=<n>).
#   2. RESOLVES  — a `references/<file>` named in SKILL.md must exist in that skill folder. A
#                  dangling pointer is worse than the inline text it replaced: the reader is
#                  told the detail exists and cannot find it.
#   3. NO ORPHAN — a file under references/ / scripts/ / assets/ must be cited by its SKILL.md,
#                  or nothing will ever read it. This is also the gate that keeps a sidecar from
#                  drifting out of the install path: apply-study-decisions.sh's
#                  sync_skill_sidecars only carries dirs that exist, and phase-4.2-apply.md's
#                  `cp -R` only carries what the pack ships.
#
# Usage:   lint-skill-budget.sh [--repo-root=<dir>] [--quiet]
# Exit:    1 on any violation; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
QUIET=0
MAX_LINES="${SKILL_MAX_LINES:-500}"
SIDECARS='references scripts assets'
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" 2>/dev/null || { echo "no such repo root: $REPO_ROOT" >&2; exit 2; }

red()   { [ "$QUIET" = 1 ] || printf '\033[31m%s\033[0m\n' "$*"; }
green() { [ "$QUIET" = 1 ] || printf '\033[32m%s\033[0m\n' "$*"; }
ERRORS=0
fail() { red "✗ $*"; ERRORS=$((ERRORS+1)); }

N=0; BIGGEST=0; BIGGEST_NAME=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  N=$((N+1))
  dir="$(dirname "$f")"; name="$(basename "$dir")"
  lines=$(wc -l < "$f" | tr -d ' ')
  [ "$lines" -gt "$BIGGEST" ] && { BIGGEST="$lines"; BIGGEST_NAME="$name"; }

  # 1. BUDGET
  if [ "$lines" -gt "$MAX_LINES" ]; then
    fail "$f: $lines lines exceeds the $MAX_LINES-line budget — move the sometimes-needed detail to references/"
  fi

  # 2. RESOLVES — but ONLY for a sidecar dir this skill actually ships. `scripts/apply-anchors.sh`
  # and `references/<framework>.md` in a SKILL.md normally mean the REPO's scripts/ and the PACK's
  # references/ — same spelling, different tree. The citation is skill-relative exactly when the
  # skill has that directory, so that is the condition the check runs under.
  for d in $SIDECARS; do
    [ -d "$dir/$d" ] || continue
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      [ -f "$dir/$ref" ] || fail "$f: names \`$ref\` but $dir/$ref does not exist"
    done <<< "$(grep -oE "$d/[A-Za-z0-9._-]*[A-Za-z0-9]" "$f" | sort -u)"
  done

  # 3. NO ORPHAN — every sidecar file must be named by the SKILL.md.
  for d in $SIDECARS; do
    [ -d "$dir/$d" ] || continue
    while IFS= read -r side; do
      [ -n "$side" ] || continue
      rel="${side#$dir/}"
      grep -qF "$rel" "$f" || fail "$f: ships $rel but never names it — nothing will read it"
    done <<< "$(find "$dir/$d" -type f 2>/dev/null)"
  done
done <<< "$(find . -path ./.git -prune -o -name SKILL.md -type f -print 2>/dev/null | grep -v '/tests/')"

if [ "$ERRORS" -eq 0 ]; then
  green "✓ skill budget: $N skills, largest is $BIGGEST_NAME at $BIGGEST/$MAX_LINES lines; every sidecar resolves and is cited"
  exit 0
fi
red "skill-budget: $ERRORS violation(s)"
exit 1
