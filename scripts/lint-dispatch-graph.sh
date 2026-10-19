#!/usr/bin/env bash
# lint-dispatch-graph.sh — every dispatch edge in the framework's text must land on something that
# ships, and an edge to a RETIRED agent must not survive the change that retired it.
#
# WHY. Agents, commands, skills and lenses name each other in prose: `@schema-reviewer`, "run
# `n-plus-one-scan`", `/db-fix`, `.claude/lenses/payment-review.md`. Nothing resolved those names.
# Phase 6 retires agents into lenses (scripts/_agent-merge-map.json) and renames others, and the
# rule "every reference is updated in the same change" was a sentence until this script. The edges
# are text, not imports, so build-graph.py is not reused; this reads the prose itself.
#
# CATALOG  agents   templates/packs/*/agents, templates/domains/*/agents, repo-baseline, workspace-baseline
#          commands commands/, templates/packs/*/commands, templates/domains/*/commands, the baselines
#          skills   templates/packs/*/skills/*/SKILL.md (+ the baselines' skills)
#          lenses   templates/packs/*/lenses/*.md, templates/domains/*/lenses/*.md
#          builtins scripts/_harness-builtins.txt
#          retired  _agent-merge-map.json entries with status `merged` whose name no live agent carries
# CORPUS   templates/, commands/, docs/, README.md, CONTRIBUTING.md, skills.sh.json — minus every
#          CHANGELOG.md and the merge map itself (history is allowed to name the past). Fenced code
#          blocks are read too: a dispatch written in a code block is still a dispatch.
#          templates/tool-adapters/ is read for D2 only (its persona names are illustrative).
#
# CHECKS
#   D1 dangling   an `@name` that looks like an agent (a catalog agent, a retired one, or a name ending
#                 -reviewer|-auditor|-architect|-engineer|-designer|-analyst|-critic|-investigator|-writer)
#                 that no catalog agent carries; a `lenses/<x>.md` path no lens file carries
#   D2 retired    ANY word-boundary mention of a retired agent name — `@x`, `x`, `pack/agents/x`
#   D3 unguarded  `@x` from pack A to an agent that ships only in pack B, B not always-on (delivery,
#                 repo-baseline, security, code-quality, business, learning, documentation, testing),
#                 with no guard in the same paragraph or table row: "installed", "UNROUTED",
#                 "(<B> pack" / "<B> pack)"
#   D4 untyped    a line that dispatches an `@agent` and names no artifact (a path, `ai/…`, `.claude/…`,
#                 a `*.json` schema) — the handoff is a conversation, not a contract
#   D5 lens       a lens file not named as PRIMARY by exactly one agent's generated `## Lenses` block;
#                 a domain `_version.json` whose `reviewer`/`fallback` is no catalog agent
#
# RATCHET  scripts/_dispatch-graph-baseline.txt holds one ceiling per check. D1, D2 and D5 are 0 and
#          stay 0; D3 and D4 may only fall (lower the line when they do — --record rewrites it).
#
# Usage:   lint-dispatch-graph.sh [--root=<dir>] [--list[=D1,D2,…]] [--json] [--record] [--self-test] [--quiet]
# Exit:    0 within the ratchet · 1 a check is over its ceiling · 2 usage
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
ROOT="$REPO_ROOT"; MODE=check; LIST=""; JSON=0; QUIET=0
for a in "$@"; do
  case "$a" in
    --root=*)    ROOT="${a#--root=}" ;;
    --list)      LIST="D1,D2,D3,D4,D5" ;;
    --list=*)    LIST="${a#--list=}" ;;
    --json)      JSON=1 ;;
    --record)    MODE=record ;;
    --self-test) MODE=selftest ;;
    --quiet)     QUIET=1 ;;
    -h|--help)   sed -n '2,40p' "$SELF"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "ERR: python3 required" >&2; exit 2; }

