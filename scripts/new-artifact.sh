#!/usr/bin/env bash
# new-artifact.sh — add a pack skill or pack command, and update every place that counts it.
#
# WHY. Adding one artifact is a two-minute edit followed by a scavenger hunt. Measured by adding
# a bare artifact and running all 41 gates:
#
#   a new SKILL   → 2 gates red, 2 assertions   (pack-matrix.svg · README "N skills")
#   a new COMMAND → 5 gates red, 8 assertions across 6 files:
#                     docs/CHEATSHEET.md              (generated, stale)
#                     docs/COMMANDS.md                (undocumented command)
#                     assets/command-map.svg          ("Another N commands ship …")
#                     assets/pack-matrix.svg          (generated, stale)
#                     README.md                       (3 separate figures)
#                     docs/setup-project-cheatsheet.md("N commands, M agents")
#
# That is the same one-fact-in-many-places shape this repo keeps paying for — a script count
# asserted in four files went red on CI twice in one day, a hook list in two places left a
# blocking hook in 0 of 12 adapters, and a ledger's own size sentence caught a truncation. The
# gates catch every one of them. Nothing made them cheap to get right the first time.
#
# COUNTS ARE COMPUTED, NEVER INCREMENTED. Every figure is re-derived from disk and written, so
# this script cannot introduce the drift it exists to prevent, and `--resync` alone REPAIRS a
# figure someone else got wrong. An incrementing script would be one more place holding a number.
#
# The count formulas are the ones docs/setup-project-cheatsheet.md § pack catalog names, so the
# script and the doc cannot disagree about what "a command" is.
#
# Usage:
#   new-artifact.sh --kind=skill   --pack=<pack> --name=<name> --description="<one line>"
#   new-artifact.sh --kind=command --pack=<pack> --name=<name> --description="<one line>"
#   new-artifact.sh --resync                      # repair every figure from disk, add nothing
#   [--dry-run]                                   # print what would change, write nothing
#
# A description is REQUIRED and is written into the artifact and, for a command, into
# docs/COMMANDS.md. Hard rule A02 bans placeholders — a scaffolder that emits `<TBD>` would be
# shipping the thing the rule forbids, so there is no default.
#
# Exit: 0 on success; 1 on a usage error or a gate that stays red afterwards.
# Notes: bash 3.2 (macOS) compatible.

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

KIND=""; PACK=""; NAME=""; DESC=""; DRY=0; RESYNC=0
while [ $# -gt 0 ]; do
  case "$1" in
    --kind=*)        KIND="${1#*=}" ;;
    --pack=*)        PACK="${1#*=}" ;;
    --name=*)        NAME="${1#*=}" ;;
    --description=*) DESC="${1#*=}" ;;
    --dry-run)       DRY=1 ;;
    --resync)        RESYNC=1 ;;
    # --repo-root points the tool at a fixture tree. A scaffolder that can only ever run against
    # its own checkout is a scaffolder nothing can pin, and every other script here is pinned.
    --repo-root=*)   REPO_ROOT="${1#*=}" ;;
    -h|--help)       sed -n '1,40p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

REPO_ROOT="$(cd -P "$REPO_ROOT" && pwd)" || exit 1   # absolute before cd
cd "$REPO_ROOT" || exit 1

