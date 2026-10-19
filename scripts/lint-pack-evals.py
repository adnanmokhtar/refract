#!/usr/bin/env python3
"""lint-pack-evals.py — every pack ships an `evals/` suite that `claude plugin eval` can load.

Spec § 8.8: each pack carries should-trigger / should-NOT-trigger cases and an outcome case built
from its fixture, run with and without the pack (.github/workflows/refract-evals.yml). This lint is
the offline half: it never calls a model. It checks the suite against the case format documented at
code.claude.com/docs/en/plugin-evals (fetched 2026-10-19, Claude Code >= 2.1.269):

  * a case is a directory holding prompt.md and/or case.yaml, with >= 1 grader (graders/*.md or a
    case.yaml `graders:` list) — "a case without one fails to load";
  * prompt.md frontmatter keys are the documented set ("an unknown key is an error"); runs 1–50,
    max_turns <= 200, timeout_seconds <= 3600; the body (the prompt) is not empty;
  * case.yaml carries schema_version "1.1" and name; context.add_dirs name directories inside the case;
  * a grader's type is one of regex · tool_used · tool_order · file_exists · llm · baseline, with only
    that type's options plus weight / arm; regex patterns compile (Python's engine — a close
    approximation of the JavaScript one the runner uses; inline `(?i)` is refused, as the docs say).
Refract's own rules on top:
  * allowed_tools stay in the read-only set, so CI needs no --allow-tools grant;
  * each suite has >= 1 case tagged `outcome` and >= 1 tagged `negative`;
  * a `tool_used: Skill` input_match names only skills / commands that exist in the pack;
  * a case.yaml carrying `# fixture: benchmarks/fixtures/<name>` has resources/ files byte-identical
    to that fixture's files at the same paths (one file or a multi-file slice), so a fixture edit cannot
    leave a stale suite behind; resources/ never holds the answer key (DEFECTS.md);
  * `# seed: <id> [<file>:<line>] [-> graders/<g>.md]` and `# decoy: …` comment lines name ids the
    fixture's DEFECTS.md defines, of the right kind (```defect / ```decoy), at its current file:line, and
    any grader they name exists with the right shape (seed: regex · decoy: regex match: not_contains);
  * a HARD case (`audit-<fixture>-slice`, or tagged `hard`) — the one that must separate the pack from
    the bare model (Δ > 0) — has 8–25 resources files, >= 4 seed graders and >= 3 decoy graders, each tied
    to a DEFECTS.md id that a case.yaml comment names (the grader's file name, body or the comment line
    naming it carries the id), and a with-only `tool_used: Skill` grader as the pack-fired indicator;
  * a COMMAND-LANE case (`cmd-<fixture>-slice`) is its sibling hard case (`audit-<fixture>-slice`, or
    `spec-<fixture>-slice` for a build key) run through the pack's own command: the prompt opens with
    `/refract-<pack>:<command>` naming a command the pack ships, with no write / fix mode flag; resources/ and
    every grader are byte-identical to the sibling's, except that the sibling's with-only `tool_used: Skill`
    indicator is dropped (the command IS the pack, and the lane runs with --ablation none). It gets the
    sibling's slice checks, without the pack-fired requirement.

  python3 scripts/lint-pack-evals.py [--pack=<name>] [--self-test]
Exit 0 clean · 1 a FAIL row. Packs still being built are WARN-only until they ship (PENDING below).
"""
import os
import re
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PENDING = set()     # packs still being built: WARN-only until they ship (finops and algorithms shipped 2026-10-19)
FIXTURES = os.path.join(ROOT, "benchmarks", "fixtures")   # the self-test points it at a scratch fixture
HARD_FILES = (8, 25)          # a hard slice: enough files that the seeds are cross-file, few enough to read
HARD_SEEDS, HARD_DECOYS = 4, 3
WRITE_MODES = ("--from-audit", "--fix", "--apply", "--write", "--yes", "--tier", "--build")   # never in a cmd-* prompt
PROMPT_KEYS = {"schema_version", "name", "description", "tags", "plugins", "runs", "expected_outcome", "model",
               "max_turns", "timeout_seconds", "allowed_tools", "append_system_prompt", "env"}
CASE_KEYS = {"schema_version", "name", "description", "tags", "plugins", "runs", "expected_outcome", "execution",
             "context", "graders"}
CONTEXT_KEYS = {"scaffold_script", "history_file", "add_dirs"}
READ_ONLY = {"Read", "Glob", "Grep", "NotebookRead", "Skill", "AskUserQuestion", "Agent", "TodoWrite", "TaskCreate",
             "TaskGet", "TaskList", "TaskUpdate", "TaskStop"}
COMMON = {"type", "weight", "arm", "name"}
GRADERS = {"regex": {"pattern", "flags", "match", "target"}, "tool_used": {"tool", "input_match", "min", "max"},
           "tool_order": {"before", "after"}, "file_exists": {"path", "exists"}, "llm": {"criteria", "focus"},
           "baseline": {"baseline_file", "criteria"}}
