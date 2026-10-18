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
#   GLOBAL   the 16 orchestration commands, installed machine-wide by sync-to-global.sh.
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
# INSTALL SET — what Claude Code itself would list (THR-DESC-BUDGET, proposal §8.6). The three
# scopes above are sums of OUR text; the platform pays something else. Claude Code 2.1.236 builds
# one skill listing per session from every non-D command and skill, measured in chars:
#   budget = 200,000 context tokens × 4 bytes/token × 0.01 = 8,000 chars (40,000 at 1M)
#   entry  = len(name) + 4 + min(len(description [+ " - " + when_to_use]), 1536)
#   name-only entry (skillOverrides "name-only") = len(name) + 2;  D (disable-model-invocation) = 0
#   entries joined by "\n".  Over budget → name-only entries keep their form and the rest keep
#   their description, in usage order, while it still fits; the remainder are TRUNCATED to the
#   name. A fresh install has no usage, so the order is the listing order.
# This script derives three installs from templates/ exactly the way /setup-project does —
# globals (commands/), then the repo-baseline commands (Phase 4.1), then each pack in order with
# phase-4.2-apply.md's collision rule (first pack owns the bare name, a different later file lands
# as <name>.<pack>, an identical one is skipped; a skill already installed is skipped) — and
# reports, for each, the listing the model would see:
#   raw      no visibility levels at all (what shipped before Phase 3)
#   D-only   disable-model-invocation honoured, no skillOverrides (a plugin-sourced install, or a
#            project whose settings.json has none — skillOverrides does NOT apply to plugin skills)
#   levels   D honoured AND /setup-project's skillOverrides (A full, B name-only) written
# with the entries the platform would truncate. The installs and their ratchet ceilings live in
# scripts/_install-set-baseline.txt; the levels in templates/governance/visibility-levels.json.
# LISTING ORDER IS AN ASSUMPTION: globals, then project commands, then project skills, each
# alphabetical. The truncated COUNT barely moves with order; WHICH names get truncated does.
#
#   --target=<repo>  report the same simulation for a REAL installed repo: its .claude/commands,
#                    .claude/skills and the global commands, with its settings.json /
#                    settings.local.json skillOverrides as configured now, and as they would be
#                    once apply-skill-overrides.sh has run. Report only — always exit 0 unless the
#                    target is missing. --globals-dir=<dir> overrides where globals are read from.
#
# Usage:   lint-description-budget.sh [--repo-root=<dir>] [--quiet] [--print]
#          lint-description-budget.sh --target=<repo> [--globals-dir=<dir>]
# Exit:    1 if any scope is over budget; 0 otherwise. 2 on usage error.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
SELF_ROOT="$REPO_ROOT"
QUIET=0; PRINT=0; TARGET=""; GLOBALS_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    --print) PRINT=1; shift ;;
    --target=*) TARGET="${1#*=}"; shift ;;
    --globals-dir=*) GLOBALS_DIR="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
if [ -n "$TARGET" ] && [ ! -d "$TARGET" ]; then echo "ERR: target not found: $TARGET" >&2; exit 2; fi

# ---- the ratchet (may go down; going up is a decision, not a reflex) ----
# Lowered once already: /align 1881->1283 and /unify-surfaces 1583->1415 by moving the
# JUSTIFICATION out of the routing text. A description's job is to say WHERE the ask belongs,
# not why — the "why" (halt 10, the 21-verb set, the 3-part pipeline) was already duplicated in
# each command's own body, which is read only when the command actually fires. Global fell
# 11153 -> 10387, ~190 tokens off every session.
: "${DESC_BUDGET_GLOBAL:=10700}"   # measured 10387
: "${DESC_BUDGET_PACK:=11700}"     # measured 11457 (frontend, the heaviest)
: "${DESC_BUDGET_SINGLE:=1700}"    # measured 1659  (device-performance-auditor)

# The fixture-root convention (same as lint-command-routing.sh's builtins list): a fixture root
# carries its own install-set baseline and levels file; a root without one uses the real ones.
INSTALL_FILE="$REPO_ROOT/scripts/_install-set-baseline.txt"
[ -f "$INSTALL_FILE" ] || INSTALL_FILE="$SELF_ROOT/scripts/_install-set-baseline.txt"
LEVELS_FILE="$REPO_ROOT/templates/governance/visibility-levels.json"
[ -f "$LEVELS_FILE" ] || LEVELS_FILE="$SELF_ROOT/templates/governance/visibility-levels.json"
THR_FILE="$REPO_ROOT/templates/governance/thresholds.json"
[ -f "$THR_FILE" ] || THR_FILE="$SELF_ROOT/templates/governance/thresholds.json"
[ -n "$GLOBALS_DIR" ] || GLOBALS_DIR="$SELF_ROOT/commands"

