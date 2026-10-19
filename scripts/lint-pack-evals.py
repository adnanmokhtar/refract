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
    to that fixture's files at the same paths, so a fixture edit cannot leave a stale suite behind.

  python3 scripts/lint-pack-evals.py [--pack=<name>] [--self-test]
Exit 0 clean · 1 a FAIL row. Packs still being built are WARN-only until they ship (PENDING below).
"""
import os
import re
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PENDING = {"finops", "algorithms"}          # batch 8 packs still being built; the integrator removes them on ship
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


def check_case(cdir, pack_dir, rel, errs):
    tags = []
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
            src_root = os.path.join(ROOT, "benchmarks", "fixtures", fx.group(1))
            res = os.path.join(cdir, "resources")
            if not os.path.isdir(src_root):
                errs.append("%s/case.yaml: fixture %s does not exist" % (rel, fx.group(1)))
            for dp, _, fs in os.walk(res):
                for f in fs:
                    p = os.path.join(dp, f)
                    r = os.path.relpath(p, res)
                    s = os.path.join(src_root, r)
                    if not os.path.isfile(s) or open(s, "rb").read() != open(p, "rb").read():
                        errs.append("%s/resources/%s: differs from benchmarks/fixtures/%s/%s — re-copy it and re-check "
                                    "the graders' lines" % (rel, r, fx.group(1), r))
    if not has_prompt:
        errs.append("%s: no prompt (prompt.md body or case.yaml execution.prompt)" % rel)
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