TARGETS = {"last_message", "trace", "files", "mock_calls"}


# ── a small YAML reader: the subset eval suites use (scalars, quoted strings, flow lists, one nested map) ──
def scalar(v):
    v = v.strip()
    if not v:
        return None
    if v[0] == "'" and v[-1] == "'" and len(v) >= 2:
        return v[1:-1].replace("''", "'")
    if v[0] == '"' and v[-1] == '"' and len(v) >= 2:
        return bytes(v[1:-1], "utf-8").decode("unicode_escape")
    if v[0] == "[" and v[-1] == "]":
        inner = v[1:-1].strip()
        return [scalar(x) for x in re.findall(r"""'(?:[^']|'')*'|"(?:[^"\\]|\\.)*"|[^,]+""", inner)] if inner else []
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if re.fullmatch(r"-?\d+\.\d+", v):
        return float(v)
    if v in ("true", "false"):
        return v == "true"
    return v


def parse_yaml(text):
    """-> (dict, error). Top-level `key: value`, and `key:` followed by 2-space-indented `sub: value`."""
    out, cur = {}, None
    for n, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^( *)([A-Za-z_][\w-]*):(?:\s+(.*))?$", line)
        if not m:
            return None, "line %d does not parse: %r" % (n, line[:60])
        ind, key, val = len(m.group(1)), m.group(2), m.group(3)
        if ind == 0:
            if val is None or val.strip() == "":
                out[key], cur = {}, key
            else:
                out[key], cur = scalar(val), None
        elif ind == 2 and cur is not None:
            out[cur][key] = scalar(val or "")
        else:
            return None, "line %d: unexpected indentation" % n
    return out, None


def frontmatter(path):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    if not m:
        return None, text, "no frontmatter block"
    fm, err = parse_yaml(m.group(1))
    return fm, m.group(2), err


def pack_names(pack_dir):
    names = set()
    sd = os.path.join(pack_dir, "skills")
    for s in os.listdir(sd) if os.path.isdir(sd) else []:
        if os.path.isfile(os.path.join(sd, s, "SKILL.md")):
            names.add(s)
    cd = os.path.join(pack_dir, "commands")
    for c in os.listdir(cd) if os.path.isdir(cd) else []:
        if c.endswith(".md"):
            names.add(c[:-3])
    return names


def js_compile(pattern, where, errs):
    if "(?i)" in pattern:
        errs.append("%s: inline (?i) is not supported by the runner — use flags: i" % where)
    try:
        return re.compile(pattern)
    except re.error as e:
        errs.append("%s: regex does not compile: %s" % (where, e))
        return None


def check_grader(fm, where, pack_dir, errs):
    t = fm.get("type")
    if t not in GRADERS:
        errs.append("%s: type %r is not a grader type (%s)" % (where, t, ", ".join(sorted(GRADERS))))
        return
    extra = set(fm) - COMMON - GRADERS[t]
    if extra:
        errs.append("%s: %s takes no %s" % (where, t, ", ".join(sorted(extra))))
    if fm.get("arm") not in (None, "with-only", "both"):
        errs.append("%s: arm must be with-only or both" % where)
    if t == "regex":
        if not fm.get("pattern"):
            errs.append("%s: regex grader needs pattern" % where)
        else:
            js_compile(str(fm["pattern"]), where, errs)
        mt = fm.get("match")
        if mt not in (None, "contains", "not_contains") and not re.fullmatch(r"count:\d+", str(mt)):
            errs.append("%s: match must be not_contains or count:N" % where)
        tg = fm.get("target")
        if tg is not None and tg not in TARGETS and not isinstance(tg, dict):
            errs.append("%s: target %r is not one of %s" % (where, tg, ", ".join(sorted(TARGETS))))
    elif t == "tool_used":
        if not fm.get("tool"):
            errs.append("%s: tool_used grader needs tool" % where)
        im = fm.get("input_match")
        if im:
            js_compile(str(im), where, errs)
            if fm.get("tool") == "Skill":
                m = re.search(r"\(\?:([A-Za-z0-9|-]+)\)\"$", str(im))
                if not m:
                    errs.append("%s: a Skill input_match ends with (?:name|…)\" naming the pack's skills" % where)
                else:
                    have = pack_names(pack_dir)
                    gone = [n for n in m.group(1).split("|") if n not in have]
                    if gone:
                        errs.append("%s: input_match names %s, which the pack no longer ships" % (where, ", ".join(gone)))
        for k in ("min", "max"):
            if k in fm and not isinstance(fm[k], int):
                errs.append("%s: %s must be an integer" % (where, k))


def fixture_key(src_root):
    """{id: {kind, file, line}} from the fixture's DEFECTS.md ```defect / ```decoy blocks ({} when absent)."""
    path = os.path.join(src_root, "DEFECTS.md")
    out = {}
    if not os.path.isfile(path):
        return out
    for kind, body in re.findall(r"```(defect|decoy)\n(.*?)```", open(path, encoding="utf-8").read(), re.S):
        f = dict(re.findall(r"^(id|file|line):[ \t]*(\S+)", body, re.M))
        if f.get("id"):
            out[f["id"]] = {"kind": kind, "file": f.get("file", ""), "line": f.get("line", "")}
    return out