REPO_ROOT="$REPO_ROOT" QUIET="$QUIET" PRINT="$PRINT" TARGET="$TARGET" GLOBALS_DIR="$GLOBALS_DIR" \
INSTALL_FILE="$INSTALL_FILE" LEVELS_FILE="$LEVELS_FILE" THR_FILE="$THR_FILE" \
G="$DESC_BUDGET_GLOBAL" P="$DESC_BUDGET_PACK" S="$DESC_BUDGET_SINGLE" python3 <<'PY'
import os, re, sys, glob, json, collections, filecmp

ROOT   = os.environ["REPO_ROOT"]
QUIET  = os.environ["QUIET"] == "1"
PRINT  = os.environ["PRINT"] == "1"
TARGET = os.environ["TARGET"]
G, P, S = (int(os.environ[k]) for k in ("G", "P", "S"))

def out(m):
    if not QUIET: print(m)
errors = []
def fail(m): errors.append(m); out("\033[31m✗ %s\033[0m" % m)

def frontmatter_lines(f):
    try: lines = open(f, encoding="utf-8").read().split("\n")
    except OSError: return []
    if not lines or lines[0].strip() != "---": return []
    fm = []
    for l in lines[1:]:
        if l.strip() == "---": return fm
        fm.append(l)
    return []

def field(f, key):
    """A frontmatter value, continuation lines folded in ('' when absent). Raw — quotes kept."""
    buf, on = [], False
    for l in frontmatter_lines(f):
        if l.lstrip().startswith("#"): continue
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t](.*))?$", l)
        if m:
            on = m.group(1) == key
            if on: buf.append(m.group(2) or "")
            continue
        if on: buf.append(l)
    return "\n".join(buf).strip()

def description(f): return field(f, "description")

