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
#   3. BODIES    — a `/name` that opens a code span in a command, agent or skill BODY (commands/,
#                  templates/packs/*/{commands,agents,skills}, templates/domains,
#                  templates/{repo,workspace}-baseline) names a real command, skill or builtin.
#                  A RATCHET, not a zero gate: every (file, target) pair present when it was written
#                  is listed in scripts/_command-ref-baseline.txt with a reason — most are URL routes
#                  (`/health`, `/login`) that only look like commands. A pair NOT listed fails; a
#                  listed pair that no longer occurs fails too, so the baseline only shrinks.
#                  `--record` rewrites the baseline from the tree (then give each new line a reason).
#   4. LEVEL D   — commands/do.md § "Level D" lists exactly the commands whose frontmatter carries
#                  `disable-model-invocation: true`. /do hands those back to the user instead of
#                  dispatching them, so a command that gains or loses the flag without that list
#                  changing would be dispatched-and-refused, or printed-and-never-run.
#
# Deliberately NOT checked: one-way disambiguation (A names B, B never names A). Measured at
# 89 pairs, nearly all correct — a general command naming a narrower sibling does not oblige
# the sibling to name it back. A gate at that threshold would be noise.
#
# Usage:   lint-command-routing.sh [--repo-root=<dir>] [--quiet] [--record]
# Exit:    1 on any violation; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUIET=0; RECORD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    --record) RECORD=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# The shared list lives beside the real scripts; a fixture root carries commands, not scripts.
BUILTINS_FILE="$REPO_ROOT/scripts/_harness-builtins.txt"
[ -f "$BUILTINS_FILE" ] || BUILTINS_FILE="$SELF_DIR/_harness-builtins.txt"

# The body-reference baseline is NOT shared with fixture roots: a root without its own has an
# empty one, so a fixture proves the check rather than inheriting the repo's accepted pairs.
REF_BASELINE="$REPO_ROOT/scripts/_command-ref-baseline.txt"

REPO_ROOT="$REPO_ROOT" QUIET="$QUIET" RECORD="$RECORD" BUILTINS_FILE="$BUILTINS_FILE" \
REF_BASELINE="$REF_BASELINE" python3 <<'PY'
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
    # (descriptions: the shipped command set as before — the hidden baseline dirs join below)
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

# ---------------------------------------------------------------- 3. BODIES (ratchet)
def g(*pats):
    seen = []
    for p in pats:
        for f in sorted(glob.glob(os.path.join(ROOT, p), recursive=True)):
            if os.path.relpath(f, ROOT).split(os.sep)[0] == "tests" or f in seen: continue
            seen.append(f)
    return seen

known = set(builtins)
# `**` never descends into a dot-dir, so the baselines' .claude/commands are named explicitly.
CMD_PATS = ("commands/*.md", "templates/**/commands/*.md", "templates/*/.claude/commands/*.md")
for f in g(*CMD_PATS): known.add(os.path.basename(f)[:-3])
for f in g("templates/**/skills/*/SKILL.md"): known.add(os.path.basename(os.path.dirname(f)))

# An OPENING backtick only: "`DROP COLUMN`/narrowing" closes a span and then says "/narrowing" in
# prose — the backtick before the slash there follows a word character, so it is not an opener.
BODY = re.compile(r"(?:^|(?<=[\s(\[>|*\"']))`/([a-z][a-z0-9-]{2,})(?=[` ])", re.M)
found = set()
for f in g("commands/*.md", "templates/packs/*/commands/*.md", "templates/packs/*/agents/*.md",
           "templates/packs/*/skills/**/*.md", "templates/domains/**/*.md",
           "templates/repo-baseline/**/*.md", "templates/workspace-baseline/**/*.md",
           "templates/repo-baseline/.claude/**/*.md", "templates/workspace-baseline/.claude/**/*.md"):
    rel = os.path.relpath(f, ROOT)
    try: text = open(f, encoding="utf-8").read()
    except OSError: continue
    for t in BODY.findall(text):
        if t not in known: found.add((rel, t))

