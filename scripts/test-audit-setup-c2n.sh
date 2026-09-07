#!/usr/bin/env bash
# test-audit-setup-c2n.sh — pin WHICH files C2n is allowed to charge for a rewritten line.
#
# THE BUG THIS EXISTS FOR. C2f fails the six derived `ai/` files for being STALE and orders
# them regenerated. C2n then diffed the regenerated file against the pre-refresh backup and
# reported every replaced line as KNOWLEDGE_LOSS — so obeying C2f guaranteed failing C2n, and
# a correct run could not lower its own fail count.
#
# 📏 Measured on hisn, 2026-09-06: Phase 4.7 cleared 10 rows, C2n opened exactly 10, total
# stayed at 33. Every row read `0 project token(s), 0 project-specific region(s)` — nothing was
# dropped; the "lost" lines were the corrections that had been asked for ("NestJS 10 +
# MikroORM/MySQL" → the true "NestJS 11 + Postgres 16") and, in one case, `Last updated:
# 2026-06-21`. Reproduced identically on capsolah-api and sahlcart-website.
#
# THE FIX, AND ITS LIMIT. Only the three COMPACT PROJECTIONS are exempt —
# commands/setup-project.md § "Token efficiency" declares them "REGENERATED, not hand-edited.
# Source of truth is the full files". The full sources they derive FROM stay protected, and that
# asymmetry is the whole point: a fact dropped from `conventions.md` is gone, a fact dropped
# from `_convention-cheatsheet.md` still lives upstream and returns on the next regeneration.
#
# So this suite asserts BOTH directions. An exemption that quietly widened to the full sources
# would pass a one-sided test and lose real knowledge, which is exactly the failure the
# exemption is meant to avoid causing.
#
# Method: lift the `case "$rel" in … esac` selector straight out of audit-setup.sh and run it.
# Copying the arms into the test would let the two drift apart — the test would keep passing
# while the shipped selector changed underneath it.
#
# Usage: test-audit-setup-c2n.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
AUDIT="$REPO_ROOT/scripts/audit-setup.sh"

QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
pass=0; fail=0
say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
ok()   { pass=$((pass + 1)); say "  ok   $1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

[ -f "$AUDIT" ] || { echo "ERR: $AUDIT not found" >&2; exit 1; }

# Lift the selector. It sits inside C2n's backup-walk loop, between the comment that names the
# adapter projections and the `esac`. Anchor on the first arm, which is stable.
SELECTOR="$(awk '
  /^      case "\$rel" in$/ { f=1 }
  f { print }
  f && /^      esac$/ { exit }
' "$AUDIT")"
[ -n "$SELECTOR" ] || { echo "ERR: C2n file selector not found in $AUDIT — did the loop get reshaped?" >&2; exit 1; }

# `continue` and `;;` only mean something inside a loop, so run the arms inside one and report
# which branch a path took. CHECKED = C2n compares it; SKIPPED = C2n never looks at it.
classify() {
  rel="$1"
  # shellcheck disable=SC2034
  for _once in 1; do
    eval "$SELECTOR"
    printf 'CHECKED\n'; return 0
  done
  printf 'SKIPPED\n'
}

expect() {
  local rel="$1" want="$2" got
  got="$(classify "$rel")"
  [ "$got" = "$want" ] && ok "$rel → $want" || bad "$rel → $want" "got $got"
}

say "=== test-audit-setup-c2n ==="
say ""
say "fixture: the three compact projections are exempt — regenerating one is not a loss"
expect "ai/_session-digest.md"        SKIPPED
expect "ai/_convention-cheatsheet.md" SKIPPED
expect "ai/_decision-index.md"        SKIPPED

say ""
say "fixture: the FULL sources they derive from stay protected — the asymmetry is the point"
expect "ai/conventions.md"     CHECKED
expect "ai/architecture.md"    CHECKED
expect "ai/business-domain.md" CHECKED

say ""
say "fixture: the exemption did not widen to the rest of the knowledge layer"
expect "ai/business-flows.md"          CHECKED
expect "ai/core/invariants.md"         CHECKED
expect "ai/decisions/0001-example.md"  CHECKED
expect "ai/dynamic/vocabulary.md"      CHECKED
# A near-miss name must NOT inherit the exemption — the arms are exact paths, not globs.
expect "ai/_session-digest.backup.md"  CHECKED
expect "ai/nested/_decision-index.md"  CHECKED

say ""
say "fixture: the surfaces C2n has always covered still route as before"
expect ".claude/rules/security-principles.md" CHECKED
expect ".claude/commands/add-feature.md"      CHECKED
expect ".claude/codebase-profile.md"          CHECKED
expect "CLAUDE.md"                            CHECKED
expect "AGENTS.md"                            CHECKED

say ""
say "fixture: derived adapter sinks stay out — regenerating a projection is not a loss"
expect ".opencode/commands/add-feature.md" SKIPPED
expect ".cursor/rules/00-project.mdc"      SKIPPED
expect "package.json"                      SKIPPED

say ""
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
