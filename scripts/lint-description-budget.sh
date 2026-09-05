#!/usr/bin/env bash
# lint-description-budget.sh — a ratchet on the routing text that is paid before anyone asks.
#
# WHY. A command/agent/skill BODY is read only when the thing fires. Its `description` is not:
# it is what routing reads to choose between 195 commands, 123 agents and 116 skills, so it is
# paid on every session that has the artifact installed. Nothing measured it, and the schemas
# that nominally capped it (maxLength 300/400) were unenforced and wrong by a factor of six.
#
# What this does NOT claim. The catalogue totals ~162KB, but no session loads the catalogue —
# a project installs some packs, not all 23. So the budget is set where the cost is actually
# incurred, at three separate scopes:
#
#   GLOBAL   the 15 orchestration commands, installed machine-wide by sync-to-global.sh.
#            This is the only text every session pays, in every project, forever.
#   PACK     one pack's commands + agents + skills. What a project pays for saying yes to it.
#   SINGLE   any one artifact, so no individual description can dominate its scope.
#
# RATCHET. The three ceilings below are set at what the repo measured when they were written.
# They exist to make growth deliberate, not to bless the current numbers — /align alone spends
# 1881 chars (~470 tokens) of every session on one command's routing text. Lower them when the
# routing text gets tightened; raising one is a decision that should be argued for in the diff,
# not a reflex when a gate goes red.
#
# Usage:   lint-description-budget.sh [--repo-root=<dir>] [--quiet] [--print]
# Exit:    1 if any scope is over budget; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
QUIET=0; PRINT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    --print) PRINT=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---- the ratchet (may go down; going up is a decision, not a reflex) ----
# Lowered once already: /align 1881->1283 and /unify-surfaces 1583->1415 by moving the
# JUSTIFICATION out of the routing text. A description's job is to say WHERE the ask belongs,
# not why — the "why" (halt 10, the 21-verb set, the 3-part pipeline) was already duplicated in
# each command's own body, which is read only when the command actually fires. Global fell
# 11153 -> 10387, ~190 tokens off every session.
: "${DESC_BUDGET_GLOBAL:=10700}"   # measured 10387
: "${DESC_BUDGET_PACK:=11700}"     # measured 11457 (frontend, the heaviest)
: "${DESC_BUDGET_SINGLE:=1700}"    # measured 1659  (device-performance-auditor)

REPO_ROOT="$REPO_ROOT" QUIET="$QUIET" PRINT="$PRINT" \
G="$DESC_BUDGET_GLOBAL" P="$DESC_BUDGET_PACK" S="$DESC_BUDGET_SINGLE" python3 <<'PY'
import os, re, sys, glob, collections

ROOT  = os.environ["REPO_ROOT"]
QUIET = os.environ["QUIET"] == "1"
PRINT = os.environ["PRINT"] == "1"
G, P, S = (int(os.environ[k]) for k in ("G", "P", "S"))

def out(m):
    if not QUIET: print(m)
errors = []
def fail(m): errors.append(m); out("\033[31m✗ %s\033[0m" % m)

def description(f):
    """The frontmatter `description` value, continuation lines folded in ('' when absent)."""
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

def files(*pats):
    seen = []
    for p in pats:
        for f in sorted(glob.glob(os.path.join(ROOT, p), recursive=True)):
            if os.path.relpath(f, ROOT).split(os.sep)[0] == "tests": continue
            if f not in seen: seen.append(f)
    return seen

ALL = files("commands/*.md", "templates/**/commands/*.md",
            "templates/**/agents/*.md", "templates/packs/*/skills/*/SKILL.md")

# SINGLE
worst = ("", 0)
for f in ALL:
    n = len(description(f))
    if n > worst[1]: worst = (f, n)
    if n > S:
        fail("%s: description is %d chars, over the %d single-artifact budget"
             % (os.path.relpath(f, ROOT), n, S))

# GLOBAL
gtot = sum(len(description(f)) for f in files("commands/*.md"))
if gtot > G:
    fail("the %d global commands spend %d chars of description, over the %d budget — this is "
         "paid by every session in every project" % (len(files("commands/*.md")), gtot, G))

# PACK
per = collections.Counter()
for f in files("templates/packs/*/commands/*.md", "templates/packs/*/agents/*.md",
               "templates/packs/*/skills/*/SKILL.md"):
    per[os.path.relpath(f, ROOT).split(os.sep)[2]] += len(description(f))
for pack, n in per.most_common():
    if n > P:
        fail("pack `%s` spends %d chars of description, over the %d per-pack budget" % (pack, n, P))

if PRINT:
    out("  global   %6d / %6d  (~%d tok, every session)" % (gtot, G, gtot // 4))
    out("  single   %6d / %6d  (%s)" % (worst[1], S, os.path.relpath(worst[0], ROOT)))
    for pack, n in per.most_common(5):
        out("  pack %-12s %6d / %6d  (~%d tok)" % (pack, n, P, n // 4))

if errors:
    out("\033[31mdescription-budget: %d scope(s) over budget\033[0m" % len(errors)); sys.exit(1)
out("\033[32m✓ description budget: global %d/%d, heaviest pack %d/%d, worst artifact %d/%d\033[0m"
    % (gtot, G, (per.most_common(1)[0][1] if per else 0), P, worst[1], S))
sys.exit(0)
PY
