#!/usr/bin/env python3
"""test-level.py — how much a build run tests on this machine, decided by one word.

Usage:  test-level.py words [--prose] <text…>        → JSON {level, comment, rest, said}
        test-level.py set <level> [--repo=<dir>]     → remember the level for this worktree
        test-level.py get [--repo=<dir>]             → print the level in force (default stage2)
        test-level.py clear [--repo=<dir>]
        test-level.py plan [--level=<l>] [--base=<ref>] [--repo=<dir>]   → JSON plan, runs nothing
        test-level.py run  [--level=<l>] [--base=<ref>] [--repo=<dir>] [--json]
        test-level.py mark [--repo=<dir>]            → put the ready mark on the pushed HEAD commit
Exit:   0  every stage the level runs is green, or the level runs nothing; mark: posted
        1  a stage failed (run); mark: refused (why on stderr) · 2 usage or config error

A copy ships to every project as .claude/scripts/test-level.py (templates/repo-baseline/), so
gate-check.py can read the level without a global install; scripts/test-level.py is the global
copy. The two files must stay byte-identical; tests/test-level/run.sh fails when they differ.

LEVELS. The owner of a run says one word for the whole batch, in Arabic or English:
  (nothing said)      stage2   the tests the change reaches, against <base>. DEFAULT.
  «جاهز» / ready      ready    stage 1 (lint, format, typecheck, build) then stage 2; when both
                               ran green on a committed tree, `mark` puts a commit status on that
                               commit, so CI can skip what already ran here.
  «من غير تيست» / no-test      nothing runs on this machine. Tests are still written.
  «تيست كامل» / full  full     the project's full run. Never chosen unless named.
«من غير كومنت» / no-comment is read in the same pass: the run posts no tracker or PR comment.

WHY. A whole suite on every change is the default most tools fall into, and on a real project it
cost hours a day of one machine and the CI minutes of the rest. The person paying for the run
knows how much proof a batch needs; this lets them say it in one word, and makes the expensive
level something nobody reaches by default.

CONFIG. .claude/testing.json in the project — the commands are the project's, this script only
decides which run and in what order:
  {"stage1": "<routine checks>", "stage2": "<tests the change reaches; <base> is replaced>",
   "full": "<the full run>", "readyStatus": "tested-locally", "base": "origin/main"}
No file → `plan` says configured:false and runs nothing; the calling command keeps its own
behaviour. A level whose stage has no command reports it MISSING and never earns the mark.

THE MARK IS ON THE COMMIT, NOT THE PR. A PR label survives the next push, so the commits that
came after the tested one would ride it into main untested — and a CI job skipped by a label `if:`
reports success. A commit status belongs to one SHA: a new commit has none, and CI tests it. `run`
records the tree it ran on (in the git dir); `mark` posts `state=success, context=<readyStatus>`
through `gh api` only when that record is a green `ready` run on exactly HEAD's tree, the working
tree is clean, and HEAD is on the remote. Costs nothing: no CI minute is spent to post it.

WORDS are read from the END of the text only, so a description that merely contains "ready" in
the middle is not a level. In --prose mode (a build command's free-text request) a bare "full"
is not a level: it ends too many sentences, and the full run must never start by accident.
Flags work anywhere: --test=stage2|ready|no-test|full, --no-comment.

THE LEVEL IN FORCE for a worktree lives in `git rev-parse --git-path refract-test-level` — inside
the git dir, so it is never committed, and each worktree has its own. gate-check.py's G1 reads it.
"""
import json
import os
import re
import subprocess
import sys

LEVELS = ("stage2", "ready", "no-test", "full")
DEFAULT = "stage2"
STAGES = {"stage2": ["stage2"], "ready": ["stage1", "stage2"], "no-test": [], "full": ["full"]}
NAMES = {"stage1": "stage 1", "stage2": "stage 2", "full": "full"}

# (normalised phrase tokens, kind, value, allowed in --prose)
PHRASES = [
    (("من", "غير", "تيست"), "level", "no-test", True), (("من", "غير", "تست"), "level", "no-test", True),
    (("بدون", "تيست"), "level", "no-test", True), (("بدون", "تست"), "level", "no-test", True),
    (("no", "test"), "level", "no-test", True), (("no-test",), "level", "no-test", True),
    (("تيست", "كامل"), "level", "full", True), (("تست", "كامل"), "level", "full", True),
    (("full", "test"), "level", "full", True), (("full-test",), "level", "full", True),
    (("full",), "level", "full", False),
    (("جاهز",), "level", "ready", True), (("ready",), "level", "ready", True),
    (("من", "غير", "كومنت"), "comment", False, True), (("بدون", "كومنت"), "comment", False, True),
    (("no", "comment"), "comment", False, True), (("no-comment",), "comment", False, True),
]
PHRASES.sort(key=lambda p: -len(p[0]))   # longest first: «من غير تيست» before a one-word phrase


