#!/usr/bin/env bash
# test-skill-overrides.sh — pins apply-skill-overrides.sh's merge contract on throwaway fixtures.
#
# The contract, case by case:
#   1 fresh      A stays off the map, D stays off the map, every B is added as "name-only";
#                permissions and hooks already in settings.json survive byte-for-byte in value.
#   2 rerun      a second --apply is a NO-OP and does not rewrite the file (mtime unchanged).
#   3 owner      an entry the owner wrote ("on") is kept, never flipped to "name-only".
#   4 local      a name the owner set in settings.local.json is not added to settings.json.
#   5 shape      skillOverrides as a STRING (the wrong shape) is refused, file untouched, exit 1.
#   6 badjson    settings.json that does not parse is refused, file untouched, exit 1.
#   7 dryrun     without --apply nothing is written.
#   8 nofile     no settings.json → one is created holding only skillOverrides.
#
# Usage: test-skill-overrides.sh   ·   Exit: 0 all pass / 1 any fail

set -uo pipefail
export LC_ALL=C
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
APPLY_SO="$REPO_ROOT/scripts/apply-skill-overrides.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/skill-overrides.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pass=0; failn=0
ok()  { pass=$((pass + 1)); echo "  ok    $*"; }
bad() { failn=$((failn + 1)); echo "  FAIL  $*" >&2; }

# A globals dir and a project tree: do (A), add-thing (B), ship-it (D), demo-skill (B skill), g-one (B global), g-dee (D global)
mkdir -p "$WORK/globals"
printf -- '---\ndescription: global one\n---\n' > "$WORK/globals/g-one.md"
printf -- '---\ndescription: global dee\ndisable-model-invocation: true\n---\n' > "$WORK/globals/g-dee.md"
printf -- '---\ndescription: router\n---\n' > "$WORK/globals/do.md"
mk_target() {  # $1 = dir
  mkdir -p "$1/.claude/commands" "$1/.claude/skills/demo-skill"
  printf -- '---\ndescription: add a thing\n---\n' > "$1/.claude/commands/add-thing.md"
  printf -- '---\ndescription: ship it\ndisable-model-invocation: true\n---\n' > "$1/.claude/commands/ship-it.md"
  printf -- '---\nname: demo-skill\ndescription: scan\n---\n' > "$1/.claude/skills/demo-skill/SKILL.md"
}
run() { bash "$APPLY_SO" "$@" --globals-dir="$WORK/globals" --quiet; }
jget() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(d.get("skillOverrides"), sort_keys=True))' "$1"; }

# 1 fresh
T="$WORK/t1"; mk_target "$T"
printf '{\n  "permissions": {"allow": ["Bash(ls:*)"]},\n  "hooks": {"Stop": []}\n}\n' > "$T/.claude/settings.json"
run "$T" --apply; got="$(jget "$T/.claude/settings.json")"
want='{"add-thing": "name-only", "demo-skill": "name-only", "g-one": "name-only"}'
[ "$got" = "$want" ] && ok "fresh: B added, A and D left off" || bad "fresh: got $got want $want"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["permissions"]=={"allow":["Bash(ls:*)"]} and d["hooks"]=={"Stop":[]} else 1)' "$T/.claude/settings.json" \
  && ok "fresh: permissions + hooks preserved" || bad "fresh: other keys changed"
bk=0; for d in "$T"/.claude/backups/skill-overrides-*/settings.json; do [ -f "$d" ] && bk=1; done
[ $bk -eq 1 ] && ok "fresh: backup written" || bad "fresh: no backup"

# 2 rerun
mt() { python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$1"; }
before="$(mt "$T/.claude/settings.json")"; sleep 1; run "$T" --apply
[ "$before" = "$(mt "$T/.claude/settings.json")" ] && ok "rerun: no-op, file not rewritten (mtime unchanged)" || bad "rerun: file rewritten"

# 3 owner
T="$WORK/t3"; mk_target "$T"
printf '{"skillOverrides": {"add-thing": "on", "do": "name-only"}}\n' > "$T/.claude/settings.json"
run "$T" --apply; got="$(jget "$T/.claude/settings.json")"
want='{"add-thing": "on", "demo-skill": "name-only", "do": "name-only", "g-one": "name-only"}'
[ "$got" = "$want" ] && ok "owner: owner values kept (even on an A name)" || bad "owner: got $got want $want"

# 4 local
T="$WORK/t4"; mk_target "$T"
printf '{}\n' > "$T/.claude/settings.json"
printf '{"skillOverrides": {"demo-skill": "off"}}\n' > "$T/.claude/settings.local.json"
run "$T" --apply; got="$(jget "$T/.claude/settings.json")"
want='{"add-thing": "name-only", "g-one": "name-only"}'
[ "$got" = "$want" ] && ok "local: a settings.local.json entry is the owner's" || bad "local: got $got want $want"

# 5 shape
T="$WORK/t5"; mk_target "$T"
printf '{"skillOverrides": "name-only"}\n' > "$T/.claude/settings.json"; c0="$(cksum < "$T/.claude/settings.json")"
run "$T" --apply >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && [ "$c0" = "$(cksum < "$T/.claude/settings.json")" ] && ok "shape: string form refused, untouched" || bad "shape: rc=$rc or file changed"

# 6 badjson
T="$WORK/t6"; mk_target "$T"
printf '{"permissions": {,}\n' > "$T/.claude/settings.json"; c0="$(cksum < "$T/.claude/settings.json")"
run "$T" --apply >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && [ "$c0" = "$(cksum < "$T/.claude/settings.json")" ] && ok "badjson: refused, untouched" || bad "badjson: rc=$rc or file changed"

# 7 dryrun
T="$WORK/t7"; mk_target "$T"
printf '{}\n' > "$T/.claude/settings.json"; c0="$(cksum < "$T/.claude/settings.json")"
run "$T"; [ "$c0" = "$(cksum < "$T/.claude/settings.json")" ] && ok "dryrun: nothing written" || bad "dryrun: file changed"

# 8 nofile
T="$WORK/t8"; mk_target "$T"
run "$T" --apply; got="$(jget "$T/.claude/settings.json" 2>/dev/null)"
want='{"add-thing": "name-only", "demo-skill": "name-only", "g-one": "name-only"}'
[ "$got" = "$want" ] && ok "nofile: created with skillOverrides only" || bad "nofile: got $got"

echo "skill-overrides: pass=$pass fail=$failn"
[ $failn -eq 0 ]
