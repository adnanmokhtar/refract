#!/usr/bin/env python3
"""trace-matrix.py — REQ → AC → task → test, with every orphan named.

Usage:  trace-matrix.py <run_id> [--phase=analysis|plan|build] [--json] [--repo=<dir>]
Exit:   0 every link holds · 2 orphans (each printed) · 1 usage error (no run, unreadable file)

WHY. A requirement nobody tests, a criterion no task implements, a task nobody asked for and a test
that names a file which does not exist all look fine one artifact at a time. The links between
requirements.md, acceptance.json and plan.md are where scope silently grows or shrinks, and a
reviewer reading one file cannot see them. This script reads all three and fails on any break, so
P2's and P5's exits ("trace REQ→AC→T 100%", proposal §4.2) are a fact, not a reading.

PHASES (each includes the checks of the one before):
  analysis  requirements.md: every REQ-### has ≥1 AC-###; every AC sits under a REQ; no duplicate id.
  plan      + acceptance.json and requirements.md hold the same AC ids; a criterion's `req` (when set)
            names an existing REQ and the AC sits under that REQ; every AC is cited by ≥1 task in
            plan.md ## Steps (`- T-003 (AC-001, AC-002) [lane: backend] <step>`); every task cites
            ≥1 AC and only ACs that exist.
  build     + every criterion names ≥1 test; every tests[].path exists on disk and the test's name
            occurs in that file.
Default: the furthest phase whose inputs exist — build when acceptance.json names tests and every
test file is on disk, plan when plan.md and acceptance.json exist, else analysis. Pass --phase to
hold a phase whose inputs are incomplete (a missing test file then FAILs instead of downgrading).

HONEST LIMITS:
  * "The test name occurs in the file" is a substring check, not a parse of the test framework: a
    name in a comment counts. The verifier runs the tests; this proves only that the link resolves.
  * Requirements are read in the run-ledger format (`### REQ-### — title`, `- AC-###: …` on one
    line); anything else is invisible to the matrix, which then reports the orphan it causes.
"""
import json
import os
import re
import subprocess
import sys

STORY = re.compile(r"^#{3}\s+(REQ-\d{3,})\b")
HEADING = re.compile(r"^#{1,6}\s")
CRIT = re.compile(r"^\s*[-*]\s+(?:\*\*)?(AC-\d{3,})(?:\*\*)?\s*:")
TASK = re.compile(r"^\s*[-*]\s+(?:\[[ xX]\]\s+)?(?:\*\*)?(T-\d{3,})(?:\*\*)?\b(.*)$")
AC_ID = re.compile(r"\bAC-\d{3,}\b")
PHASES = ["analysis", "plan", "build"]