if [ "$MODE" = selftest ]; then
  TD=$(mktemp -d "${TMPDIR:-/tmp}/lint-dispatch-graph.XXXXXX"); trap 'rm -rf "$TD"' EXIT
  mkdir -p "$TD/templates/packs/aa/agents" "$TD/templates/packs/aa/commands" "$TD/templates/packs/bb/agents" \
           "$TD/templates/packs/aa/lenses" "$TD/templates/domains/dd/lenses" "$TD/scripts" "$TD/commands"
  printf -- '---\nname: x-reviewer\ndescription: d\n---\n## Lenses\n<!-- BEGIN GENERATED lenses -->\n| `.claude/lenses/l1.md` | primary |\n| `.claude/lenses/dd-review.md` | primary |\n<!-- END GENERATED lenses -->\n' > "$TD/templates/packs/aa/agents/x-reviewer.md"
  printf -- '---\nname: y-reviewer\ndescription: d\n---\n' > "$TD/templates/packs/bb/agents/y-reviewer.md"
  printf 'lens\n' > "$TD/templates/packs/aa/lenses/l1.md"; printf 'lens\n' > "$TD/templates/domains/dd/lenses/dd-review.md"
  printf '{"reviewer":"x-reviewer","lens":"lenses/dd-review.md"}\n' > "$TD/templates/domains/dd/_version.json"
  printf '{"version":1,"agents":[{"old_name":"gone-auditor","old_path":"templates/packs/aa/agents/gone-auditor.md","to":"x-reviewer","lens":"templates/packs/aa/lenses/l1.md","status":"merged"}]}\n' > "$TD/scripts/_agent-merge-map.json"
  : > "$TD/scripts/_harness-builtins.txt"
  printf 'D1 0\nD2 0\nD3 0\nD4 9\nD5 0\n' > "$TD/scripts/_dispatch-graph-baseline.txt"
  clean() { printf -- '---\nname: c\ndescription: d\n---\nDispatch `@x-reviewer` with `.claude/lenses/l1.md`.\n' > "$TD/templates/packs/aa/commands/c.md"; }
  fails=0
  expect() { # $1 want-rc $2 label
    local rc=0; bash "$SELF" --root="$TD" --quiet >/dev/null 2>&1 || rc=$?
    if [ "$rc" = "$1" ]; then echo "  ok   $2"; else echo "  FAIL $2 (rc $rc, want $1)"; fails=$((fails+1)); fi
  }
  clean; expect 0 "clean tree passes"
  clean; echo 'Then `@nobody-reviewer` grades it.' >> "$TD/templates/packs/aa/commands/c.md"; expect 1 "D1: a dangling @agent fails"
  clean; echo 'Read `.claude/lenses/missing.md`.' >> "$TD/templates/packs/aa/commands/c.md"; expect 1 "D1: a dangling lens path fails"
  clean; echo 'Still dispatches `gone-auditor`.' >> "$TD/templates/packs/aa/commands/c.md"; expect 1 "D2: a retired agent named anywhere fails"
  clean; echo 'Dispatch @y-reviewer over ai/x.md.' >> "$TD/templates/packs/aa/commands/c.md"; expect 1 "D3: an unguarded cross-pack @agent fails"
  clean; echo 'Dispatch @y-reviewer over ai/x.md (when the bb pack is installed).' >> "$TD/templates/packs/aa/commands/c.md"; expect 0 "D3: the guarded form passes"
  clean; printf 'lens\n' > "$TD/templates/packs/aa/lenses/l2.md"; expect 1 "D5: a lens no agent's block names fails"; rm "$TD/templates/packs/aa/lenses/l2.md"
  clean; printf '{"reviewer":"ghost-reviewer","lens":"lenses/dd-review.md"}\n' > "$TD/templates/domains/dd/_version.json"; expect 1 "D5: a domain reviewer that does not exist fails"
  [ "$fails" -eq 0 ] && { echo "self-test: all cases pass"; exit 0; }
  echo "self-test: $fails case(s) failed"; exit 1
fi

ROOT="$ROOT" MODE="$MODE" LIST="$LIST" JSON="$JSON" QUIET="$QUIET" python3 - <<'PY'
import os, re, sys, glob, json, collections