def _norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def check_seeds(cdir, rel, text, src_root, res, hard, errs, cmd=False):
    """Seed / decoy comment lines and graders against the fixture's answer key; the HARD-case shape."""
    key = fixture_key(src_root)
    comments = [l for l in text.splitlines() if l.lstrip().startswith("#")]
    named = {}                                   # id -> kind word of the comment line (seed / decoy / other)
    by_grader = {}                               # grader stem -> ids on the comment line naming it
    declared = set()                             # graders a non-seed, non-decoy line declares (`# key: … -> graders/g.md`)
    for l in comments:
        ids = [i for i in key if re.search(r"(?<![\w-])%s(?![\w-])" % re.escape(i), l)]
        m = re.match(r"^\s*#\s*(seed|decoy)\s*:\s*(\S+)", l, re.I)
        word = m.group(1).lower() if m else "other"
        for i in ids:
            named.setdefault(i, word)
        for g in re.findall(r"graders/([\w.-]+)\.md\b", l):
            by_grader.setdefault(g, []).extend(ids)
            if not m:
                declared.add(g)
        if not m:
            continue
        cid = m.group(2)
        if cid not in key:
            errs.append("%s/case.yaml: `# %s: %s` — benchmarks/fixtures/%s/DEFECTS.md defines no such id"
                        % (rel, word, cid, os.path.basename(src_root)))
            continue
        want = "defect" if word == "seed" else "decoy"
        if key[cid]["kind"] != want:
            errs.append("%s/case.yaml: %s is a ```%s block, not a %s" % (rel, cid, key[cid]["kind"], word))
        fl = re.search(r"(\S+?):(\d+)\b", l[m.end():].split("->")[0])
        if fl and (fl.group(1).lstrip("(["), fl.group(2)) != (key[cid]["file"], key[cid]["line"]):
            errs.append("%s/case.yaml: %s is at %s:%s in DEFECTS.md, the comment says %s:%s — re-check the slice"
                        % (rel, cid, key[cid]["file"], key[cid]["line"], fl.group(1), fl.group(2)))
        if key[cid]["file"] and not os.path.isfile(os.path.join(res, key[cid]["file"])):
            errs.append("%s/case.yaml: %s sits in %s, which resources/ does not hold" % (rel, cid, key[cid]["file"]))
        for g in re.findall(r"graders/([\w.-]+)\.md\b", l[m.end():]):
            gp = os.path.join(cdir, "graders", g + ".md")
            if not os.path.isfile(gp):
                errs.append("%s/case.yaml: %s names graders/%s.md, which does not exist" % (rel, cid, g))
                continue
            fm, _, _ = frontmatter(gp)
            fm = fm or {}
            neg = fm.get("match") == "not_contains"
            if fm.get("type") != "regex" or neg != (word == "decoy"):
                errs.append("%s/graders/%s.md: a %s grader is a regex%s" % (rel, g, word, " with match: not_contains" if word == "decoy" else " that must match"))
    if not hard:
        return
    nres = sum(len(fs) for _, _, fs in os.walk(res))
    if not HARD_FILES[0] <= nres <= HARD_FILES[1]:
        errs.append("%s: a hard slice holds %d–%d resources files, this one %d" % (rel, HARD_FILES[0], HARD_FILES[1], nres))
    seeds = decoys = fired = 0
    gd = os.path.join(cdir, "graders")
    for g in sorted(os.listdir(gd)) if os.path.isdir(gd) else []:
        if not g.endswith(".md"):
            continue
        fm, body, err = frontmatter(os.path.join(gd, g))
        if err or not fm:
            continue
        stem = g[:-3]
        if fm.get("type") == "tool_used" and fm.get("tool") == "Skill" and fm.get("arm") != "both" \
                and (fm.get("min") is None or (isinstance(fm.get("min"), int) and fm["min"] >= 1)):
            fired += 1
            continue
        if fm.get("type") != "regex":
            continue
        decoy = fm.get("match") == "not_contains"
        want = "decoy" if decoy else "defect"
        tied = set(by_grader.get(stem, []))
        tied |= {i for i in key if _norm(i) in _norm(stem)}
        tied |= {i for i in key if re.search(r"(?<![\w-])%s(?![\w-])" % re.escape(i), body or "")}
        ok = [i for i in tied if i in named and key[i]["kind"] == want]
        if not ok and stem in declared:
            continue                             # a declared extra check (an outcome key's gate), not a seed or a decoy
        if not ok:
            errs.append("%s/graders/%s: a %s grader must be tied to a ```%s id of DEFECTS.md that a case.yaml comment "
                        "names (# %s: <id> … -> graders/%s)" % (rel, g, "decoy" if decoy else "seed", want,
                                                                 "decoy" if decoy else "seed", g))
            continue
        if decoy:
            decoys += 1
        else:
            seeds += 1
    if seeds < HARD_SEEDS:
        errs.append("%s: a hard slice grades >= %d seeds (one regex grader per DEFECTS.md defect), this one %d" % (rel, HARD_SEEDS, seeds))
    if decoys < HARD_DECOYS and sum(1 for v in key.values() if v["kind"] == "decoy") >= HARD_DECOYS:
        errs.append("%s: a hard slice spares >= %d decoys (one regex not_contains grader per DEFECTS.md decoy), this one %d"
                    % (rel, HARD_DECOYS, decoys))
    if not fired and not cmd:
        errs.append("%s: a hard slice carries a with-only `tool_used: Skill` grader (min >= 1) — the pack-fired indicator" % rel)