die() { echo "ERROR: $*" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || die "python3 is required (the generators are python)"

# ---- the figures, computed from disk with the documented formulas ----
count_all() {
  N_SKILLS=$(find templates/packs -name SKILL.md | wc -l | tr -d ' ')
  N_PACKCMD=$(ls templates/packs/*/commands/*.md 2>/dev/null | grep -v '/_' | wc -l | tr -d ' ')
  N_GLOBAL=$(ls commands/*.md 2>/dev/null | wc -l | tr -d ' ')
  N_AGENTS=$(ls templates/packs/*/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  N_TRACKS=$(find templates/packs -mindepth 1 -maxdepth 1 -type d ! -name '_*' | wc -l | tr -d ' ')
  N_TOTAL=$((N_GLOBAL + N_PACKCMD))
  # The script count is the same class of figure and is asserted in three more places. It moved
  # twice in one day and went red on CI both times, so --resync owns it too: a figure this tool
  # can compute is a figure it should not leave to a human to remember.
  N_SCRIPTS=$(find scripts -maxdepth 1 \( -name '*.sh' -o -name '*.py' \) | wc -l | tr -d ' ')
  N_TOOLING=$(find scripts -maxdepth 1 \( -name '*.sh' -o -name '*.py' \) | grep -v '/test-' | wc -l | tr -d ' ')
}

# ---- create the artifact ----
if [ "$RESYNC" -eq 0 ]; then
  [ -n "$KIND" ] || die "--kind=skill|command is required (or --resync)"
  [ -n "$PACK" ] || die "--pack=<pack> is required"
  [ -n "$NAME" ] || die "--name=<name> is required"
  [ -n "$DESC" ] || die "--description is required — A02 bans placeholders, so there is no default"
  [ -d "templates/packs/$PACK" ] || die "no such pack: templates/packs/$PACK"
  case "$NAME" in *[!a-z0-9-]*) die "name must be kebab-case: $NAME" ;; esac

  case "$KIND" in
    skill)
      TARGET="templates/packs/$PACK/skills/$NAME/SKILL.md"
      [ -e "$TARGET" ] && die "already exists: $TARGET"
      if [ "$DRY" -eq 0 ]; then
        mkdir -p "$(dirname "$TARGET")"
        { printf -- '---\n'
          printf 'name: %s\n' "$NAME"
          printf 'description: %s\n' "$DESC"
          printf -- '---\n\n'
          printf '# %s\n\n' "$NAME"
          printf '%s\n' "$DESC"
        } > "$TARGET" || die "could not write $TARGET"
      fi
      echo "created  $TARGET" ;;
    command)
      TARGET="templates/packs/$PACK/commands/$NAME.md"
      [ -e "$TARGET" ] && die "already exists: $TARGET"
      if [ "$DRY" -eq 0 ]; then
        # A pack need not already have a commands/ directory — several ship skills only. Without
        # this the redirect failed on such a pack while the run went on to insert the docs row and
        # print PASS, reporting a command that does not exist.
        mkdir -p "$(dirname "$TARGET")" || die "cannot create $(dirname "$TARGET")"
        { printf -- '---\n'
          printf 'description: %s\n' "$DESC"
          printf 'kind: command\n'
          printf 'pack: %s\n' "$PACK"
          printf -- '---\n\n'
          printf '# /%s\n\n## What this does\n\n%s\n' "$NAME" "$DESC"
        } > "$TARGET" || die "could not write $TARGET"
        # docs/COMMANDS.md — verify-doc-sync.sh fails on any command absent from it. Insert into
        # the pack's own `### <pack> track` table when there is one, else the catch-all section.
        python3 - "$PACK" "$NAME" "$DESC" <<'PY'
import re, sys
pack, name, desc = sys.argv[1], sys.argv[2], sys.argv[3]
p = "docs/COMMANDS.md"; lines = open(p).read().split("\n")
hdr = None
for i, l in enumerate(lines):
    if re.match(r'^### ', l) and pack.lower().replace("-", " ") in l.lower().replace("-", " "):
        hdr = i; break
if hdr is None:
    for i, l in enumerate(lines):
        if l.strip() == "### Additional track commands": hdr = i; break
if hdr is None:
    lines.append(""); lines.append("| `/%s` | %s |" % (name, desc))
else:
    end = hdr + 1
    while end < len(lines) and not re.match(r'^#{2,3} ', lines[end]): end += 1
    while end > hdr and not lines[end-1].strip().startswith("|"): end -= 1
    lines.insert(end, "| `/%s` | %s |" % (name, desc))
open(p, "w").write("\n".join(lines))
print("documented in docs/COMMANDS.md")
PY
      fi
      echo "created  $TARGET" ;;
    *) die "--kind must be skill or command" ;;
  esac
fi

count_all
echo "counts from disk: $N_TRACKS tracks · $N_SKILLS skills · $N_GLOBAL global + $N_PACKCMD pack = $N_TOTAL commands · $N_AGENTS agents"
echo "                  $N_SCRIPTS scripts ($N_TOOLING excluding test-*)"
[ "$DRY" -eq 1 ] && { echo "(dry run — nothing written)"; exit 0; }