ROOT = os.environ["ROOT"]; MODE = os.environ["MODE"]; QUIET = os.environ["QUIET"] == "1"
LIST = [x for x in os.environ["LIST"].split(",") if x]; JSON = os.environ["JSON"] == "1"
os.chdir(ROOT)
ALWAYS_ON = {"delivery", "repo-baseline", "security", "code-quality", "business", "learning",
             "documentation", "testing"}
SUFFIX = re.compile(r"-(reviewer|auditor|architect|engineer|designer|analyst|critic|investigator|writer)$")

def rd(p):
    try: return open(p, encoding="utf-8", errors="replace").read()
    except OSError: return ""

def fm_name(p):
    m = re.search(r"\A---\n(.*?)\n---", rd(p), re.S)
    if m:
        n = re.search(r"^name:\s*['\"]?([A-Za-z0-9_.-]+)", m.group(1), re.M)
        if n: return n.group(1)
    return None

def home(p):
    parts = p.split("/")
    if parts[:2] == ["templates", "packs"] and len(parts) > 2: return parts[2]
    if parts[:2] == ["templates", "domains"] and len(parts) > 2: return "domain:" + parts[2]
    if parts[:2] == ["templates", "repo-baseline"]: return "repo-baseline"
    if parts[:2] == ["templates", "workspace-baseline"]: return "workspace-baseline"
    if parts[0] == "commands": return "global"
    return "other"

# ---------------------------------------------------------------- catalog
agents = collections.defaultdict(set)      # name -> {home}
for p in (glob.glob("templates/packs/*/agents/*.md") + glob.glob("templates/domains/*/agents/*.md")
          + glob.glob("templates/repo-baseline/.claude/agents/*.md")
          + glob.glob("templates/workspace-baseline/.claude/agents/*.md")):
    agents[fm_name(p) or os.path.basename(p)[:-3]].add(home(p))
commands = set(os.path.basename(p)[:-3] for p in
               glob.glob("commands/*.md") + glob.glob("templates/packs/*/commands/*.md")
               + glob.glob("templates/domains/*/commands/*.md")
               + glob.glob("templates/*-baseline/.claude/commands/*.md"))
skills = set()
for p in glob.glob("templates/packs/*/skills/*/SKILL.md") + glob.glob("templates/*-baseline/.claude/skills/*/SKILL.md"):
    skills.add(os.path.basename(os.path.dirname(p))); n = fm_name(p)
    if n: skills.add(n)
lens_files = {}                            # basename -> source path
for p in glob.glob("templates/packs/*/lenses/*.md") + glob.glob("templates/domains/*/lenses/*.md"):
    lens_files.setdefault(os.path.basename(p), []).append(p)
builtins = set(l.strip() for l in rd("scripts/_harness-builtins.txt").splitlines()
               if l.strip() and not l.startswith("#"))
try: mm = json.load(open("scripts/_agent-merge-map.json", encoding="utf-8"))
except (OSError, ValueError): mm = {"agents": []}
retired = sorted(set(e["old_name"] for e in mm.get("agents", [])
                     if e.get("status") == "merged" and e["old_name"] not in agents))

# ---------------------------------------------------------------- corpus
corpus = []
for base in ("templates", "commands", "docs"):
    for d, ds, fs in os.walk(base):
        ds[:] = [x for x in ds if x not in ("node_modules", ".git")]
        for f in fs:
            if f == "CHANGELOG.md" or not f.endswith((".md", ".json", ".yml", ".yaml", ".txt")): continue
            corpus.append(os.path.join(d, f))
for f in ("README.md", "CONTRIBUTING.md", "skills.sh.json"):
    if os.path.isfile(f): corpus.append(f)
corpus = sorted(c for c in corpus if c != "scripts/_agent-merge-map.json")