bpath = os.environ["REF_BASELINE"]
if os.environ["RECORD"] == "1":
    old = {}
    try:
        for line in open(bpath, encoding="utf-8"):
            if line.startswith("#") or "|" not in line: continue
            key, _, why = line.partition("#")
            old[key.strip()] = why.strip()
    except OSError: pass
    with open(bpath, "w", encoding="utf-8") as h:
        h.write("# Command-reference baseline — scripts/lint-command-routing.sh check 3 (BODIES)\n#\n"
                "# Every `/name` code span in a command/agent/skill body that names no command, skill or\n"
                "# builtin, accepted when recorded. A pair not listed fails; a listed pair that no longer\n"
                "# occurs fails, so this file only shrinks. Re-record with --record; every line needs a reason.\n#\n"
                "# FORMAT  <file>|<target>   # reason\n\n")
        for rel, t in sorted(found):
            k = "%s|%s" % (rel, t)
            h.write("%s   # %s\n" % (k, old.get(k) or "REASON NEEDED"))
    out("recorded %d pair(s) to %s" % (len(found), os.path.relpath(bpath, ROOT))); sys.exit(0)

accepted = set()
try:
    for line in open(bpath, encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if "|" in line:
            a, b = line.split("|", 1); accepted.add((a.strip(), b.strip()))
except OSError:
    pass
for rel, t in sorted(found - accepted):
    fail("%s: `/%s` names no command, skill or harness builtin — fix the reference (or, if it is a "
         "URL route or a deliberate 'there is no /%s', baseline it with a reason)" % (rel, t, t))
for rel, t in sorted(accepted - found):
    fail("%s|%s is in _command-ref-baseline.txt but no longer occurs — delete the line (the "
         "baseline only shrinks)" % (rel, t))

# ---------------------------------------------------------------- 4. LEVEL D ↔ /do's hand-back list
def is_d(f):
    for l in open(f, encoding="utf-8").read().split("\n")[1:]:
        if l.strip() == "---": return False
        if re.match(r"^disable-model-invocation:[ \t]*(true|yes|on)[ \t]*$", l, re.I): return True
    return False
dset = set(os.path.basename(f)[:-3] for f in g(*CMD_PATS) if is_d(f))
do = os.path.join(ROOT, "commands", "do.md")
if os.path.exists(do):
    body = open(do, encoding="utf-8").read()
    m = re.search(r"^### Level D[^\n]*\n(.*?)(?=^#{2,3} )", body, re.S | re.M)
    if not m:
        if dset: fail("commands/do.md has no `### Level D` section, but %d command(s) carry "
                      "disable-model-invocation — /do would dispatch them and be refused" % len(dset))
    else:
        # The list is the section's line(s) made of nothing but `/command` spans joined by " · ";
        # prose around it (which names /do itself) is not the list.
        LIST_LINE = re.compile(r"^`/[a-z][a-z0-9-]*`(?:\s*·\s*`/[a-z][a-z0-9-]*`)*\s*$")
        lst = "\n".join(l for l in m.group(1).split("```")[0].split("\n") if LIST_LINE.match(l.strip()))
        listed = set(re.findall(r"`/([a-z][a-z0-9-]+)`", lst))
        for n in sorted(dset - listed):
            fail("/%s carries disable-model-invocation but commands/do.md § Level D does not list "
                 "it — /do would dispatch it and the Skill tool would refuse" % n)
        for n in sorted(listed - dset):
            fail("commands/do.md § Level D lists /%s, which does not carry disable-model-invocation "
                 "— /do would print a command it could have run" % n)

if errors:
    out("\033[31mcommand-routing: %d violation(s)\033[0m" % len(errors)); sys.exit(1)
out("\033[32m✓ command routing: %d commands, every /reference resolves, every shared trigger "
    "phrase is disambiguated, %d body reference(s) baselined, %d level-D command(s) handed back "
    "by /do\033[0m" % (len(cmds), len(found), len(dset)))
sys.exit(0)
PY