def _tree(root):
    out = {}
    for dp, _, fs in os.walk(root):
        for f in fs:
            p = os.path.join(dp, f)
            out[os.path.relpath(p, root)] = open(p, "rb").read()
    return out


def _is_indicator(path):
    fm, _, err = frontmatter(path)
    return not err and bool(fm) and fm.get("type") == "tool_used" and fm.get("tool") == "Skill" and fm.get("arm") == "with-only"


def check_cmd(cdir, pack_dir, rel, body, errs):
    """A cmd-<fixture>-slice case: its sibling hard case run through the pack's command (see the docstring)."""
    stem = os.path.basename(cdir)[len("cmd-"):]
    sib = next((os.path.join(os.path.dirname(cdir), k + stem) for k in ("audit-", "spec-")
                if os.path.isdir(os.path.join(os.path.dirname(cdir), k + stem))), None)
    pack = os.path.basename(pack_dir)
    m = re.match(r"\s*/refract-([a-z0-9-]+):([a-z0-9-]+)[ \t]+(.*)", body or "")
    if not m:
        errs.append("%s/prompt.md: a command-lane prompt opens with `/refract-%s:<command> ` and then the ask" % (rel, pack))
    else:
        if m.group(1) != pack:
            errs.append("%s/prompt.md: names /refract-%s, but the case lives in the %s pack" % (rel, m.group(1), pack))
        if not os.path.isfile(os.path.join(pack_dir, "commands", m.group(2) + ".md")):
            errs.append("%s/prompt.md: /refract-%s:%s — the pack ships no commands/%s.md" % (rel, pack, m.group(2), m.group(2)))
        bad = [w for w in m.group(3).split() if w.startswith("--") and w.split("=", 1)[0] in WRITE_MODES]
        if bad:
            errs.append("%s/prompt.md: %s is a write / fix mode — the command lane stays read-only" % (rel, " ".join(bad)))
    if not sib:
        errs.append("%s: a command-lane case has a sibling hard case (audit-%s or spec-%s) — none found" % (rel, stem, stem))
        return None
    if _tree(os.path.join(cdir, "resources")) != _tree(os.path.join(sib, "resources")):
        errs.append("%s/resources: differs from %s/resources — the command lane runs the same slice"
                    % (rel, os.path.basename(sib)))
    gd, sd = os.path.join(cdir, "graders"), os.path.join(sib, "graders")
    mine = _tree(gd) if os.path.isdir(gd) else {}
    theirs = {k: v for k, v in (_tree(sd) if os.path.isdir(sd) else {}).items() if not _is_indicator(os.path.join(sd, k))}
    for k in sorted(set(mine) | set(theirs)):
        if mine.get(k) != theirs.get(k):
            what = "missing" if k not in mine else "extra" if k not in theirs else "differs"
            errs.append("%s/graders/%s: %s against %s (the command lane keeps the sibling's graders, minus pack-fired)"
                        % (rel, k, what, os.path.basename(sib)))
    return sib


