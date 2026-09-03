#!/usr/bin/env bash
# test-new-artifact.sh — pin the scaffolder that adds a pack artifact and re-derives every figure.
#
# The property under test is NOT "it creates a file". It is that the figures land at the value
# DISK dictates. new-artifact.sh computes each count rather than incrementing it, so a fixture
# whose numbers start out WRONG must come out right — that is the difference between a scaffolder
# and one more place holding a number, and it is why --resync doubles as a repair tool.
#
# Usage:  test-new-artifact.sh [--quiet]
# Exit:   1 on any failed assertion.

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
TOOL="$REPO_ROOT/scripts/new-artifact.sh"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
pass=0; fail=0
say() { [ $QUIET -eq 0 ] && echo "$@"; return 0; }
ok()  { if [ "$2" = "0" ]; then say "  ok    $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }

command -v python3 >/dev/null 2>&1 || { echo "SKIP  test-new-artifact (needs python3)"; exit 0; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/new-artifact.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT

seed() {   # a mini tree carrying every figure the tool owns — deliberately WRONG to start
  rm -rf "$WORK/repo"; mkdir -p "$WORK/repo"/{commands,scripts,docs,assets,.claude-plugin}
  mkdir -p "$WORK/repo/templates/packs/alpha"/{commands,skills,agents}
  echo "# g1" > "$WORK/repo/commands/g1.md"
  echo "# c1" > "$WORK/repo/templates/packs/alpha/commands/c1.md"
  mkdir -p "$WORK/repo/templates/packs/alpha/skills/s1"; echo "# s1" > "$WORK/repo/templates/packs/alpha/skills/s1/SKILL.md"
  echo "# a1" > "$WORK/repo/templates/packs/alpha/agents/a1.md"
  # Built through a variable on purpose. lint-setup-contracts.sh Rule 13 reads a literal
  # `scripts/<name>.sh` token anywhere in a file under scripts/ as a REMEDIATION this script
  # prescribes, and fails when the named file does not exist in the repo. These two are fixture
  # files inside a temp dir, not instructions — same trap lint-handoffs.sh sets for `_<name>.md`
  # artifact tokens, which cost two separate repairs today. Keep the path split.
  SDIR="$WORK/repo/scripts"
  echo "# tooling" > "$SDIR/x.sh"; echo "# a test" > "$SDIR/test-t.sh"
  cat > "$WORK/repo/README.md" <<'R'
| **99 skills** | x |
| **99 commands** | 99 global + 99 pack-level |
Another 99 commands ship inside the packs and install per-project.
| **99 scripts** | x |
R
  printf '<text>Another 99 commands ship inside the 99 packs — 99 commands in total.</text>\n' > "$WORK/repo/assets/command-map.svg"
  printf '<text>99 validators + sync scripts</text>\n' > "$WORK/repo/assets/architecture.svg"
  printf -- '- pack catalog (99 commands, 99 agents)\n' > "$WORK/repo/docs/setup-project-cheatsheet.md"
  printf '{ "description": "99 scripts" }\n' > "$WORK/repo/.claude-plugin/plugin.json"
  printf '# Commands\n\n### Alpha track\n\n| cmd | what |\n|---|---|\n| `/c1` | one |\n' > "$WORK/repo/docs/COMMANDS.md"
  printf '# Reference\n' > "$WORK/repo/docs/REFERENCE.md"
}
has() { grep -qF -- "$2" "$WORK/repo/$1"; }

say "=== --resync repairs figures it did not write ==="
seed
bash "$TOOL" --repo-root="$WORK/repo" --resync >/dev/null 2>&1
has README.md "**1 skills**";                    ok "README skills 99 -> 1" $?
has README.md "1 global + 1 pack-level";         ok "README split recomputed" $?
has README.md "**2 commands**";                  ok "README total = global + pack" $?
has README.md "**2 scripts**";                   ok "README scripts counted" $?
has assets/architecture.svg "1 validators";      ok "SVG excludes test-* from the tooling count" $?
has .claude-plugin/plugin.json "2 scripts";      ok "manifest scripts recomputed" $?
has docs/setup-project-cheatsheet.md "1 commands, 1 agents"; ok "cheatsheet pack figures recomputed" $?

say ""
say "=== adding a skill moves only the skill figure ==="
seed
bash "$TOOL" --repo-root="$WORK/repo" --kind=skill --pack=alpha --name=s2 --description="A second skill." >/dev/null 2>&1
[ -f "$WORK/repo/templates/packs/alpha/skills/s2/SKILL.md" ]; ok "SKILL.md created at the pack path" $?
grep -q "^name: s2" "$WORK/repo/templates/packs/alpha/skills/s2/SKILL.md"; ok "frontmatter carries name" $?
grep -q "^description: A second skill." "$WORK/repo/templates/packs/alpha/skills/s2/SKILL.md"; ok "frontmatter carries the given description" $?
has README.md "**2 skills**";                    ok "skill count follows disk" $?
has README.md "**2 commands**";                  ok "command count unchanged by a skill" $?

say ""
say "=== adding a command updates all six sites, docs included ==="
seed
bash "$TOOL" --repo-root="$WORK/repo" --kind=command --pack=alpha --name=c2 --description="A second command." >/dev/null 2>&1
[ -f "$WORK/repo/templates/packs/alpha/commands/c2.md" ]; ok "command file created" $?
has docs/COMMANDS.md '`/c2`';                    ok "documented in COMMANDS.md (verify-doc-sync's whole test)" $?
has README.md "**3 commands**";                  ok "README total recomputed" $?
has README.md "1 global + 2 pack-level";         ok "README split recomputed" $?
has README.md "Another 2 commands ship";         ok "README prose figure recomputed" $?
has assets/command-map.svg "Another 2 commands"; ok "command-map.svg recomputed" $?
has assets/command-map.svg "3 commands in total"; ok "command-map.svg total recomputed" $?

say ""
say "=== refusals ==="
seed
bash "$TOOL" --repo-root="$WORK/repo" --kind=skill --pack=alpha --name=s3 >/dev/null 2>&1
[ $? -ne 0 ]; ok "a missing --description is refused (A02 bans placeholders)" $?
bash "$TOOL" --repo-root="$WORK/repo" --kind=skill --pack=nope --name=s3 --description="x" >/dev/null 2>&1
[ $? -ne 0 ]; ok "an unknown pack is refused" $?
bash "$TOOL" --repo-root="$WORK/repo" --kind=skill --pack=alpha --name=Bad_Name --description="x" >/dev/null 2>&1
[ $? -ne 0 ]; ok "a non-kebab-case name is refused" $?
bash "$TOOL" --repo-root="$WORK/repo" --kind=skill --pack=alpha --name=s1 --description="x" >/dev/null 2>&1
[ $? -ne 0 ]; ok "overwriting an existing artifact is refused" $?

say ""
say "=== --dry-run writes nothing ==="
seed
before=$(cat "$WORK/repo/README.md")
bash "$TOOL" --repo-root="$WORK/repo" --kind=skill --pack=alpha --name=s9 --description="x" --dry-run >/dev/null 2>&1
[ "$before" = "$(cat "$WORK/repo/README.md")" ] && [ ! -e "$WORK/repo/templates/packs/alpha/skills/s9" ]
ok "no file created and no figure moved" $?

echo ""
echo "new-artifact: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
