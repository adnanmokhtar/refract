#!/usr/bin/env bash
# test-discipline-block-sync.sh — pin the AGENTS.md block writer in apply-adapter-sync.sh.
#
# WHY. `_discipline-enforcement.md` says "`/setup-project --refresh` re-syncs it" and for the
# life of that sentence nothing did: no script in the repo mentioned the block. Nine adapters
# share it, so every improvement reached NEW projects only and existing ones kept whatever they
# were installed with. The sync is deterministic now, and this is what stops it rotting back.
#
# The three properties that matter are not "it ran". They are: the marked region becomes the
# current block; every byte OUTSIDE the markers survives (it is the user's file); and a second
# run changes nothing. The fourth case is the refusal — an AGENTS.md with no markers must be
# REPORTED, never guessed at, because the contract places the block "after Project overview,
# before Architecture" and a script cannot see where that is.
#
# Usage: test-discipline-block-sync.sh [--quiet]
# Exit:  0 all assertions hold / 1 one did not

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
SYNC="$REPO_ROOT/scripts/apply-adapter-sync.sh"
SRC="$REPO_ROOT/templates/tool-adapters/_discipline-enforcement.md"

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
pass=0; fail=0
ok()  { pass=$((pass+1)); [ $QUIET -eq 0 ] && echo "  ok    $1"; return 0; }
bad() { fail=$((fail+1)); echo "  FAIL  $1"; return 0; }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1 — expected '$3', got '$2'"; }

[ -f "$SYNC" ] || { echo "SKIP  discipline-block-sync (no apply-adapter-sync.sh)"; exit 0; }
[ -f "$SRC" ]  || { echo "SKIP  discipline-block-sync (no _discipline-enforcement.md)"; exit 0; }

echo "=== test-discipline-block-sync ==="

T=$(mktemp -d)
mkdir -p "$T/.claude/commands" "$T/.claude/rules" "$T/.opencode"
echo '# c' > "$T/.claude/commands/x.md"

# A target carrying a STALE block, with user content on both sides of it.
cat > "$T/AGENTS.md" <<'EOF'
# Project overview

Written by a human. Must survive verbatim.

<!-- discipline-enforcement:start -->
## Discipline enforcement

1. An old rule that no longer matches the canonical block.
<!-- discipline-enforcement:end -->

## Architecture

Also written by a human. Also must survive verbatim.
EOF
before_outside=$(sed '/discipline-enforcement:start/,/discipline-enforcement:end/d' "$T/AGENTS.md")

out=$(bash "$SYNC" "$T" --adapters=opencode --apply 2>&1)

got=$(printf '%s\n' "$out" | grep -c 'REFRESH  AGENTS.md discipline-enforcement block')
assert_eq "a stale block is refreshed" "$got" "1"

# The canonical block, extracted the same way the syncer does, must now be in the target.
expect=$(sed -n '/^<!-- discipline-enforcement:start -->$/,/^<!-- discipline-enforcement:end -->$/p' "$SRC")
actual=$(awk '/^<!-- discipline-enforcement:start -->$/{f=1} f{print} /^<!-- discipline-enforcement:end -->$/{f=0}' "$T/AGENTS.md")
[ "$expect" = "$actual" ] && ok "the marked region is byte-identical to the canonical block" \
                          || bad "the marked region does not match the canonical block"

# THE property that makes this safe to run unattended: it is the user's file.
after_outside=$(sed '/discipline-enforcement:start/,/discipline-enforcement:end/d' "$T/AGENTS.md")
[ "$before_outside" = "$after_outside" ] && ok "every byte outside the markers survived" \
                                         || bad "content outside the markers was modified"
printf '%s\n' "$after_outside" | grep -q 'Also written by a human' \
  && ok "user content AFTER the block is still there" \
  || bad "user content after the block was dropped"

# A second run must be a NO-OP, or a refresh loop dirties the tree on every setup.
out2=$(bash "$SYNC" "$T" --adapters=opencode --apply 2>&1)
got2=$(printf '%s\n' "$out2" | grep -c 'NO-OP    AGENTS.md discipline-enforcement block')
assert_eq "a second run is a NO-OP" "$got2" "1"

# THE REFUSAL. No markers is not an invitation to pick a spot.
printf '# Project overview\n\nNo markers here.\n' > "$T/AGENTS.md"
sum_before=$(shasum "$T/AGENTS.md" | cut -d' ' -f1)
out3=$(bash "$SYNC" "$T" --adapters=opencode --apply 2>&1)
sum_after=$(shasum "$T/AGENTS.md" | cut -d' ' -f1)
assert_eq "an AGENTS.md with no markers is left byte-identical" "$sum_after" "$sum_before"
# Match the printed DETAIL, not the row kind: report_missing_author prints path + detail and
# never the kind, so grepping for 'discipline-block' passed on nothing being reported at all.
printf '%s\n' "$out3" | grep -q 'no <!-- discipline-enforcement:start --> markers' \
  && ok "the missing block is REPORTED rather than guessed at" \
  || bad "no report for an AGENTS.md with no markers"

# No AGENTS.md at all is the per-adapter sync's row to report, not this one's — it must not create one.
rm -f "$T/AGENTS.md"
bash "$SYNC" "$T" --adapters=opencode --apply >/dev/null 2>&1
[ -f "$T/AGENTS.md" ] && bad "AGENTS.md was created out of nothing" \
                      || ok "a missing AGENTS.md is not conjured by the block syncer"

rm -rf "$T"
echo "----"
echo "discipline-block-sync: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
