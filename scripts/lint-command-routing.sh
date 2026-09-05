#!/usr/bin/env bash
# lint-command-routing.sh — the disambiguation in a command's description must hold up.
#
# WHY. 179 commands cannot all be told apart by name, so they are told apart by their
# `description`: each claims quoted trigger phrases and then spends most of its length saying
# which sibling owns the neighbouring case — "not one surface with variant picking
# (/enhance-ui)", "that is /unify-surfaces". That machinery is the single most expensive text
# in the repo (/align spends 1881 chars, ~470 tokens of every session, almost all of it on
# disambiguation — see lint-description-budget.sh), and nothing checked that it was true.
#
# Two checks, both cheap, both regression-catchers rather than backlog-finders — the repo is
# clean on both today:
#
#   1. RESOLVES  — a `/name` in a description names a real command, or a harness builtin from
#                  scripts/_harness-builtins.txt. Renaming a command silently turns every
#                  sibling that pointed at it into a routing instruction for a command that no
#                  longer exists, and the router follows it.
#   2. COLLIDES  — two commands must not claim the SAME quoted trigger phrase unless at least
#                  one of them names the other. Sharing a phrase is legitimate and deliberate
#                  here: /audit and /polish both quote 'pre-launch sweep' precisely to say it
#                  is ambiguous, and each names the other. Sharing it while NEITHER mentions
#                  the other is the actual defect — two commands claiming one phrase with
#                  nothing to break the tie.
#
# Deliberately NOT checked: one-way disambiguation (A names B, B never names A). Measured at
# 89 pairs, nearly all correct — a general command naming a narrower sibling does not oblige
# the sibling to name it back. A gate at that threshold would be noise.
#
# Usage:   lint-command-routing.sh [--repo-root=<dir>] [--quiet]
# Exit:    1 on any violation; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# The shared list lives beside the real scripts; a fixture root carries commands, not scripts.
BUILTINS_FILE="$REPO_ROOT/scripts/_harness-builtins.txt"
[ -f "$BUILTINS_FILE" ] || BUILTINS_FILE="$SELF_DIR/_harness-builtins.txt"

REPO_ROOT="$REPO_ROOT" QUIET="$QUIET" BUILTINS_FILE="$BUILTINS_FILE" python3 <<'PY'
import os, re, sys, glob, collections

ROOT  = os.environ["REPO_ROOT"]
QUIET = os.environ["QUIET"] == "1"
def out(m):
    if not QUIET: print(m)
errors = []
def fail(m): errors.append(m); out("\033[31m✗ %s\033[0m" % m)

builtins = set()
try:
    for line in open(os.environ["BUILTINS_FILE"], encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if line: builtins.add(line)
except OSError:
    fail("scripts/_harness-builtins.txt is unreadable — every builtin would read as dangling")

def description(f):
    try: lines = open(f, encoding="utf-8").read().split("\n")
    except OSError: return ""
    if not lines or lines[0].strip() != "---": return ""
    buf, on = [], False
    for l in lines[1:]:
        if l.strip() == "---": break
        if l.lstrip().startswith("#"): continue
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t](.*))?$", l)
        if m:
            on = m.group(1) == "description"
            if on: buf.append(m.group(2) or "")
            continue
        if on: buf.append(l)
    return "\n".join(buf).strip()

cmds = {}
for pat in ("commands/*.md", "templates/**/commands/*.md"):
    for f in sorted(glob.glob(os.path.join(ROOT, pat), recursive=True)):
        if os.path.relpath(f, ROOT).split(os.sep)[0] == "tests": continue
        cmds.setdefault(os.path.basename(f)[:-3], (f, description(f)))

# A slash-command mention, never a path segment: `ai/patterns/`, `.claude/rules/` and
# `docs/REFERENCE.md` must not read as references to /patterns, /rules and /REFERENCE.
REF = re.compile(r'(?:(?<=^)|(?<=[\s(`"\[]))/([a-z][a-z0-9-]{2,})(?![\w/-])')

refs = collections.defaultdict(set)
for name, (f, d) in cmds.items():
    rel = os.path.relpath(f, ROOT)
    for t in REF.findall(d):
        if t in cmds: refs[name].add(t)
        elif t not in builtins:
            fail("%s: description points at `/%s`, which is not a command in this repo nor a "
                 "harness builtin — the router will follow it" % (rel, t))

phrases = collections.defaultdict(set)
for name, (f, d) in cmds.items():
    for q in re.findall(r"'([^']{8,90})'", d):
        phrases[q.lower().strip()].add(name)

for phrase, owners in sorted(phrases.items()):
    if len(owners) < 2: continue
    for a in sorted(owners):
        for b in sorted(owners):
            if a >= b: continue
            if b not in refs.get(a, set()) and a not in refs.get(b, set()):
                fail("/%s and /%s both claim the trigger '%s' and neither names the other — "
                     "nothing breaks the tie" % (a, b, phrase[:60]))

if errors:
    out("\033[31mcommand-routing: %d violation(s)\033[0m" % len(errors)); sys.exit(1)
out("\033[32m✓ command routing: %d commands, every /reference resolves, every shared trigger "
    "phrase is disambiguated\033[0m" % len(cmds))
sys.exit(0)
PY
