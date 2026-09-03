#!/usr/bin/env bash
# lint-shell-callables.sh — a reporter call must name a function that EXISTS.
#
# WHY. audit-setup.sh line 1866 read
#
#     warn "C2e: audit-adapter-coverage.sh exited non-zero — coverage numbers below are STALE"
#
# but `warn` is the COUNTER variable (`warn=0`); the reporter is `warn_msg`. So that line ran a
# command that does not exist — exit 127 — and under `set -e` it ENDED THE AUDIT, at C2e,
# before C2p, C2q, C2r and C2t.
#
# It fired only when audit-adapter-coverage.sh exited non-zero, which never happens on a
# configured developer machine and always happens on a bare CI runner. So the branch was
# unreachable in every environment where anyone would have noticed, and fatal in the one where
# nobody was looking — the whole audit ended and the exit code was the only trace.
#
# The irony is load-bearing: four lines above it sits a comment saying "Do NOT swallow the exit
# code", written after a dead adapter chain once reported a pass. The handler added to stop that
# was itself broken, so the dead chain took the audit down instead of being reported.
#
# A NAME IS NOT A CONTRACT. Shell resolves `warn` at call time; nothing checks it before then,
# and a branch that never runs locally is never checked at all. This does.
#
# Usage: lint-shell-callables.sh [--quiet]
# Exit:  0 every reporter call resolves / 1 one does not
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

# The reporter vocabulary these scripts use. Deliberately a CLOSED list rather than "any
# lowercase word": a general undefined-command checker in shell is a research project (aliases,
# PATH, dynamic dispatch), while this catches the real bug class — a status line that silently
# is not one — with no false positives to argue about.
REPORTERS='ok err warn warn_msg fail pass note skip info log_pass log_fail log_warn say bad add'

fail=0 checked=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  defined=$(grep -oE '^[A-Za-z_][A-Za-z_0-9]*\(\)' "$f" 2>/dev/null | tr -d '()' | sort -u)
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    ln="${hit%%:*}"; body="${hit#*:}"
    name=$(printf '%s' "$body" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z_0-9]*)[[:space:]].*/\1/')
    case " $REPORTERS " in *" $name "*) ;; *) continue ;; esac
    checked=$((checked + 1))
    printf '%s\n' "$defined" | grep -qxF "$name" && continue
    # Reaching here means the name is NOT a defined function. The old code only failed when it
    # was also a `^name=` assignment — so the worse case, a name that exists nowhere at all, fell
    # through the loop and the gate printed "all resolve to a defined function". Verified with a
    # fixture: a script calling an undefined `note "..."` passed this gate and exited 127 itself.
    fail=$((fail + 1))
    if grep -qE "^${name}=" "$f" 2>/dev/null; then
      printf '  FAIL %s:%s calls `%s`, which is a VARIABLE in this file, not a function\n' \
        "${f#"$REPO_ROOT"/}" "$ln" "$name"
    else
      printf '  FAIL %s:%s calls `%s`, which is defined nowhere in this file\n' \
        "${f#"$REPO_ROOT"/}" "$ln" "$name"
    fi
    printf '       exit 127 at run time; under `set -e` that ends the script mid-run.\n'
  done < <(grep -nE '^[[:space:]]*[a-z_][a-z_0-9]*[[:space:]]+"' "$f" 2>/dev/null || true)
done < <(find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)

say ""
if [ "$fail" -eq 0 ]; then say "  $checked reporter call(s) checked, all resolve to a defined function"
else printf '  %d reporter call(s) name something that is not a function\n' "$fail"; fi
[ "$fail" -eq 0 ]