def check_case(cdir, pack_dir, rel, errs):
    tags = []
    body = ""
    cmd = bool(re.fullmatch(r"cmd-[a-z0-9-]+-slice", os.path.basename(cdir)))
    pm, cy = os.path.join(cdir, "prompt.md"), os.path.join(cdir, "case.yaml")
    has_prompt = False
    graders = 0
    if os.path.isfile(pm):
        fm, body, err = frontmatter(pm)
        if err and fm is None and "no frontmatter" not in err:
            errs.append("%s/prompt.md: %s" % (rel, err))
        fm = fm or {}
        unknown = set(fm) - PROMPT_KEYS
        if unknown:
            errs.append("%s/prompt.md: unknown frontmatter key(s) %s — the runner refuses them" % (rel, ", ".join(sorted(unknown))))
        if not body.strip():
            errs.append("%s/prompt.md: the body (the prompt) is empty" % rel)
        has_prompt = bool(body.strip())
        body = body or ""
        for k, lo, hi in (("runs", 1, 50), ("max_turns", 1, 200), ("timeout_seconds", 1, 3600)):
            if k in fm and not (isinstance(fm[k], int) and lo <= fm[k] <= hi):
                errs.append("%s/prompt.md: %s must be an integer in %d..%d" % (rel, k, lo, hi))
        tools = fm.get("allowed_tools") or []
        if not isinstance(tools, list):
            errs.append("%s/prompt.md: allowed_tools must be a list" % rel)
        else:
            gated = [x for x in tools if x not in READ_ONLY]
            if gated:
                errs.append("%s/prompt.md: %s need an --allow-tools grant; Refract suites stay read-only" % (rel, ", ".join(gated)))
        tags = fm.get("tags") or []
        if fm.get("env") and any(not re.fullmatch(r"EVAL_[A-Z0-9_]*", k) for k in fm["env"]):
            errs.append("%s/prompt.md: env keys must match EVAL_[A-Z0-9_]*" % rel)
    if os.path.isfile(cy):
        text = open(cy, encoding="utf-8").read()
        y, err = parse_yaml(text)
        if err:
            errs.append("%s/case.yaml: %s" % (rel, err))
            y = {}
        if str(y.get("schema_version")) != "1.1":
            errs.append('%s/case.yaml: schema_version must be "1.1"' % rel)
        if not y.get("name"):
            errs.append("%s/case.yaml: name is required" % rel)
        unknown = set(y) - CASE_KEYS
        if unknown:
            errs.append("%s/case.yaml: unknown key(s) %s" % (rel, ", ".join(sorted(unknown))))
        ctx = y.get("context") or {}
        if set(ctx) - CONTEXT_KEYS:
            errs.append("%s/case.yaml: unknown context key(s) %s" % (rel, ", ".join(sorted(set(ctx) - CONTEXT_KEYS))))
        for d in ctx.get("add_dirs") or []:
            if ".." in str(d) or os.path.isabs(str(d)) or not os.path.isdir(os.path.join(cdir, str(d))):
                errs.append("%s/case.yaml: add_dirs %r is not a directory inside the case" % (rel, d))
        if isinstance(y.get("execution"), dict) and y["execution"].get("prompt"):
            has_prompt = True
        tags = tags or y.get("tags") or []
        fx = re.search(r"^# fixture: benchmarks/fixtures/([A-Za-z0-9_.-]+)", text, re.M)
        if fx:
            src_root = os.path.join(FIXTURES, fx.group(1))
            res = os.path.join(cdir, "resources")
            if not os.path.isdir(src_root):
                errs.append("%s/case.yaml: fixture %s does not exist" % (rel, fx.group(1)))
            for dp, _, fs in os.walk(res):
                for f in fs:
                    p = os.path.join(dp, f)
                    r = os.path.relpath(p, res)
                    s = os.path.join(src_root, r)
                    if f == "DEFECTS.md":
                        errs.append("%s/resources/%s: the fixture's answer key is in the agent's workspace — every run "
                                    "would read it and score 1.0" % (rel, r))
                    elif not os.path.isfile(s) or open(s, "rb").read() != open(p, "rb").read():
                        errs.append("%s/resources/%s: differs from benchmarks/fixtures/%s/%s — re-copy it and re-check "
                                    "the graders' lines" % (rel, r, fx.group(1), r))
            hard = bool(re.fullmatch(r"audit-[a-z0-9-]+-slice", os.path.basename(cdir))) or "hard" in (tags or y.get("tags") or [])
            check_seeds(cdir, rel, text, src_root, res, hard, errs, cmd)
        elif re.fullmatch(r"(?:audit|cmd)-[a-z0-9-]+-slice", os.path.basename(cdir)):
            errs.append("%s/case.yaml: a hard slice case names its fixture (`# fixture: benchmarks/fixtures/<name>`)" % rel)
    if not has_prompt:
        errs.append("%s: no prompt (prompt.md body or case.yaml execution.prompt)" % rel)
    if cmd:
        check_cmd(cdir, pack_dir, rel, body, errs)
    gd = os.path.join(cdir, "graders")
    for g in sorted(os.listdir(gd)) if os.path.isdir(gd) else []:
        if not g.endswith(".md"):
            continue
        fm, body, err = frontmatter(os.path.join(gd, g))
        where = "%s/graders/%s" % (rel, g)
        if err:
            errs.append("%s: %s" % (where, err))
            continue
        check_grader(fm, where, pack_dir, errs)
        if fm.get("type") == "llm" and not body.strip() and not fm.get("criteria"):
            errs.append("%s: an llm grader's body is its rubric — it is empty" % where)
        graders += 1
    if graders == 0:
        errs.append("%s: no grader — the runner refuses a case without one" % rel)
    return tags