# ---- rewrite every figure to the computed value ----
python3 - "$N_SKILLS" "$N_PACKCMD" "$N_GLOBAL" "$N_TOTAL" "$N_AGENTS" "$N_TRACKS" "$N_SCRIPTS" "$N_TOOLING" <<'PY'
import os, re, sys
sk, pc, gl, tot, ag, tr, sc, to = (int(x) for x in sys.argv[1:9])
edits = [
    ("README.md",                      r'\*\*\d+ skills\*\*',                         '**%d skills**' % sk),
    ("README.md",                      r'\*\*\d+ commands\*\*',                       '**%d commands**' % tot),
    ("README.md",                      r'\d+ global \+ \d+ pack-level',               '%d global + %d pack-level' % (gl, pc)),
    ("README.md",                      r'Another \d+ commands ship inside the packs', 'Another %d commands ship inside the packs' % pc),
    ("assets/command-map.svg",         r'Another \d+ commands ship inside the \d+ packs', 'Another %d commands ship inside the %d packs' % (pc, tr)),
    ("assets/command-map.svg",         r'— \d+ commands in total',                    '— %d commands in total' % tot),
    # The second number in "N of the M pack commands". It sat wrong (133 vs 134) because
    # verify-figure-stats.sh only compared the FIRST integer in that sentence — so nothing owned
    # it and nothing checked it. Both halves are covered now.
    ("assets/command-map.svg",         r'of the \d+ pack commands',                   'of the %d pack commands' % pc),
    ("docs/setup-project-cheatsheet.md", r'\d+ commands, \d+ agents',                 '%d commands, %d agents' % (pc, ag)),
    ("README.md",                      r'\*\*\d+ scripts\*\*',                        '**%d scripts**' % sc),
    (".claude-plugin/plugin.json",     r'\d+ scripts',                                '%d scripts' % sc),
    ("assets/architecture.svg",        r'\d+ validators',                             '%d validators' % to),
]
# Read EVERY file first. The original buffered edits and wrote them only after the read loop, so
# one absent path raised mid-loop and discarded every edit already computed — and the shell
# ignored python's exit status, so the run still printed PASS with README untouched. A partial
# rewrite of a set of figures that must agree with each other is worse than no rewrite: it leaves
# some sites current and some stale, which is the drift this tool exists to remove.
missing = [p for p, _, _ in edits if not os.path.exists(p)]
if missing:
    sys.stderr.write("cannot resync — missing: %s\n" % ", ".join(sorted(set(missing))))
    sys.exit(1)

touched = {}
for path, pat, rep in edits:
    s = touched.get(path) or open(path).read()
    new, n = re.subn(pat, rep, s)
    if n: touched[path] = new
for path, s in touched.items():
    open(path, "w").write(s); print("  updated  %s" % path)
PY
[ $? -eq 0 ] || die "figure rewrite failed — nothing was changed"

[ -f scripts/gen-pack-matrix.py ] && python3 scripts/gen-pack-matrix.py >/dev/null 2>&1 && echo "  regenerated  assets/pack-matrix.svg"
[ -f scripts/gen-cheatsheet.py  ] && python3 scripts/gen-cheatsheet.py  >/dev/null 2>&1 && echo "  regenerated  docs/CHEATSHEET.md"

# ---- self-check: the gates this touches must be green, or the scaffolder is incomplete ----
echo ""
echo "verifying the gates a new artifact makes red:"
rc_total=0
for g in verify-readme-stats verify-figure-stats verify-pack-matrix verify-cheatsheet verify-doc-sync verify-plugin-manifest; do
  [ -f "scripts/$g.sh" ] || { printf "  skip  %s (not in this tree)\n" "$g"; continue; }
  bash "scripts/$g.sh" >/dev/null 2>&1
  rc=$?
  [ $rc -eq 0 ] && printf "  ok    %s\n" "$g" || { printf "  FAIL  %s\n" "$g"; rc_total=1; }
done
[ $rc_total -eq 0 ] && echo "" && echo "PASS — every registration site agrees with disk."
exit $rc_total