def norm(tok):
    tok = tok.strip("«»\"'.,،؛;:!?()").lower()
    return re.sub("[أإآ]", "ا", tok.replace("ـ", ""))


def parse_words(text, prose=False):
    """-> {level, comment, rest, said} or raises ValueError on two different levels."""
    level, comment, said, keep = None, True, [], []
    for tok in text.split():
        m = re.fullmatch(r"--test=(\S+)", tok)
        if m:
            if m.group(1) not in LEVELS:
                raise ValueError("unknown test level %r — one of %s" % (m.group(1), ", ".join(LEVELS)))
            level = pick(level, m.group(1)); said.append(tok)
        elif tok == "--no-comment":
            comment = False; said.append(tok)
        else:
            keep.append(tok)
    while keep:
        hit = None
        for words, kind, value, in_prose in PHRASES:
            n = len(words)
            if (in_prose or not prose) and len(keep) >= n and tuple(norm(t) for t in keep[-n:]) == words:
                hit = (n, kind, value); break
        if not hit:
            break
        n, kind, value = hit
        said.insert(0, " ".join(keep[-n:])); del keep[-n:]
        if kind == "level":
            level = pick(level, value)
        else:
            comment = False
    return {"level": level or DEFAULT, "comment": comment, "rest": " ".join(keep), "said": said}


def pick(current, new):
    if current and current != new:
        raise ValueError("two test levels said: %s and %s — say one" % (current, new))
    return new


def marker(repo):
    return git_path(repo, "refract-test-level")


def level_in_force(repo):
    try:
        v = open(marker(repo), encoding="utf-8").read().strip()
    except (OSError, ValueError):
        return DEFAULT
    return v if v in LEVELS else DEFAULT


def load_config(repo):
    p = os.path.join(repo, ".claude", "testing.json")
    if not os.path.isfile(p):
        return None
    try:
        return json.load(open(p, encoding="utf-8"))
    except ValueError as e:
        raise ValueError(".claude/testing.json is not valid JSON: %s" % e)


def default_base(repo, cfg):
    if cfg.get("base"):
        return cfg["base"]
    try:
        flow = json.load(open(os.path.join(repo, ".claude", "task-flow.json"), encoding="utf-8"))
        return (flow.get("git") or {}).get("branchFrom") or "origin/main"
    except (OSError, ValueError):
        return "origin/main"


def plan(repo, level=None, base=None):
    level = level or level_in_force(repo)
    if level not in LEVELS:
        raise ValueError("unknown test level %r" % level)
    cfg = load_config(repo)
    if cfg is None:
        return {"level": level, "configured": False, "base": None, "steps": [], "mark": None,
                "line": "tests: no .claude/testing.json — the command's own test step applies"}
    base = base or default_base(repo, cfg)
    steps = []
    for st in STAGES[level]:
        cmd = cfg.get(st)
        steps.append({"stage": st, "cmd": cmd.replace("<base>", base) if cmd else None,
                      "result": "PENDING" if cmd else "MISSING"})
    mark = (cfg.get("readyStatus") or "tested-locally") if level == "ready" else None
    return {"level": level, "configured": True, "base": base, "steps": steps, "mark": mark,
            "line": "tests: none on this machine (no-test)" if not steps else None}


def run_plan(repo, p):
    lane = os.path.join(repo, ".claude", "hooks", "test-lane.sh")
    use_lane = os.path.isfile(lane) and not os.path.exists(os.path.join(repo, ".claude", ".no-test-lane"))
    failed = None
    for s in p["steps"]:
        if s["result"] == "MISSING":
            continue
        if failed:
            s["result"] = "SKIPPED"; continue
        argv = ["bash", lane, "run", s["cmd"]] if use_lane else ["bash", "-c", s["cmd"]]
        rc = subprocess.run(argv, cwd=repo, stdin=subprocess.DEVNULL).returncode
        s["result"] = "PASS" if rc == 0 else "FAIL"
        if rc != 0:
            failed = s["stage"]
    ran = " + ".join(NAMES[s["stage"]] for s in p["steps"])
    missing = [NAMES[s["stage"]] for s in p["steps"] if s["result"] == "MISSING"]
    if p["line"]:
        pass
    elif failed:
        p["line"] = "tests: %s — FAIL at %s" % (ran, NAMES[failed])
    else:
        p["line"] = "tests: %s — PASS" % ran + ("; not configured: %s" % ", ".join(missing) if missing else "")
    if failed or missing:
        p["mark"] = None           # the mark says every stage ran green; a gap never earns it
    tree = None if git_out(repo, "status", "--porcelain") else git_out(repo, "rev-parse", "HEAD^{tree}")
    with open(git_path(repo, "refract-test-run"), "w", encoding="utf-8") as f:
        json.dump({"level": p["level"], "tree": tree, "green": not failed and not missing, "mark": p["mark"]}, f)
    return 1 if failed else 0