def lint_pack(pack_dir, errs, warns):
    name = os.path.basename(pack_dir)
    ev = os.path.join(pack_dir, "evals")
    if not os.path.isdir(ev):
        (warns if name in PENDING else errs).append("%s: no evals/ suite%s" % (name, " (pack still being built)" if name in PENDING else ""))
        return 0
    cases, tags = 0, set()
    for dp, dns, fns in os.walk(ev):
        base = os.path.basename(dp)
        if base in ("results", "mocks") and dp != ev:
            dns[:] = []
            continue
        if "prompt.md" in fns or "case.yaml" in fns:
            dns[:] = []
            rel = os.path.relpath(dp, os.path.dirname(pack_dir))
            tags.update(check_case(dp, pack_dir, rel, errs))
            cases += 1
    if cases == 0:
        errs.append("%s/evals: no case (a directory holding prompt.md or case.yaml)" % name)
    for want in ("outcome", "negative"):
        if cases and want not in tags:
            errs.append("%s/evals: no case tagged `%s` (spec § 8.8: should-trigger outcome and should-NOT-trigger)" % (name, want))
    return cases


def run(packs_root, only=None):
    errs, warns, n_cases, n_packs = [], [], 0, 0
    for p in sorted(os.listdir(packs_root)):
        d = os.path.join(packs_root, p)
        if p.startswith("_") or not os.path.isdir(d) or (only and p != only):
            continue
        n_packs += 1
        n_cases += lint_pack(d, errs, warns)
    return errs, warns, n_packs, n_cases