def toplevel(start):
    try:
        r = subprocess.run(["git", "-C", start, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else None
    except OSError:
        return None


def read_lines(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read().splitlines()


def parse_requirements(path):
    reqs, acs, dups, loose = {}, {}, [], []           # REQ -> [AC]; AC -> REQ; duplicate ids; ACs under no REQ
    cur, fence = None, False
    for n, line in enumerate(read_lines(path), 1):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        m = STORY.match(line)
        if m:
            cur = m.group(1)
            if cur in reqs:
                dups.append((cur, n))
            reqs.setdefault(cur, [])
            continue
        if HEADING.match(line):
            cur = None
            continue
        m = CRIT.match(line)
        if m:
            ac = m.group(1)
            if ac in acs:
                dups.append((ac, n))
                continue
            acs[ac] = cur
            if cur:
                reqs[cur].append(ac)
            else:
                loose.append((ac, n))
    return reqs, acs, dups, loose


def parse_plan(path):
    tasks, in_steps = {}, False                        # T -> [AC], in file order
    for line in read_lines(path):
        if line.startswith("## "):
            in_steps = line[3:].strip().lower().startswith("steps")
            continue
        if not in_steps:
            continue
        m = TASK.match(line)
        if m:
            rest = m.group(2)
            cited = AC_ID.findall(rest.split(")", 1)[0]) if rest.strip().startswith("(") else []
            tasks.setdefault(m.group(1), []).extend(cited)
    return tasks


def trace(repo, run_id, phase=None):
    d = os.path.join(repo, "ai", "runs", run_id)
    req_p, acc_p, plan_p = (os.path.join(d, n) for n in ("requirements.md", "acceptance.json", "plan.md"))
    if not os.path.isfile(req_p):
        raise FileNotFoundError("ai/runs/%s/requirements.md does not exist" % run_id)
    acc = None
    if os.path.isfile(acc_p):
        with open(acc_p, encoding="utf-8") as fh:
            acc = json.load(fh)
    crit = [c for c in (acc or {}).get("criteria", []) if isinstance(c, dict)]
    if phase is None:
        tests = [t.get("path") for c in crit for t in c.get("tests", []) or []]
        if acc is not None and os.path.isfile(plan_p) and tests and all(
                p and os.path.isfile(os.path.join(repo, p)) for p in tests):
            phase = "build"
        elif acc is not None and os.path.isfile(plan_p):
            phase = "plan"
        else:
            phase = "analysis"
    level = PHASES.index(phase)
    orphans = []

    def o(kind, ident, problem):
        orphans.append({"kind": kind, "id": ident, "problem": problem})

    reqs, acs, dups, loose = parse_requirements(req_p)
    for ident, n in dups:
        o("duplicate", ident, "id appears twice in requirements.md (again at line %d)" % n)
    for ac, n in loose:
        o("ac", ac, "requirements.md:%d — criterion under no REQ story" % n)
    for r, cs in reqs.items():
        if not cs:
            o("req", r, "story has no acceptance criterion")
    tasks, acc_ids, tests_of = {}, [], {}
    if level >= 1:
        if acc is None:
            o("file", "acceptance.json", "ai/runs/%s/acceptance.json does not exist (phase %s)" % (run_id, phase))
        if not os.path.isfile(plan_p):
            o("file", "plan.md", "ai/runs/%s/plan.md does not exist (phase %s)" % (run_id, phase))
        else:
            tasks = parse_plan(plan_p)
            if not tasks:
                o("file", "plan.md", "no `- T-### (AC-…) …` task under ## Steps")
        for c in crit:
            cid = c.get("id") or "?"
            if cid in acc_ids:
                o("duplicate", cid, "id appears twice in acceptance.json")
            acc_ids.append(cid)
            tests_of[cid] = [t for t in c.get("tests", []) or [] if isinstance(t, dict)]
            if cid not in acs:
                o("ac", cid, "in acceptance.json, not in requirements.md")
            want = c.get("req")
            if want:
                if want not in reqs:
                    o("ac", cid, "acceptance.json req %s is not a story in requirements.md" % want)
                elif cid in acs and acs[cid] != want:
                    o("ac", cid, "acceptance.json says req %s, requirements.md files it under %s" % (want, acs[cid]))
        if acc is not None:
            for ac in acs:
                if ac not in acc_ids:
                    o("ac", ac, "in requirements.md, not in acceptance.json")
        cited = {}
        for t, cs in tasks.items():
            if not cs:
                o("task", t, "cites no criterion — write `- %s (AC-…) …`" % t)
            for ac in cs:
                if ac not in acs:
                    o("task", t, "cites %s, which is not a criterion in requirements.md" % ac)
                cited.setdefault(ac, []).append(t)
        if tasks:
            for ac in acs:
                if ac not in cited:
                    o("ac", ac, "no task in plan.md cites it")
    else:
        cited = {}
    if level >= 2:
        for cid in acc_ids:
            ts = tests_of.get(cid) or []
            if not ts:
                o("test", cid, "names no test")
            for t in ts:
                p, name = t.get("path") or "", t.get("name") or ""
                full = os.path.join(repo, p)
                if not p or not os.path.isfile(full):
                    o("test", cid, "test file %s does not exist" % (p or "(no path)"))
                elif name:
                    with open(full, encoding="utf-8", errors="replace") as fh:
                        if name not in fh.read():
                            o("test", cid, "test name %r does not occur in %s" % (name, p))
    rows = []
    for r in sorted(reqs):
        for ac in reqs[r] or [None]:
            rows.append({"req": r, "ac": ac, "tasks": sorted(set(cited.get(ac, []))) if ac else [],
                         "tests": ["%s::%s" % (t.get("path"), t.get("name")) for t in tests_of.get(ac, [])] if ac else []})
    n_ac = len(acs)
    cov = {"req_to_ac": "%d/%d" % (sum(1 for r in reqs if reqs[r]), len(reqs))}
    if level >= 1:
        cov["ac_in_contract"] = "%d/%d" % (sum(1 for a in acs if a in acc_ids), n_ac)
        cov["ac_to_task"] = "%d/%d" % (sum(1 for a in acs if a in cited), n_ac)
        cov["task_to_ac"] = "%d/%d" % (sum(1 for t in tasks if tasks[t] and all(a in acs for a in tasks[t])), len(tasks))
    if level >= 2:
        cov["ac_to_test"] = "%d/%d" % (sum(1 for a in acc_ids if tests_of.get(a)), len(acc_ids))
    return {"schema": "refract/trace/v1", "run_id": run_id, "phase": phase, "coverage": cov,
            "matrix": rows, "orphans": orphans}


def main(argv):
    opts = dict(a[2:].partition("=")[::2] for a in argv if a.startswith("--"))
    pos = [a for a in argv if not a.startswith("--")]
    if len(pos) != 1 or (opts.get("phase") and opts["phase"] not in PHASES):
        print(__doc__.split("\n\n")[0] + "\n" + __doc__.split("\n\n")[1], file=sys.stderr)
        return 1
    repo = toplevel(opts.get("repo") or ".") or os.path.abspath(opts.get("repo") or ".")
    try:
        res = trace(repo, pos[0], opts.get("phase") or None)
    except (OSError, ValueError) as e:
        print("trace-matrix: %s" % e, file=sys.stderr)
        return 1
    if "json" in opts:
        print(json.dumps(res, indent=2))
    else:
        print("trace-matrix %s — phase %s — %s" % (pos[0], res["phase"],
              " · ".join("%s %s" % (k, v) for k, v in res["coverage"].items())))
        print("  %-9s %-8s %-18s %s" % ("REQ", "AC", "tasks", "tests"))
        for r in res["matrix"]:
            print("  %-9s %-8s %-18s %s" % (r["req"], r["ac"] or "—", ",".join(r["tasks"]) or "—",
                                             ", ".join(r["tests"]) or "—"))
        if res["orphans"]:
            print("ORPHANS (%d):" % len(res["orphans"]))
            for x in res["orphans"]:
                print("  %s %s — %s" % (x["kind"], x["id"], x["problem"]))
        else:
            print("no orphans")
    return 2 if res["orphans"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