def git_out(repo, *args):
    r = subprocess.run(["git"] + list(args), cwd=repo, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def git_path(repo, name):
    p = git_out(repo, "rev-parse", "--git-path", name)
    if not p:
        raise ValueError("not a git repository: %s" % repo)
    return p if os.path.isabs(p) else os.path.join(repo, p)


def mark(repo):
    """Post the ready mark on HEAD — only for a green `ready` run on exactly this committed, pushed tree."""
    try:
        last = json.load(open(git_path(repo, "refract-test-run"), encoding="utf-8"))
    except (OSError, ValueError):
        raise Refused("no recorded run — `test-level.py run --level=ready` first")
    if last.get("level") != "ready" or not last.get("green") or not last.get("mark"):
        raise Refused("the last run was not a green `ready` run")
    if git_out(repo, "status", "--porcelain"):
        raise Refused("the working tree has uncommitted changes")
    if not last.get("tree") or last["tree"] != git_out(repo, "rev-parse", "HEAD^{tree}"):
        raise Refused("HEAD is not the tree the tests ran on — run the level again")
    sha = git_out(repo, "rev-parse", "HEAD")
    if not git_out(repo, "branch", "-r", "--contains", sha):
        raise Refused("HEAD is not on the remote yet — push, then mark")
    gh = os.environ.get("TEST_LEVEL_GH", "gh")
    r = subprocess.run([gh, "api", "repos/{owner}/{repo}/statuses/" + sha, "-f", "state=success",
                        "-f", "context=" + last["mark"], "-f", "description=stage 1 + stage 2 green on this machine"],
                       cwd=repo, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if r.returncode != 0:
        raise Refused("gh api failed: %s" % (r.stderr or r.stdout).strip()[:300])
    return sha, last["mark"]


class Refused(Exception):
    pass


def opt(args, name):
    for a in args:
        if a.startswith("--%s=" % name):
            return a.split("=", 1)[1]
    return None


def main(argv):
    if not argv:
        print(__doc__.split("\n\n")[0] + "\n\nsee --help", file=sys.stderr); return 2
    if argv[0] in ("-h", "--help"):
        print(__doc__); return 0
    cmd, args = argv[0], argv[1:]
    repo = opt(args, "repo") or os.getcwd()
    try:
        if cmd == "words":
            prose = "--prose" in args
            text = " ".join(a for a in args if a != "--prose")
            print(json.dumps(parse_words(text, prose), ensure_ascii=False)); return 0
        if cmd == "set":
            lv = next((a for a in args if not a.startswith("--")), None)
            if lv not in LEVELS:
                raise ValueError("set needs one of %s" % ", ".join(LEVELS))
            with open(marker(repo), "w", encoding="utf-8") as f:
                f.write(lv + "\n")
            return 0
        if cmd == "get":
            print(level_in_force(repo)); return 0
        if cmd == "clear":
            try:
                os.remove(marker(repo))
            except FileNotFoundError:
                pass
            return 0
        if cmd == "mark":
            try:
                sha, ctx = mark(repo)
            except Refused as e:
                print("test-level: mark refused: %s" % e, file=sys.stderr); return 1
            print("marked %s %s" % (sha[:12], ctx)); return 0
        if cmd in ("plan", "run"):
            p = plan(repo, opt(args, "level"), opt(args, "base"))
            rc = run_plan(repo, p) if cmd == "run" and p["configured"] else 0
            print(json.dumps(p, ensure_ascii=False) if cmd == "plan" or "--json" in args else p["line"])
            return rc
    except ValueError as e:
        print("test-level: %s" % e, file=sys.stderr); return 2
    print("test-level: unknown command %r" % cmd, file=sys.stderr); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
