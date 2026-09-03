#!/usr/bin/env bash
# lint-context-provenance.sh — a shipped file that claims things about the WORLD must say where
# each claim came from.
#
# WHY. Seven baseline files under templates/repo-baseline/ai/ carry claims that cannot be read off
# a codebase: what a persona wants, what a competitor is good at, what a customer will pay for.
# CLAUDE.md loads them as *product context*, so every "should we build X" decision inherits them,
# and no gate downstream ever re-checks them.
#
# Phase 2 already runs a provenance contract — `[found: <source>]` / `[inferred: <basis>]` /
# `[unconfirmed]`, where an unmarked factual claim is invalid. It applies to `.claude/_extracted-*`
# only. Measured on a live consuming repo: six of these files, 1,063 lines, **zero** markers —
# including a named competitor with attributed strengths and weaknesses, written by a model, with
# nothing recording whether it came from that repo's own docs or from training-data memory.
#
# `extract-business-context` names that exact failure — "a competitor from training-data memory …
# is the failure mode downstream files inherit forever" — so the rule already existed. The files
# that need it most were simply outside it.
#
# WHAT THIS GATE CAN AND CANNOT SEE. It runs in THIS repo, where these files are blank templates;
# it cannot inspect a consuming project's filled-in copies. So it checks the one thing decidable
# here: that every template TELLS its generator the contract. The filled files are graded in the
# target by `/setup-project-health` check 11, which counts markers and lists every `[unconfirmed]`
# as a question for a human. Two halves of one contract — this half makes the instruction impossible
# to omit, that half makes the omission visible where the claims actually get written.
#
#   [1] check_contract_present   (FAIL) — each product-context template carries the provenance block.
#   [2] check_all_three_markers  (FAIL) — the block names all three markers. A block offering only
#                                          `[found:]` and `[inferred:]` quietly removes the honest
#                                          default, and "I don't know" is the answer these files
#                                          need most.
#   [3] check_health_covers_them (FAIL) — /setup-project-health names each file in check 11. A
#                                          template that instructs and a health check that never
#                                          looks is an instruction nobody is held to.
#
# Usage:  lint-context-provenance.sh [--repo-root=<dir>]
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

DIR="templates/repo-baseline/ai"
HEALTH="commands/setup-project-health.md"
MARK="Provenance is mandatory in this file"
FILES="project-goals users-and-personas business-model competitive-context business-domain business-flows roadmap"

fails=0
echo "=== lint-context-provenance ==="
echo "Repo: $REPO_ROOT"
echo ""

[ -d "$DIR" ] || { echo "FAIL  missing: $DIR"; exit 1; }

echo "[1] every product-context template states the provenance contract"
ok1=1
for f in $FILES; do
  p="$DIR/$f.md"
  if [ ! -f "$p" ]; then
    echo "  FAIL  $p — listed as product context but absent"; fails=$((fails+1)); ok1=0; continue
  fi
  grep -qF "$MARK" "$p" || { echo "  FAIL  $p — carries no provenance block"; fails=$((fails+1)); ok1=0; }
done
[ $ok1 -eq 1 ] && echo "  ok — all $(echo $FILES | wc -w | tr -d ' ') templates carry it"

echo "[2] each block offers all three markers, the honest default included"
ok2=1
for f in $FILES; do
  p="$DIR/$f.md"; [ -f "$p" ] || continue
  grep -qF "$MARK" "$p" || continue
  for m in '[found:' '[inferred:' '[unconfirmed]'; do
    grep -qF -- "$m" "$p" || { echo "  FAIL  $p — block omits \`$m\`"; fails=$((fails+1)); ok2=0; }
  done
done
[ $ok2 -eq 1 ] && echo "  ok — none of them drops \`[unconfirmed]\`"

echo "[3] /setup-project-health grades these same files"
ok3=1
if [ ! -f "$HEALTH" ]; then
  echo "  FAIL  missing: $HEALTH"; fails=$((fails+1)); ok3=0
else
  for f in $FILES; do
    grep -qF "ai/$f.md" "$HEALTH" || { echo "  FAIL  $HEALTH never names ai/$f.md — the template instructs, nothing checks"; fails=$((fails+1)); ok3=0; }
  done
fi
[ $ok3 -eq 1 ] && echo "  ok — every template has a matching check in the target"

echo ""
echo "reach: $(echo $FILES | wc -w | tr -d ' ') product-context templates · 3 markers each · graded in-target by health check 11"
echo "       not checked: filled files in consuming repos — this gate cannot see them; check 11 is that half"
if [ $fails -gt 0 ]; then
  echo "FAIL  $fails provenance-contract gap(s)."
  exit 1
fi
echo "PASS"
