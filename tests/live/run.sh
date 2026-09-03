#!/usr/bin/env bash
# tests/live/run.sh — the half of /setup-project no other test touches: the decisions a MODEL makes.
#
# WHY. tests/setup-project/run.sh states its own limit in its header — Phase 1 mode detection,
# Phase 2 extraction and Phase 4.6 anchoring "need a real CLI invocation strategy. M6+ candidate."
# Everything deterministic is covered; the part that reads a codebase and decides what it is has
# never been executed by a test. That is the part the whole tool exists for.
#
# WHAT MADE THIS BUILDABLE, measured rather than assumed. Three runs of the same classification
# question against the same fixture returned the same word three times. Three runs of an OPEN
# question returned three different sentences with the same meaning. So:
#
#     a CLASSIFICATION is stable        → assert the answer
#     PROSE is not                      → assert the FACTS in it, never the wording
#
# Every assertion here is of the first kind. An assertion on phrasing would fail on a rewrite that
# is equally correct, and a test that fails on correct work gets deleted within a month.
#
# WHY IT IS NOT IN THE BLOCKING SUITE. It costs money and wall-clock (~7s per call, plus model
# time), needs credentials, and depends on a service being up — a CI gate with those properties
# goes red for reasons that are not defects, and a gate that cries wolf is removed. Run it
# deliberately: before a release, or after touching phase-1/phase-2 prompts.
#
# Usage:  tests/live/run.sh [--quiet]
# Exit:   1 on any failed assertion; 2 when no CLI is available (never a silent pass).

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
HERE="$(cd -P "$(dirname "$_ss")" && pwd)"; REPO_ROOT="$(cd -P "$HERE/../.." && pwd)"; unset _ss _sd
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

pass=0; fail=0
say() { [ $QUIET -eq 0 ] && echo "$@"; return 0; }
ok()  { say "  ok    $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1"; [ -n "${2:-}" ] && echo "        $2"; fail=$((fail+1)); }

if ! command -v claude >/dev/null 2>&1; then
  echo "ERR: no `claude` CLI on PATH — the model-driven half cannot be exercised." >&2
  echo "     This exits 2 rather than passing: a suite that reports success without running" >&2
  echo "     anything is the always-pass bug this repo keeps closing." >&2
  exit 2
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/live.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT

# ask <dir> <prompt> — one word back, lowercased, punctuation stripped.
ask() {
  ( cd "$1" && claude -p "$2" 2>/dev/null ) | tr -d '\n' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z-'
}

say "=== live: the decisions a model makes ==="
say "Repo: $REPO_ROOT"
say ""

# ---- Phase 1: the mode table is deterministic prose; the MODEL still has to apply it ----
say "§1  Phase 1 — mode detection (the table in templates/phases/phase-1-detect-mode.md)"

MODE_Q='Read the repository in the current directory. Using ONLY these rules — no source and no .claude/ and no CLAUDE.md and no ai/ means CREATE; source exists but .claude/ or ai/ is missing means ENHANCE — answer with ONE word, either CREATE or ENHANCE. No punctuation, no explanation.'

mkdir -p "$WORK/empty"
a=$(ask "$WORK/empty" "$MODE_Q")
[ "$a" = "create" ] && ok "empty repo → CREATE" || bad "empty repo → CREATE" "got '$a'"

mkdir -p "$WORK/src-only/src"
echo '{"dependencies":{"express":"4"}}' > "$WORK/src-only/package.json"
echo 'module.exports = {}' > "$WORK/src-only/src/index.js"
a=$(ask "$WORK/src-only" "$MODE_Q")
[ "$a" = "enhance" ] && ok "source but no .claude/ → ENHANCE" || bad "source but no .claude/ → ENHANCE" "got '$a'"

# ---- Phase 2: stack detection is the single fact every later phase is keyed on ----
say ""
say "§2  Phase 2 — stack detection (what every later phase keys on)"

STACK_Q='Look at the project in the current directory and answer with ONE word from this list only: nextjs, django, express, unknown. No punctuation, no explanation.'

mkdir -p "$WORK/next/app"
echo '{"dependencies":{"next":"14","react":"18"}}' > "$WORK/next/package.json"
echo 'export default function Page(){return null}' > "$WORK/next/app/page.tsx"
a=$(ask "$WORK/next" "$STACK_Q")
[ "$a" = "nextjs" ] && ok "next.js project → nextjs" || bad "next.js project → nextjs" "got '$a'"

mkdir -p "$WORK/dj/app"
printf 'Django==5.0\n' > "$WORK/dj/requirements.txt"
printf 'from django.db import models\n' > "$WORK/dj/app/models.py"
printf 'import os\n' > "$WORK/dj/manage.py"
a=$(ask "$WORK/dj" "$STACK_Q")
[ "$a" = "django" ] && ok "django project → django" || bad "django project → django" "got '$a'"

# The honest negative: a directory with nothing to go on must NOT produce a confident guess.
mkdir -p "$WORK/bare"
printf '# notes\n' > "$WORK/bare/README.md"
a=$(ask "$WORK/bare" "$STACK_Q")
[ "$a" = "unknown" ] && ok "no stack signals → unknown (does not guess)" \
  || bad "no stack signals → unknown" "got '$a' — inventing a stack from nothing is the failure this asserts against"

# ---- provenance: the rule the business files depend on ----
say ""
say "§3  Provenance — a claim with no source must be marked, not asserted"

PROV_Q='A file states: "Our main competitor is Shopify." Nothing in this repository mentions Shopify. Per the provenance contract — [found: source] for something read from a real named source, [inferred: basis] for something derived from this repo, [unconfirmed] when nobody here knows — answer with ONE marker only: found, inferred, or unconfirmed. No punctuation.'
a=$(ask "$WORK/bare" "$PROV_Q")
[ "$a" = "unconfirmed" ] && ok "unsourced competitor claim → unconfirmed" \
  || bad "unsourced competitor claim → unconfirmed" "got '$a' — this is the fabrication the contract exists to stop"

echo ""
echo "live: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