hits = collections.defaultdict(list)       # check -> [(src, line, target, note)]
AT = re.compile(r"(?<![\w.@/-])@([a-z][a-z0-9]*(?:-[a-z0-9]+)+)\b(?![-\w])")
LENS = re.compile(r"lenses/([A-Za-z0-9_.-]+\.md)")
RET = re.compile(r"(?<![\w-])(" + "|".join(re.escape(r) for r in retired) + r")(?![\w-])") if retired else None
GUARD_GENERIC = re.compile(r"installed|UNROUTED|not installed", re.I)
PATHISH = re.compile(r"(ai/|\.claude/|[\w.-]+/[\w./{}*-]+\.(md|json|ya?ml)|\.schema\.json|\{run_id\})")

def paragraphs(lines):
    """Map line index -> (start, end) of its paragraph (blank-line separated; a table row is its own unit)."""
    spans, i, n = {}, 0, len(lines)
    while i < n:
        if lines[i].lstrip().startswith("|"):
            spans[i] = (i, i); i += 1; continue
        j = i
        while j < n and lines[j].strip() and not lines[j].lstrip().startswith("|"): j += 1
        for k in range(i, max(j, i + 1)): spans[k] = (i, max(j - 1, i))
        i = max(j, i + 1)
    return spans

for src in corpus:
    text = rd(src); lines = text.split("\n"); sp = None
    shome = home(src)
    is_agent_file = "/agents/" in src and src.endswith(".md")
    # templates/tool-adapters/ show how a tool loads "an agent" with an illustrative persona name
    # (`backend-reviewer`), the same one in every adapter. Not a dispatch; a retired name is still D2.
    illustrative = src.startswith("templates/tool-adapters/")
    for i, line in enumerate(lines):
        if RET:
            for m in RET.finditer(line):
                hits["D2"].append((src, i + 1, m.group(1), "retired agent named"))
        if illustrative: continue                             # adapter docs: example personas, D2 only
        for m in AT.finditer(line):
            name = m.group(1)
            looks = name in agents or name in retired or SUFFIX.search(name)
            if not looks: continue
            if name not in agents and name not in retired:
                hits["D1"].append((src, i + 1, "@" + name, "no agent ships this name")); continue
            if name in retired: continue                      # D2 already counted it
            homes = agents[name]
            if shome in homes or homes & ALWAYS_ON: pass
            elif shome in ("other",): pass
            else:
                if sp is None: sp = paragraphs(lines)
                a, b = sp.get(i, (i, i)); para = "\n".join(lines[a:b + 1])
                guarded = bool(GUARD_GENERIC.search(para)) or any(
                    re.search(r"\(%s pack|%s pack\)|%s pack" % ((re.escape(h),) * 3), para)
                    for h in homes)
                if not guarded:
                    hits["D3"].append((src, i + 1, "@" + name, "→ %s, no install guard" % ",".join(sorted(homes))))
            if re.search(r"dispatch", line, re.I) and not PATHISH.search(line) and not is_agent_file:
                hits["D4"].append((src, i + 1, "@" + name, "dispatch names no artifact"))
        for m in LENS.finditer(line):
            if m.group(1) not in lens_files and "<" not in m.group(1):
                hits["D1"].append((src, i + 1, "lenses/" + m.group(1), "no lens file ships this name"))

# ---------------------------------------------------------------- D5 lenses
BLOCK = re.compile(r"<!-- BEGIN GENERATED lenses.*?-->(.*?)<!-- END GENERATED lenses -->", re.S)
primary = collections.defaultdict(list)
for p in (glob.glob("templates/packs/*/agents/*.md") + glob.glob("templates/repo-baseline/.claude/agents/*.md")):
    for blk in BLOCK.findall(rd(p)):
        for row in blk.split("\n"):
            m = re.search(r"`\.claude/lenses/([A-Za-z0-9_.-]+\.md)`", row)
            if m and "fallback" not in row.lower():
                primary[m.group(1)].append(p)
# A lens a merge-map entry names while that entry is NOT `merged` is STAGED: written ahead of an
# unearned merge (the specialist agent still ships and is the reader). It must have NO primary reader
# yet; it gets exactly one the change that marks the entry merged.
staged = set(os.path.basename(e.get("lens") or "") for e in mm.get("agents", [])
             if e.get("lens") and e.get("status") != "merged")