def scalar(raw):
    """The YAML scalar the platform sees: quotes off, escapes resolved, folded lines joined."""
    v = " ".join(x.strip() for x in raw.split("\n")).strip()
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        v = v[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    elif len(v) >= 2 and v[0] == "'" and v[-1] == "'":
        v = v[1:-1].replace("''", "'")
    return v

def listing_desc(f):
    d, w = scalar(description(f)), scalar(field(f, "when_to_use"))
    return "%s - %s" % (d, w) if w else d

def is_d(f):
    return re.match(r"(?i)^(true|yes|on)$", scalar(field(f, "disable-model-invocation")) or "") is not None

def files(*pats):
    seen = []
    for p in pats:
        for f in sorted(glob.glob(os.path.join(ROOT, p), recursive=True)):
            if os.path.relpath(f, ROOT).split(os.sep)[0] == "tests": continue
            if f not in seen: seen.append(f)
    return seen

def load_json(p):
    try: return json.load(open(p, encoding="utf-8"))
    except (OSError, ValueError): return None

LEVELS = load_json(os.environ["LEVELS_FILE"]) or {}
FRONT  = list(LEVELS.get("front_door", []))
FRONT_MAX = int(LEVELS.get("front_door_max", 5))
thr = ((load_json(os.environ["THR_FILE"]) or {}).get("thresholds", {}).get("THR-DESC-BUDGET", {})
       .get("value", {}))
PER_ENTRY  = int(thr.get("per_entry_max_chars", 1536))
FRONT_CAP  = int(thr.get("front_door_entry_max_chars", 600))
TARGET_VIS = int(thr.get("install_model_visible_target_chars", 6000))
BUDGET     = int(200000 * 4 * 0.01)        # THR-DESC-BUDGET.platform_listing_chars at 200K

# ---------------------------------------------------------------- the platform's listing model
def simulate(entries, name_only):
    """entries: [(name, desc)] in listing order, D already removed. name_only: set of names.
    Mirrors Claude Code 2.1.236's listing budget: returns (visible_chars, demand_chars, truncated)."""
    rows = []
    for n, d in entries:
        if n in name_only: rows.append((n, 0, len(n) + 2, True))
        else:
            dl = min(len(d), PER_ENTRY)
            rows.append((n, dl, len(n) + 4 + dl, False))
    sep = max(0, len(rows) - 1)
    demand = sum(r[2] for r in rows) + sep
    if demand <= BUDGET: return demand, demand, []
    base = sum(r[2] if r[3] else len(r[0]) + 2 for r in rows) + sep
    room, trunc = BUDGET - base, []
    for n, dl, el, fixed in rows:
        if fixed: continue
        extra = el - (len(n) + 2)
        if extra <= room: room -= extra
        else: trunc.append(n)
    return BUDGET - room if room >= 0 else base, demand, trunc

def three_ways(entries_all):
    """entries_all: [(name, desc, D)] → dict of raw / D-only / levels results."""
    raw   = [(n, d) for n, d, _ in entries_all]
    nod   = [(n, d) for n, d, dd in entries_all if not dd]
    b_set = set(n for n, d, dd in entries_all if not dd and n not in FRONT)
    return {"raw": simulate(raw, set()), "D-only": simulate(nod, set()),
            "levels": simulate(nod, b_set)}, len(raw), len(nod), len(b_set)

def fmt_trunc(t, k=8):
    return ", ".join(t[:k]) + (" … +%d more" % (len(t) - k) if len(t) > k else "") if t else "none"

# ------------------------------------------------------------------------------- --target mode
if TARGET:
    gdir = os.environ["GLOBALS_DIR"]
    ents, seen = [], set()
    def add(n, f):
        if n in seen: return
        seen.add(n); ents.append((n, listing_desc(f), is_d(f)))
    proj = sorted(glob.glob(os.path.join(TARGET, ".claude", "commands", "*.md")))
    skl  = sorted(glob.glob(os.path.join(TARGET, ".claude", "skills", "*", "SKILL.md")))
    pnames = set(os.path.basename(f)[:-3] for f in proj)
    for f in sorted(glob.glob(os.path.join(gdir, "*.md"))):
        n = os.path.basename(f)[:-3]
        if n not in pnames: add(n, f)              # a project command of the same name shadows it
    for f in proj: add(os.path.basename(f)[:-3], f)
    for f in skl: add(scalar(field(f, "name")) or os.path.basename(os.path.dirname(f)), f)
    owner = {}
    for sf in ("settings.json", "settings.local.json"):
        so = (load_json(os.path.join(TARGET, ".claude", sf)) or {}).get("skillOverrides")
        if isinstance(so, dict): owner.update(so)
    now_nod = [(n, d) for n, d, dd in ents if not dd and owner.get(n) not in ("off", "user-invocable-only")]
    now = simulate(now_nod, set(n for n, _ in now_nod if owner.get(n) == "name-only"))
    res, nraw, nnod, nb = three_ways(ents)
    print("description listing — %s  (budget %d chars at 200K context; target ≤%d model-visible)"
          % (TARGET, BUDGET, TARGET_VIS))
    print("  %d entries: %d D (not listed, user-typed only), %d front door (A), %d name-only (B)"
          % (nraw, nraw - nnod, nnod - nb, nb))
    print("  as configured now : %5d visible of %5d demanded — %d truncated to the name: %s"
          % (now[0], now[1], len(now[2]), fmt_trunc(now[2])))
    lv = res["levels"]
    print("  with Refract levels: %5d visible of %5d demanded — %d truncated to the name: %s"
          % (lv[0], lv[1], len(lv[2]), fmt_trunc(lv[2])))
    print("  (skillOverrides does not apply to plugin-sourced skills; a plugin install lists in full)")
    sys.exit(0)

def frontdoor_check():
    if len(FRONT) > FRONT_MAX:
        fail("visibility-levels.json lists %d front-door names, over front_door_max %d — every "
             "extra front door is a description every session pays for" % (len(FRONT), FRONT_MAX))
    for f in files("commands/*.md", "templates/**/commands/*.md", "templates/**/.claude/commands/*.md"):
        n = os.path.basename(f)[:-3]
        if n not in FRONT: continue
        dl = len(listing_desc(f))
        if dl > FRONT_CAP:
            fail("%s: front-door description is %d chars, over the %d cap (THR-DESC-BUDGET."
                 "front_door_entry_max_chars)" % (os.path.relpath(f, ROOT), dl, FRONT_CAP))

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

frontdoor_check()

# INSTALL SET — derive each fixture install the way /setup-project does, then simulate.
def install_set(packs):
    ents, cmd_files, skills = [], {}, set()
    for f in files("commands/*.md"):                                  # globals (user scope)
        ents.append((os.path.basename(f)[:-3], f))
    g_names = set(n for n, _ in ents)
    proj = []
    for f in sorted(glob.glob(os.path.join(ROOT, "templates/repo-baseline/.claude/commands/*.md"))):
        n = os.path.basename(f)[:-3]; cmd_files[n] = f; proj.append((n, f))   # Phase 4.1
    for p in packs:                                                   # Phase 4.2.b, pack order
        for f in sorted(glob.glob(os.path.join(ROOT, "templates/packs", p, "commands", "*.md"))):
            n = os.path.basename(f)[:-3]
            if n not in cmd_files: cmd_files[n] = f; proj.append((n, f)); continue
            if filecmp.cmp(f, cmd_files[n], shallow=False): continue
            v = "%s.%s" % (n, p)
            if v not in cmd_files: cmd_files[v] = f; proj.append((v, f))
    skl = []
    for p in packs:
        for f in sorted(glob.glob(os.path.join(ROOT, "templates/packs", p, "skills", "*", "SKILL.md"))):
            n = scalar(field(f, "name")) or os.path.basename(os.path.dirname(f))
            if n in skills: continue
            skills.add(n); skl.append((n, f))
    pn = set(n for n, _ in proj)
    order = [(n, f) for n, f in ents if n not in pn] + sorted(proj) + sorted(skl)
    # One listing entry per NAME: the platform de-duplicates by name, so a command and a skill
    # that share one are listed once — the first one loaded (the platform runs the skill; see align-detect § Notes).
    uniq, seen = [], set()
    for n, f in order:
        if n in seen: continue
        seen.add(n); uniq.append((n, f))
    return [(n, listing_desc(f), is_d(f)) for n, f in uniq], g_names

rows = []
try:
    for line in open(os.environ["INSTALL_FILE"], encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if not line: continue
        parts = [x.strip() for x in line.split("|")]
        if len(parts) != 4:
            fail("%s: malformed row `%s` — want <install>|<packs>|<max visible>|<max truncated>"
                 % (os.path.basename(os.environ["INSTALL_FILE"]), line)); continue
        rows.append((parts[0], [x for x in parts[1].split(",") if x], int(parts[2]), int(parts[3])))
except OSError:
    fail("scripts/_install-set-baseline.txt is unreadable — the install-set ratchet has no installs")

sim_lines = []
for name, packs, cap_vis, cap_tr in rows:
    missing = [p for p in packs if not os.path.isdir(os.path.join(ROOT, "templates/packs", p))]
    ents, g_names = install_set([p for p in packs if p not in missing])
    res, nraw, nnod, nb = three_ways(ents)
    lv = res["levels"]
    if lv[0] > cap_vis:
        fail("install `%s`: %d model-visible listing chars with levels, over its ratchet %d"
             % (name, lv[0], cap_vis))
    if len(lv[2]) > cap_tr:
        fail("install `%s`: the platform would truncate %d entries even with levels, over its "
             "ratchet %d — %s" % (name, len(lv[2]), cap_tr, fmt_trunc(lv[2])))
    gl = three_ways([e for e in ents if e[0] in g_names])[0]["levels"]
    sim_lines.append("  install %-18s %3d entries (%d D, %d A, %d B)  globals-only %d chars"
                     % (name, nraw, nraw - nnod, nnod - nb, nb, gl[0]))
    for k in ("raw", "D-only", "levels"):
        v, dmd, tr = res[k]
        sim_lines.append("    %-7s visible %5d / demand %6d  %s target %d  truncated %3d: %s"
                         % (k, v, dmd, "≤" if v <= TARGET_VIS else ">", TARGET_VIS, len(tr),
                            fmt_trunc(tr, 6)))
    if missing: sim_lines.append("    (packs not in this root, skipped: %s)" % ", ".join(missing))

if PRINT:
    out("  global   %6d / %6d  (~%d tok, every session)" % (gtot, G, gtot // 4))
    out("  single   %6d / %6d  (%s)" % (worst[1], S, os.path.relpath(worst[0], ROOT)))
    for pack, n in per.most_common(5):
        out("  pack %-12s %6d / %6d  (~%d tok)" % (pack, n, P, n // 4))
    out("  platform listing budget %d chars at 200K context (THR-DESC-BUDGET); front door %d/%d"
        % (BUDGET, len(FRONT), FRONT_MAX))
    for l in sim_lines: out(l)

if errors:
    out("\033[31mdescription-budget: %d scope(s) over budget\033[0m" % len(errors)); sys.exit(1)
out("\033[32m✓ description budget: global %d/%d, heaviest pack %d/%d, worst artifact %d/%d, "
    "%d install set(s) within their listing ratchet\033[0m"
    % (gtot, G, (per.most_common(1)[0][1] if per else 0), P, worst[1], S, len(rows)))
sys.exit(0)
PY
