#!/usr/bin/env bash
# lint-self-review.sh — a missing reviewer must never turn into the builder reviewing itself.
#
# WHY. Thirteen pack commands said the same thing when a dispatched reviewer was not installed:
# "perform that review inline against the corresponding pack/domain checklist". Read literally,
# the agent that wrote the change then graded it, labelled the axis `inline:<agent>` or
# `graded inline (<pack> absent)`, and the run could still close COMPLETE. A reviewer exists to be
# someone other than the builder; a builder re-reading a checklist over its own diff is the
# failure it was added to prevent, and the label made it look like coverage. On a backend-only
# install that was five of /analyze-module's six axes.
#
# The contract that replaced it: the axis is reported `UNREVIEWED(<axis>)` and the run ends
# INCOMPLETE, naming the pack that closes it. This gate keeps the old fallback from coming back —
# in a new command, a re-cut `_examples/` fallback, or a paste from an older file.
#
# Phase 2 added four phrases. The first sweep matched only "perform that review inline"; the same
# fallback survived in other words — "dispatch security-auditor, or inline against the checklist",
# "the inline checklist if not installed", "run its checklist inline", "apply the corresponding
# checklist inline" — in fourteen lines across backend, frontend, mobile, ai-engineering, security and
# migration. Same defect, different spelling; all fourteen now report UNREVIEWED.
#
# Scans templates/ and commands/ (*.md). CHANGELOG.md files are exempt: they record that the
# fallback existed, which is history, not an instruction. Deliberately NOT matched: "graded inline"
# on its own — the frontend INP budget is graded by the builder against a pattern, not dispatched
# to a reviewer — and `inline:<skill-name>` in /pre-commit, a mechanical check the skill would
# also run. Both are named here so a reader knows they were considered, not missed.
#
# Usage:   lint-self-review.sh [--repo-root=<dir>] [--quiet]
# Exit:    1 on any occurrence; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 2

# One phrase per line; matched case-insensitively as fixed strings.
PHRASES='perform that review inline
perform that axis inline
performed inline against
is performed inline
inline-review fallback
graded inline (<pack> absent)
inline:<agent-name>
inline:<reviewer-name>
inline against the checklist
inline checklist if not installed
checklist inline
checklist inlined'

dirs=""
for d in templates commands; do [ -d "$d" ] && dirs="$dirs $d"; done
if [ -z "$dirs" ]; then
  echo "FAIL  neither templates/ nor commands/ exists under $REPO_ROOT — nothing was scanned, which is not a pass." >&2
  exit 1
fi

# shellcheck disable=SC2086
hits=$(printf '%s\n' "$PHRASES" | grep -rniF -f - $dirs --include='*.md' 2>/dev/null | grep -v '/CHANGELOG\.md:' || true)
# shellcheck disable=SC2086
scanned=$(find $dirs -name '*.md' ! -name CHANGELOG.md | wc -l | tr -d ' ')

if [ -n "$hits" ]; then
  n=$(printf '%s\n' "$hits" | grep -c .)
  echo "FAIL  $n self-review fallback(s) — a missing reviewer is UNREVIEWED(<axis>) and the run INCOMPLETE, never the builder grading itself:"
  printf '%s\n' "$hits" | cut -c1-220 | sed 's/^/  /'
  echo "Replace each with the contract: report \`UNREVIEWED(<axis>) — <agent> not installed (<pack> pack)\`, end INCOMPLETE, name \`/setup-project --include=<pack>\`."
  exit 1
fi
[ "$QUIET" -eq 1 ] || echo "reach: $scanned markdown file(s) under$dirs (CHANGELOG.md exempt)"
echo "PASS  no self-review fallback — a missing reviewer is reported UNREVIEWED, not graded by the builder."
exit 0