def self_test_hard(tmp, pk, skill):
    """The hard-slice rules, on a scratch fixture with a 4-defect / 3-decoy answer key."""
    global FIXTURES
    fails, saved = [], FIXTURES
    FIXTURES = os.path.join(tmp, "fixtures")
    try:
        fx = os.path.join(FIXTURES, "demo-fx")
        os.makedirs(os.path.join(fx, "src"))
        for n in range(1, 10):
            open(os.path.join(fx, "src", "f%d.ts" % n), "w").write("line\n" * 20)
        key = ["# key\n"]
        for n in range(1, 5):
            key.append("```defect\nid:       DX-%02d\nfile:     src/f%d.ts\nline:     %d\nmatch:    bad\n```\n" % (n, n, n + 2))
        for n in range(1, 4):
            key.append("```decoy\nid:       DX-DECOY-%02d\nfile:     src/f%d.ts\nline:     15\nmatch:    fine\n```\n" % (n, n))
        open(os.path.join(fx, "DEFECTS.md"), "w").write("".join(key))
        evals = os.path.join(pk, "evals")
        if os.path.isdir(evals):
            shutil.rmtree(evals)

        def build(mutate=None):
            c = os.path.join(evals, "audit-demo-fx-slice")
            if os.path.isdir(evals):
                shutil.rmtree(evals)
            os.makedirs(os.path.join(c, "graders"))
            shutil.copytree(os.path.join(fx, "src"), os.path.join(c, "resources", "src"))
            cy = ["# fixture: benchmarks/fixtures/demo-fx"]
            g = {"pack-fired": skill + "\nmin: 1\narm: with-only"}
            for n in range(1, 5):
                cy.append("# seed: DX-%02d (src/f%d.ts:%d) -> graders/seed-dx-%02d.md" % (n, n, n + 2, n))
                g["seed-dx-%02d" % n] = "type: regex\npattern: 'f%d\\.ts'\nflags: i" % n
            for n in range(1, 4):
                cy.append("# decoy: DX-DECOY-%02d src/f%d.ts:15 -> graders/decoy-dx-decoy-%02d.md" % (n, n, n))
                g["decoy-dx-decoy-%02d" % n] = "type: regex\npattern: 'f%d\\.ts:15'\nmatch: not_contains" % n
            state = {"cy": cy, "g": g, "prompt": "tags: [outcome]\nallowed_tools: [Read, Skill]", "res": c + "/resources"}
            if mutate:
                mutate(state)
            open(os.path.join(c, "case.yaml"), "w").write("\n".join(state["cy"]) + '\nschema_version: "1.1"\nname: audit-demo-fx-slice\n'
                                                        "context:\n  add_dirs: [resources]\n")
            open(os.path.join(c, "prompt.md"), "w").write("---\n%s\n---\n\nAudit it.\n" % state["prompt"])
            for name, fm in state["g"].items():
                open(os.path.join(c, "graders", name + ".md"), "w").write("---\n%s\n---\n" % fm)
            n = os.path.join(evals, "silent")
            os.makedirs(os.path.join(n, "graders"))
            open(os.path.join(n, "prompt.md"), "w").write("---\ntags: [negative]\n---\n\nUnrelated.\n")
            open(os.path.join(n, "graders", "s.md"), "w").write("---\n%s\nmin: 0\nmax: 0\narm: both\n---\n" % skill)
            return run(os.path.join(tmp, "packs"))[0]

        e = build()
        if e:
            fails.append("good-hard-slice-is-clean: %s" % e)

        def swap(old, new):
            return lambda st: st.update(cy=[l.replace(old, new) for l in st["cy"]])
        cases = [
            ("unknown-seed-id", swap("seed: DX-04", "seed: DX-99"), "defines no such id"),
            ("seed-names-a-decoy", swap("seed: DX-04 (src/f4.ts:6)", "seed: DX-DECOY-03 (src/f3.ts:15)"), "not a seed"),
            ("drifted-seed-line", swap("src/f2.ts:4", "src/f2.ts:9"), "re-check the slice"),
            ("seed-grader-untied", lambda st: st["cy"].remove(st["cy"][1]), "must be tied"),
            ("too-few-seeds", lambda st: (st["cy"].pop(4), st["g"].pop("seed-dx-04")), "grades >= 4 seeds"),
            ("decoy-grader-missing", lambda st: st["g"].pop("decoy-dx-decoy-02"), "does not exist"),
            ("decoy-grader-not-negative", lambda st: st["g"].update({"decoy-dx-decoy-01": "type: regex\npattern: x"}), "not_contains"),
            ("no-pack-fired", lambda st: st["g"].pop("pack-fired"), "pack-fired indicator"),
            ("answer-key-in-resources", lambda st: shutil.copy(os.path.join(fx, "DEFECTS.md"), st["res"]), "answer key"),
            ("slice-too-small", lambda st: [os.remove(os.path.join(st["res"], "src", "f%d.ts" % k)) for k in (5, 6, 7, 8, 9)],
             "hard slice holds"),
        ]
        for name, mutate, want in cases:
            e = build(mutate)
            if not any(want in x for x in e):
                fails.append("%s-is-refused (got: %s)" % (name, e[:2]))

        # the command lane: cmd-<fixture>-slice = the sibling hard case behind /refract-<pack>:<command>
        os.makedirs(os.path.join(pk, "commands"), exist_ok=True)
        open(os.path.join(pk, "commands", "demo-audit.md"), "w").write("---\ndescription: d\n---\n")

        def build_cmd(mutate=None, body="/refract-demo:demo-audit --whole-repo Audit it."):
            build()
            src, c = os.path.join(evals, "audit-demo-fx-slice"), os.path.join(evals, "cmd-demo-fx-slice")
            shutil.copytree(src, c)
            os.remove(os.path.join(c, "graders", "pack-fired.md"))
            cy = open(os.path.join(c, "case.yaml")).read().replace("name: audit-demo-fx-slice", "name: cmd-demo-fx-slice")
            open(os.path.join(c, "case.yaml"), "w").write(cy)
            open(os.path.join(c, "prompt.md"), "w").write("---\ntags: [outcome, hard, command]\nallowed_tools: [Read, Skill]\n"
                                                         "---\n\n%s\n" % body)
            if mutate:
                mutate(c)
            return [x for x in run(os.path.join(tmp, "packs"))[0] if "cmd-demo-fx-slice" in x]
        e = build_cmd()
        if e:
            fails.append("good-command-lane-is-clean: %s" % e)
        cmd_cases = [
            ("cmd-unknown-command", None, "/refract-demo:no-such-audit Audit it.", "ships no commands/no-such-audit.md"),
            ("cmd-other-pack", None, "/refract-other:demo-audit Audit it.", "lives in the demo pack"),
            ("cmd-write-mode", None, "/refract-demo:demo-audit --from-audit=r.md Audit it.", "write / fix mode"),
            ("cmd-bare-ask", None, "Audit it.", "opens with `/refract-demo:<command> `"),
            ("cmd-grader-drift", lambda c: open(os.path.join(c, "graders", "seed-dx-01.md"), "a").write("x\n"),
             None, "differs against audit-demo-fx-slice"),
            ("cmd-grader-missing", lambda c: os.remove(os.path.join(c, "graders", "decoy-dx-decoy-01.md")), None, "missing against"),
            ("cmd-resources-drift", lambda c: os.remove(os.path.join(c, "resources", "src", "f9.ts")), None,
             "the command lane runs the same slice"),
            ("cmd-no-sibling", lambda c: shutil.rmtree(os.path.join(evals, "audit-demo-fx-slice")), None, "sibling hard case"),
        ]
        for name, mutate, body, want in cmd_cases:
            e = build_cmd(mutate, body) if body else build_cmd(mutate)
            if not any(want in x for x in e):
                fails.append("%s-is-refused (got: %s)" % (name, e[:2]))
        shutil.rmtree(os.path.join(pk, "commands"))
        shutil.rmtree(evals)
    finally:
        FIXTURES = saved
    return fails