for lens, srcs in sorted(lens_files.items()):
    if lens in staged:
        if primary.get(lens):
            hits["D5"].append((srcs[0], 1, lens, "staged lens (merge-map entry not merged) is already named as primary by %s" % ", ".join(primary[lens])))
        continue
    if len(srcs) > 1:
        hits["D5"].append((srcs[1], 1, lens, "two lens files share this name: " + ", ".join(srcs)))
    n = len(primary.get(lens, []))
    if n != 1:
        hits["D5"].append((srcs[0], 1, lens, "named as primary by %d agents' generated Lenses blocks (want 1)" % n))
for vj in sorted(glob.glob("templates/domains/*/_version.json")):
    try: v = json.load(open(vj, encoding="utf-8"))
    except (OSError, ValueError): continue
    d = os.path.basename(os.path.dirname(vj))
    for k in ("reviewer", "fallback"):
        if v.get(k) and v[k] not in agents:
            hits["D5"].append((vj, 1, v[k], "domain %s `%s` is no catalog agent" % (d, k)))
    if v.get("lens") and not os.path.isfile(os.path.join(os.path.dirname(vj), v["lens"])):
        hits["D5"].append((vj, 1, v["lens"], "domain %s lens path does not resolve" % d))
    if glob.glob(os.path.join(os.path.dirname(vj), "lenses", "*.md")) and not v.get("reviewer"):
        hits["D5"].append((vj, 1, d, "domain ships a lens but declares no `reviewer`"))

# ---------------------------------------------------------------- report / ratchet
CHECKS = ["D1", "D2", "D3", "D4", "D5"]
counts = {c: len(hits[c]) for c in CHECKS}
BASE = "scripts/_dispatch-graph-baseline.txt"
base = {}
for l in rd(BASE).splitlines():
    l = l.split("#", 1)[0].split()
    if len(l) >= 2 and l[0] in CHECKS: base[l[0]] = int(l[1])
if JSON:
    print(json.dumps({c: [dict(src=s, line=n, target=t, note=x) for s, n, t, x in hits[c]] for c in CHECKS}, indent=1))
    sys.exit(0)
for c in LIST:
    for s, n, t, x in hits.get(c, []):
        print("%s:%d → %s [%s] %s" % (s, n, t, c, x))
if MODE == "record":
    hdr = [l for l in rd(BASE).splitlines() if l.startswith("#")]
    keep = {"D1": 0, "D2": 0, "D5": 0}
    with open(BASE, "w", encoding="utf-8") as fh:
        fh.write("\n".join(hdr) + ("\n" if hdr else ""))
        for c in CHECKS:
            fh.write("%s %d\n" % (c, counts[c] if c not in keep else 0))
    print("recorded: " + " ".join("%s %d" % (c, counts[c]) for c in CHECKS)); sys.exit(0)
bad = [c for c in CHECKS if counts[c] > base.get(c, 0)]
if not QUIET:
    print("dispatch graph — %d agents, %d commands, %d skills, %d lenses, %d retired; corpus %d files"
          % (len(agents), len(commands), len(skills), len(lens_files), len(retired), len(corpus)))
    names = {"D1": "dangling", "D2": "retired", "D3": "unguarded", "D4": "untyped", "D5": "lens"}
    print("  " + "  ".join("%s %s %d/%d" % (c, names[c], counts[c], base.get(c, 0)) for c in CHECKS))
    for c in bad:
        print("\033[31m✗ %s grew: %d > ceiling %d — first hits:\033[0m" % (c, counts[c], base.get(c, 0)))
        for s, n, t, x in hits[c][:12]: print("    %s:%d → %s  %s" % (s, n, t, x))
    for c in CHECKS:
        if counts[c] < base.get(c, 0) and c in ("D3", "D4"):
            print("  note: %s fell %d → %d — lower its line in %s (--record)" % (c, base[c], counts[c], BASE))
if bad: sys.exit(1)
if not QUIET: print("\033[32m✓ dispatch graph within its ratchet\033[0m")
sys.exit(0)
PY
