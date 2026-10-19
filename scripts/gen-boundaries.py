#!/usr/bin/env python3
"""gen-boundaries.py — the generated `## Lenses` (and, later, `## Boundary`) blocks of every agent.

WHY. Phase 6 folds specialist agents into LENSES: the knowledge file a roster agent reads by path
(`.claude/lenses/<x>.md`). A lens nobody names is knowledge nobody reads, which is how 33 of the 35
domain reviewer agents sat unreached for months (dispatched by nobody; their one reference was the
generated review matrix). So the mapping lens → reader is DATA, and the reader's body is GENERATED
from it, never hand-kept:

  pack lens     scripts/_agent-merge-map.json — the entry whose `lens` is the file; reader = `to`
                (a role that does not exist yet resolves through the entry that renames into it)
  domain lens   templates/domains/<d>/_version.json — `reviewer`, `reviewer_pack`, `fallback`, `lens`

OUTPUT. Between `<!-- BEGIN GENERATED lenses … -->` / `<!-- END GENERATED lenses -->` in each reader:
one row per lens, PRIMARY, or `fallback` when the primary reviewer's pack is not installed (the
fallback is always an always-on agent, so no domain lens is ever orphaned). Nothing else in the
agent file is touched.

`## Boundary` (PLAN.md §5.1: "Mine" = ownership.json classes this agent owns, "Not mine" = classes a
detector it names routes elsewhere) is generated the same way, for every agent that carries its markers
(`--add-boundary=` adds them). The agents WITHOUT one are RATCHETED as debt: the count may only fall
(scripts/_boundaries-baseline.txt), so a new agent ships with its block.
A class whose `target` names an agent that does not exist is debt too, ratcheted the same way.

Usage:  gen-boundaries.py --write [--add-boundary=<agent>,…] | --check | --list [--root=<dir>]
        --add-boundary  give these agents a generated Boundary block (every later --write keeps it current)
Exit:   --check: 0 current and within the ratchet · 1 a block is stale / missing, or debt grew
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for a in sys.argv[1:]:
    if a.startswith("--root="): ROOT = a.split("=", 1)[1]
os.chdir(ROOT)
MODE = next((a for a in sys.argv[1:] if a in ("--write", "--check", "--list")), "--check")
ALWAYS_ON = {"delivery", "repo-baseline", "security", "code-quality", "business", "learning",
             "documentation", "testing"}
BEGIN = "<!-- BEGIN GENERATED lenses (scripts/gen-boundaries.py; do not edit by hand) -->"
END = "<!-- END GENERATED lenses -->"
BLOCK_RE = re.compile(r"<!-- BEGIN GENERATED lenses[^\n]*-->\n.*?<!-- END GENERATED lenses -->", re.S)
HEAD_RE = re.compile(r"^## Lenses\s*$", re.M)


def agent_files():
    out = {}
    for p in sorted(glob.glob("templates/packs/*/agents/*.md") + glob.glob("templates/repo-baseline/.claude/agents/*.md")):
        out.setdefault(os.path.basename(p)[:-3], p)
    return out


AGENTS = agent_files()


def pack_of(p):
    parts = p.split("/")
    return parts[2] if parts[1] == "packs" else "repo-baseline"


def load(p, default):
    try:
        return json.load(open(p, encoding="utf-8"))
    except (OSError, ValueError):
        return default


MM = load("scripts/_agent-merge-map.json", {"agents": []}).get("agents", [])


def resolve(role):
    """A role name → the agent file that plays it today (a planned rename: its old name)."""
    if role in AGENTS:
        return role
    for e in MM:
        if e.get("to") == role and e.get("kind") == "rename" and e.get("old_name") in AGENTS:
            return e["old_name"]
    return None


def lens_rows():
    """[(reader, installed lens name, source description, applies-when, is_fallback)]"""
    rows, problems = [], []
    for e in MM:
        lp = e.get("lens") or ""
        if e.get("status") != "merged":
            continue                       # a staged lens (planned / kept) has no reader yet
        if not lp.startswith("templates/packs/") or "/lenses/" not in lp or not os.path.isfile(lp):
            continue
        reader = resolve(e.get("to", ""))
        if not reader:
            problems.append("%s: reader `%s` is no agent" % (lp, e.get("to"))); continue
        pk = lp.split("/")[2]
        rows.append((reader, os.path.basename(lp), "%s pack (Phase 6 merge, `scripts/_agent-merge-map.json`)" % pk,
                     "the %s pack is installed" % pk if pk not in ALWAYS_ON else "always (the %s pack is always on)" % pk,
                     False))
    for vj in sorted(glob.glob("templates/domains/*/_version.json")):
        v = load(vj, {}); d = os.path.basename(os.path.dirname(vj))
        if not v.get("lens"):
            continue
        lp = os.path.join(os.path.dirname(vj), v["lens"])
        if not os.path.isfile(lp):
            problems.append("%s: lens %s does not resolve" % (vj, v["lens"])); continue
        reviewer, rpack, fb = v.get("reviewer"), v.get("reviewer_pack"), v.get("fallback")
        if reviewer not in AGENTS:
            problems.append("%s: reviewer `%s` is no agent" % (vj, reviewer)); continue
        was = ""
        cond = "domain `%s` is installed" % d
        rows.append((reviewer, os.path.basename(lp), "domain %s%s" % (d, was),
                     cond + ("" if not rpack or rpack in ALWAYS_ON else " (needs the %s pack)" % rpack), False))
        if fb and fb != reviewer:
            if fb not in AGENTS:
                problems.append("%s: fallback `%s` is no agent" % (vj, fb)); continue
            rows.append((fb, os.path.basename(lp), "domain %s — fallback" % d,
                         "%s and the %s pack is NOT installed" % (cond, rpack), True))
    return rows, problems


def render(rows):
    out = [BEGIN,
           "Read the lens the brief names (`lens: .claude/lenses/<x>.md`) before grading; a domain lens adds its",
           "checklist to yours, a pack lens may replace your input and output (its own text says so). A lens path",
           "you cannot open returns `BLOCKED(lens missing)` — never a silent pass.",
           "",
           "| Lens (installed path) | Source | Read when |",
           "|---|---|---|"]
    for r in sorted(rows, key=lambda r: (r[4], r[1])):
        out.append("| `.claude/lenses/%s` | %s | %s |" % (r[1], r[2], r[3]))
    out.append(END)
    return "\n".join(out)


def apply_block(text, block):
    if BLOCK_RE.search(text):
        return BLOCK_RE.sub(lambda m: block, text, count=1)
    # Insert a `## Lenses` section before `## Related`, `## Hard rules` or at the end.
    sec = "## Lenses\n\n" + block + "\n"
    for anchor in ("\n## Related", "\n## Hard rules", "\n## Output format"):
        i = text.find(anchor)
        if i >= 0:
            return text[:i + 1] + sec + "\n" + text[i + 1:]
    return text.rstrip("\n") + "\n\n" + sec


def boundary_debt():
    own = load("templates/governance/ownership.json", {}).get("classes", {})
    lead = lambda s: (re.match(r"[a-z0-9-]+", s.strip()) or re.match(r"", "")).group(0)   # "x (api lens)" / "x reports; …" → x
    missing_targets = sorted(set(lead(c["target"]) for c in own.values()
                                 if c.get("target") and lead(c["target"]) and not resolve(lead(c["target"]))))
    no_block = [n for n, p in AGENTS.items() if "<!-- BEGIN GENERATED boundary" not in open(p, encoding="utf-8").read()]
    return no_block, missing_targets


BB = "<!-- BEGIN GENERATED boundary (scripts/gen-boundaries.py; do not edit by hand) -->"
BE = "<!-- END GENERATED boundary -->"
BB_RE = re.compile(r"<!-- BEGIN GENERATED boundary[^\n]*-->\n.*?<!-- END GENERATED boundary -->", re.S)
ADD_BOUNDARY = set()
for a in sys.argv[1:]:
    if a.startswith("--add-boundary="): ADD_BOUNDARY |= set(x for x in a.split("=", 1)[1].split(",") if x)


def boundary_block(name, text):
    """Mine = classes whose ownership `owner` names this agent; Target = classes whose Phase-6 `target`
    is this role (they move here when the merge lands); Not mine = classes a detector this agent names
    routes to another owner (≤ 8)."""
    own = load("templates/governance/ownership.json", {}).get("classes", {})
    lead = lambda s: (re.match(r"[a-z0-9-]+", (s or "").strip()) or re.match(r"", "")).group(0)
    names_me = re.compile(r"(?<![\w-])(?:[a-z-]+/agents/)?%s(?![\w-])" % re.escape(name))
    mine, target, notmine = [], [], []
    clip = lambda t, n: t if len(t) <= n else t[:n].rsplit(" ", 1)[0] + " …"
    for cls, c in sorted(own.items()):
        dtext = c.get("detector") or ""
        det = (re.sub(r"\s*\(.*$", "", dtext) or dtext).split("/")[-1]
        # the PRIMARY owner only: "x/agents/cost-reviewer (judge …; @verifier mode refute …)" is
        # cost-reviewer's class — the verifier named in the parenthesis refutes it, it does not own it
        primary = re.split(r"\s*[(;]", c.get("owner") or "", maxsplit=1)[0]
        if names_me.search(primary):
            mine.append("`%s` (%s)" % (cls, det or "no detector"))
        elif lead(c.get("target")) == name:
            target.append("`%s`" % cls)
        elif det and re.search(r"(?<![\w-])%s(?![\w-])" % re.escape(det), text) and len(notmine) < 8:
            o = re.sub(r"\s*\(.*$", "", (c.get("owner") or "?").split(" · ")[0]).strip()
            notmine.append("`%s` → %s (%s pack; without it: %s)" % (cls, o, c.get("pack", "?"),
                           clip(c.get("fallback") or "reported UNROUTED", 80)))
    out = [BB, "Generated from `templates/governance/ownership.json` and `scripts/_agent-merge-map.json`.", ""]
    out.append("- **Mine:** " + (", ".join(mine) if mine else "no class yet."))
    if target:
        out.append("- **Phase-6 target (owned elsewhere until the merge is earned):** " + ", ".join(target))
    if notmine:
        out.append("- **Not mine** (a detector I name routes these elsewhere):")
        out += ["  - " + x for x in notmine]
    out.append(BE)
    return "\n".join(out)


def apply_boundary(text, block):
    if BB_RE.search(text):
        return BB_RE.sub(lambda m: block, text, count=1)
    sec = "## Boundary\n\n" + block + "\n"
    for anchor in ("\n## Lenses", "\n## Related", "\n## Hard rules"):
        i = text.find(anchor)
        if i >= 0:
            return text[:i + 1] + sec + "\n" + text[i + 1:]
    return text.rstrip("\n") + "\n\n" + sec


rows, problems = lens_rows()
by_reader = {}
for r in rows:
    by_reader.setdefault(r[0], []).append(r)
stale = []
for name, p in sorted(AGENTS.items()):
    text = open(p, encoding="utf-8").read()
    want = by_reader.get(name)
    if want:
        new = apply_block(text, render(want))
    else:   # an agent that reads no lens carries no block
        new = re.sub(r"\n## Lenses\s*\n\n?" + BLOCK_RE.pattern + r"\n?", "\n", text, flags=re.S) if BLOCK_RE.search(text) else text
    if BB_RE.search(new) or name in ADD_BOUNDARY:
        new = apply_boundary(new, boundary_block(name, BB_RE.sub("", new)))
    if new != text:
        stale.append(p)
        if MODE == "--write":
            open(p, "w", encoding="utf-8").write(new)

no_block, missing_targets = boundary_debt()
BASE = "scripts/_boundaries-baseline.txt"
base = {}
try:
    for l in open(BASE, encoding="utf-8"):
        l = l.split("#", 1)[0].split()
        if len(l) >= 2: base[l[0]] = int(l[1])
except OSError:
    pass

if MODE == "--list":
    for r in sorted(rows):
        print("%-24s %-34s %s%s" % (r[0], r[1], r[2], "  [fallback]" if r[4] else ""))
    print("boundary debt: %d agents without a generated Boundary block; ownership targets with no agent: %s"
          % (len(no_block), ", ".join(missing_targets) or "none"))
    sys.exit(0)
if MODE == "--write":
    print("gen-boundaries: %d agent file(s) rewritten, %d lens row(s) across %d reader(s)"
          % (len(stale), len(rows), len(by_reader)))
    for p in problems: print("  ✗ " + p)
    sys.exit(1 if problems else 0)

bad = []
if stale: bad.append("%d agent(s) carry a stale or missing Lenses block — run scripts/gen-boundaries.py --write: %s"
                     % (len(stale), ", ".join(stale[:6])))
bad += problems
if len(no_block) > base.get("boundary-missing", 0):
    bad.append("agents without a Boundary block grew: %d > %d" % (len(no_block), base.get("boundary-missing", 0)))
if len(missing_targets) > base.get("target-missing", 0):
    bad.append("ownership targets naming no agent grew: %d > %d (%s)"
               % (len(missing_targets), base.get("target-missing", 0), ", ".join(missing_targets)))
print("boundaries — %d lens row(s) over %d reader(s); Boundary debt %d/%d agents; targets with no agent %d/%d"
      % (len(rows), len(by_reader), len(no_block), base.get("boundary-missing", 0),
         len(missing_targets), base.get("target-missing", 0)))
for b in bad: print("  ✗ " + b)
sys.exit(1 if bad else 0)