def self_test():
    tmp = tempfile.mkdtemp(prefix="lint-pack-evals-")
    fails = []
    try:
        pk = os.path.join(tmp, "packs", "demo")
        os.makedirs(os.path.join(pk, "skills", "demo-scan"))
        open(os.path.join(pk, "skills", "demo-scan", "SKILL.md"), "w").write("---\nname: demo-scan\n---\n")

        def case(name, prompt_fm, body, graders):
            c = os.path.join(pk, "evals", name)
            os.makedirs(os.path.join(c, "graders"), exist_ok=True)
            open(os.path.join(c, "prompt.md"), "w").write("---\n%s\n---\n\n%s\n" % (prompt_fm, body))
            for g, fm in graders.items():
                open(os.path.join(c, "graders", g + ".md"), "w").write("---\n%s\n---\n" % fm)
        skill = "type: tool_used\ntool: Skill\ninput_match: '\"skill\"\\s*:\\s*\"(?:[\\w-]+:)?(?:demo-scan)\"'"
        case("finds", "tags: [outcome]\nallowed_tools: [Read, Skill]\nruns: 3", "Find it.",
             {"fired": skill, "names": "type: regex\npattern: 'a\\.ts'\nflags: i"})
        case("silent", "tags: [negative]", "Unrelated.", {"silent": skill + "\nmin: 0\nmax: 0\narm: both"})
        e, w, _, n = run(os.path.join(tmp, "packs"))
        if e or n != 2:
            fails.append("good-suite-is-clean: %s" % e)
        bad = [("unknown-key", "tags: [x]\nbogus: 1", "p", {"g": "type: regex\npattern: a"}, "unknown frontmatter"),
               ("no-grader", "tags: [x]", "p", {}, "no grader"),
               ("bad-type", "tags: [x]", "p", {"g": "type: custom"}, "not a grader type"),
               ("bad-regex", "tags: [x]", "p", {"g": "type: regex\npattern: '(a'"}, "does not compile"),
               ("inline-i", "tags: [x]", "p", {"g": "type: regex\npattern: '(?i)a'"}, "inline (?i)"),
               ("bash", "tags: [x]\nallowed_tools: [Bash]", "p", {"g": "type: regex\npattern: a"}, "allow-tools"),
               ("empty-body", "tags: [x]", "", {"g": "type: regex\npattern: a"}, "body (the prompt) is empty"),
               ("gone-skill", "tags: [x]", "p", {"g": skill.replace("demo-scan", "demo-scan|old-scan")}, "no longer ships"),
               ("wrong-opt", "tags: [x]", "p", {"g": "type: tool_used\ntool: Skill\npattern: a"}, "takes no pattern"),
               ("runs", "tags: [x]\nruns: 99", "p", {"g": "type: regex\npattern: a"}, "runs must be")]
        for name, fm, body, gs, want in bad:
            case(name, fm, body, gs)
            e, _, _, _ = run(os.path.join(tmp, "packs"))
            if not any(want in x and name in x for x in e):
                fails.append("%s-is-refused" % name)
            shutil.rmtree(os.path.join(pk, "evals", name))
        # fixture drift
        fxname = "lint-pack-evals-selftest-fixture"
        fxroot = os.path.join(ROOT, "benchmarks", "fixtures", fxname)
        c = os.path.join(pk, "evals", "finds")
        os.makedirs(os.path.join(c, "resources", "src"))
        open(os.path.join(c, "resources", "src", "a.ts"), "w").write("x\n")
        open(os.path.join(c, "case.yaml"), "w").write("# fixture: benchmarks/fixtures/%s\nschema_version: \"1.1\"\n"
                                                     "name: finds\ncontext:\n  add_dirs: [resources]\n" % fxname)
        e, _, _, _ = run(os.path.join(tmp, "packs"))
        if not any("differs from benchmarks/fixtures" in x for x in e):
            fails.append("fixture-drift-is-refused")
        open(os.path.join(c, "case.yaml"), "w").write("schema_version: \"1.1\"\nname: finds\ncontext:\n  add_dirs: [nope]\n")
        e, _, _, _ = run(os.path.join(tmp, "packs"))
        if not any("add_dirs" in x for x in e):
            fails.append("missing-add-dir-is-refused")
        shutil.rmtree(os.path.join(pk, "evals", "silent"))
        open(os.path.join(c, "case.yaml"), "w").write("schema_version: \"1.1\"\nname: finds\n")
        e, _, _, _ = run(os.path.join(tmp, "packs"))
        if not any("tagged `negative`" in x for x in e):
            fails.append("suite-without-negative-case-is-refused")
        shutil.rmtree(os.path.join(pk, "evals"))
        e, w, _, _ = run(os.path.join(tmp, "packs"))
        if not any("no evals/ suite" in x for x in e):
            fails.append("pack-without-suite-fails")
        fails.extend(self_test_hard(tmp, pk, skill))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        print("FAIL  lint-pack-evals self-test: " + f)
    print("lint-pack-evals self-test: %s (%d failure(s))" % ("PASS" if not fails else "FAIL", len(fails)))
    return 1 if fails else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    only = next((a.split("=", 1)[1] for a in argv if a.startswith("--pack=")), None)
    errs, warns, n_packs, n_cases = run(os.path.join(ROOT, "templates", "packs"), only)
    for w in warns:
        print("WARN  " + w)
    for e in errs:
        print("FAIL  " + e)
    if errs:
        print("lint-pack-evals: %d problem(s) across %d pack(s)" % (len(errs), n_packs))
        return 1
    print("PASS  lint-pack-evals: %d pack(s), %d case(s) load-ready (%d pending pack(s) warned)" % (n_packs, n_cases, len(warns)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
