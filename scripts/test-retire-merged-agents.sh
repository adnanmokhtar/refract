#!/usr/bin/env bash
# test-retire-merged-agents.sh — fixtures for scripts/retire-merged-agents.sh (PLAN.md §6, migration of
# existing installs on /setup-project --refresh).
#
# Stages an install whose .claude/agents/ holds byte-exact Refract copies (blobs read from this repo's
# git history, the same ids scripts/_agent-merge-map.json lists) and asserts:
#   dry-run        nothing is written; the would-be moves are listed
#   retired+stub   an unedited copy of a `merged` agent whose name no template ships any more
#                  (payment-reviewer) is moved to .claude/backups/retired-agents/ and replaced by a
#                  stub that names the role and the lens that replaced it
#   edited         an owner-edited copy of a merged agent (webhook-reviewer + one line) is kept,
#                  reported EDITED with the lens path, and gets no stub
#   same-name      an unedited copy whose name is still shipped by another template (testing's
#                  test-engineer → delivery's) is retired WITHOUT a stub, so the live agent of that
#                  name installs in its place
#   live copy      the CURRENT template of a still-shipped name (delivery's test-engineer) is untouched
#   planned        an agent whose merge is only `planned` (endpoint-tester, a W3 specialist) is untouched
# The cases use entries whose status is stable while other clusters merge (domain lenses, the
# test-engineer twin, a W3 specialist); a fixture whose status changed fails an assertion rather than passing silently.
#   idempotent     a second run changes no byte and no mtime, appends no duplicate note, and never
#                  reports its own stub as EDITED
# Exit: 0 all pass · 1 a case failed.
set -uo pipefail
export LC_ALL=C
# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd
REPO="$(cd "$SELF_DIR/.." && pwd)"
RM="$SELF_DIR/retire-merged-agents.sh"
MAP="$SELF_DIR/_agent-merge-map.json"
command -v git >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || { echo "SKIP test-retire-merged-agents (needs git + python3)"; exit 0; }
W="$(mktemp -d "${TMPDIR:-/tmp}/test-retire-merged.XXXXXX")"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok() { if [ "$1" = "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL  $3 — want '$2', got '$1'"; fi; }

# blob <old_path> → the newest known blob of that map entry that this checkout's object store holds
blob() {
  python3 - "$MAP" "$1" <<'PY' | while read -r b; do git -C "$REPO" cat-file -e "$b" 2>/dev/null && { echo "$b"; break; }; done
import json, sys
for a in json.load(open(sys.argv[1]))["agents"]:
    if a["old_path"] == sys.argv[2]:
        for b in reversed(a["known_blobs"]): print(b)
PY
}
stage() {  # $1 = agent file name, $2 = old_path whose known blob to write
  local b; b="$(blob "$2")"
  [ -n "$b" ] || { echo "FAIL  fixture — no known blob of $2 in this checkout"; fail=$((fail+1)); return 1; }
  git -C "$REPO" cat-file -p "$b" > "$P/.claude/agents/$1.md"
}
P="$W/proj"; mkdir -p "$P/.claude/agents"
stage payment-reviewer templates/domains/payment/agents/payment-reviewer.md
stage webhook-reviewer templates/domains/webhook/agents/webhook-reviewer.md
printf '\n- our own rule: every webhook handler logs the delivery id\n' >> "$P/.claude/agents/webhook-reviewer.md"
stage test-engineer templates/packs/testing/agents/test-engineer.md
stage endpoint-tester templates/packs/backend/agents/endpoint-tester.md
mkdir -p "$W/live/.claude/agents"; cp "$REPO/templates/packs/delivery/agents/test-engineer.md" "$W/live/.claude/agents/"

snap() { ( cd "$1" && find . -type f -print0 | sort -z | xargs -0 ls -lT 2>/dev/null || find . -type f -exec ls -l --time-style=full-iso {} + ) | sed 's/^[^ ]* *[^ ]* *//' ; }

# ---- dry run writes nothing ----
before="$(snap "$P")"
rc=0; out="$(bash "$RM" "$P" 2>&1)" || rc=$?
ok "$rc" 0 "dry run exits 0"
ok "$(snap "$P")" "$before" "dry run writes nothing"
ok "$(printf '%s' "$out" | grep -c 'would retire.*payment-reviewer')" 1 "dry run lists the move"

# ---- apply ----
rc=0; out="$(bash "$RM" "$P" --apply 2>&1)" || rc=$?
ok "$rc" 0 "apply exits 0"
A="$P/.claude/agents"; B="$P/.claude/backups/retired-agents"
# retired + stub
ok "$([ -f "$B/payment-reviewer.md" ] && echo moved || echo missing)" moved "unedited merged copy moved to backups"
ok "$(grep -c '^name: payment-reviewer$' "$A/payment-reviewer.md" 2>/dev/null)" 1 "stub keeps the old name"
ok "$(grep -c 'refract:retired-stub' "$A/payment-reviewer.md" 2>/dev/null)" 1 "stub carries the marker"
ok "$(grep -c '@code-reviewer' "$A/payment-reviewer.md" 2>/dev/null | awk '{print ($1>0)}')" 1 "stub names the role that replaced it"
ok "$(grep -c '\.claude/lenses/payment-review\.md' "$A/payment-reviewer.md" 2>/dev/null | awk '{print ($1>0)}')" 1 "stub names the installed lens path"
ok "$(printf '%s' "$out" | grep -c 'renamed: @payment-reviewer → @code-reviewer (lens .claude/lenses/payment-review.md)')" 1 "rename note printed"
ok "$(wc -l < "$A/payment-reviewer.md" | awk '{print ($1<=14)}')" 1 "stub is short (listing cost)"
# edited
ok "$(grep -c 'our own rule' "$A/webhook-reviewer.md")" 1 "owner-edited copy kept"
ok "$(grep -c 'refract:retired-stub' "$A/webhook-reviewer.md")" 0 "owner-edited copy gets no stub"
ok "$(printf '%s' "$out" | grep -c 'EDITED retired agent webhook-reviewer: its knowledge now lives in .claude/lenses/webhook-review.md')" 1 "edited copy reported with its lens"
# same-name (still shipped by another template): retired, no stub
ok "$([ -e "$A/test-engineer.md" ] && echo present || echo absent)" absent "testing's test-engineer retired, no stub (delivery's installs)"
ok "$([ -f "$B/test-engineer.md" ] && echo moved || echo missing)" moved "testing's test-engineer backed up"
# planned: untouched
ok "$(git hash-object "$A/endpoint-tester.md")" "$(blob templates/packs/backend/agents/endpoint-tester.md)" "planned merge leaves the agent untouched"
# notes
V="$P/.claude/_command-variants.md"
ok "$(grep -c 'payment-reviewer' "$V")" 1 "rename recorded once in _command-variants.md"
ok "$(grep -c 'webhook-reviewer' "$V")" 1 "edited copy recorded once in _command-variants.md"

# ---- live copy of a still-shipped name is not touched ----
rc=0; out2="$(bash "$RM" "$W/live" --apply 2>&1)" || rc=$?
ok "$rc" 0 "live install exits 0"
ok "$(cmp -s "$W/live/.claude/agents/test-engineer.md" "$REPO/templates/packs/delivery/agents/test-engineer.md" && echo same || echo changed)" same "delivery's current test-engineer untouched"
ok "$(printf '%s' "$out2" | grep -c 'EDITED')" 0 "a live agent is never reported EDITED"

# ---- idempotent ----
before="$(snap "$P")"
rc=0; out3="$(bash "$RM" "$P" --apply 2>&1)" || rc=$?
ok "$rc" 0 "second apply exits 0"
ok "$(snap "$P")" "$before" "second apply changes no byte and no mtime"
ok "$(printf '%s' "$out3" | grep -c 'EDITED retired agent payment-reviewer')" 0 "own stub never reported EDITED"

echo "test-retire-merged-agents: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
