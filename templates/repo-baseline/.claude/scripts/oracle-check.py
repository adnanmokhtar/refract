#!/usr/bin/env python3
"""oracle-check.py — does each new or changed test actually assert something?

Usage:  oracle-check.py [--base=<ref>] [--head=<ref>] [--repo=<dir>] [--files=a,b] [--all] [--json]
Exit:   0  no finding    1  at least one finding    2  usage or git error

WHY. A test that runs code and asserts nothing passes against every implementation, including the
wrong one — it is coverage, not a check. Agent-written test patches are mostly like that: 80.2% have
a weak or missing oracle (the research behind Refract's verification layer, [B §1 #4]). A green
suite of such tests proves the code ran. This script finds them, per test case, in the tests this
change added or touched, so "the tests pass" can be weighed against "the tests would fail if the
code were wrong". It is the QG-15 check of the engineering baseline.

WHAT IS READ. base..head, base defaulting to the merge-base of HEAD with origin/HEAD · origin/main ·
origin/master · main · master, head defaulting to the WORKING TREE (untracked test files included);
--head=HEAD in CI. Only test files (same path rules as test-integrity.py) and only the cases with at
least one added line. --files= checks the named files whole; --all checks every case in them.

  no-assertion   the case's body holds no assertion at all (custom `expectX(` / `assertX(` /
                 `verifyX(` helpers count as assertions)
  weak-oracle    every assertion in the body is one that holds for almost any result:
                 toBeDefined / toBeTruthy / not.toThrow / not.toBeNull / toHaveBeenCalled() with no
                 arguments; Python bare `assert x`, `assert x is not None`, assertIsNotNone,
                 assertTrue(x); Go assert.NotNil / require.NoError / assert.True alone
  tautology      an assertion that cannot fail: expect(true).toBe(true), assert True,
                 assertEqual(a, a), expect(x).toBe(x)

Per-case bodies are delimited by braces (JS/TS, Go, JVM, .NET, PHP, Rust, Dart, Swift), indentation
(Python) or `end` (Ruby, Elixir). NOT COVERED: snapshot-only tests (a snapshot is an oracle, if a
weak one — test-integrity.py flags snapshot rewrites instead), property tests with generator-only
bodies, and assertions inside helper functions whose names do not start with expect / assert /
verify / check / should.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True          # no __pycache__ in the project (see gate-check.py)
_spec = importlib.util.spec_from_file_location("test_integrity", os.path.join(HERE, "test-integrity.py"))
ti = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ti)

HELPER = r"\b(?:expect|assert|verify|check|should)[A-Z_]\w*\s*\("
WEAK = {
    "js": r"\.(?:toBeDefined|toBeTruthy|toBeFalsy)\(\s*\)|\.not\.(?:toThrow|toThrowError|toBeNull|toBeUndefined|toBeFalsy)\(\s*\)"
          r"|\.toHaveBeenCalled\(\s*\)|\.toBeInstanceOf\(\s*Object\s*\)|\bexpect\([^()]*(?:\([^()]*\))?[^()]*\)\s*;?\s*$",
    "py": r"^\s*assert\s+(?:not\s+)?[\w.]+(?:\([^()]*\))?\s*(?:,.*)?$|^\s*assert\s+.+\s+is\s+not\s+None\s*(?:,.*)?$"
          r"|\bassertIsNotNone\(|\bassertTrue\(\s*[\w.]+\s*\)|\bassert_called\(\s*\)",
    "go": r"\b(?:assert|require)\.(?:NotNil|NoError|NotEmpty|True)\(",
    "jvm": r"\bassertNotNull\(|\bassertTrue\(\s*\w+\s*\)|\.isNotNull\(\s*\)",
    "cs": r"\bAssert\.(?:IsNotNull|NotNull|IsTrue)\(\s*\w+\s*\)|\.Should\(\)\.NotBeNull\(\s*\)",
    "php": r"\$this->assert(?:NotNull|True)\(\s*\$\w+\s*\)",
    "rb": r"\bexpect\([^)]*\)\.(?:to|not_to)\s+(?:be_truthy|be_nil|be_present)\b|\.not_to\s+raise_error",
    "dart": r"\bexpect\([^,]+,\s*(?:isNotNull|isTrue|anything)\s*\)",
    "swift": r"\bXCTAssertNotNil\(|\bXCTAssertTrue\(\s*\w+\s*\)",
}
TAUTOLOGY = (r"\bexpect\(\s*(true|false|null|undefined|\d+|'[^']*'|\"[^\"]*\")\s*\)\.(?:toBe|toEqual|toStrictEqual)\(\s*\1\s*\)"
             r"|\bexpect\(\s*([\w.]+)\s*\)\.(?:toBe|toEqual|toStrictEqual)\(\s*\2\s*\)"
             r"|^\s*assert\s+True\b|\bassert(?:Equal|Equals|Same)\(\s*([\w.]+)\s*,\s*\3\s*\)|\bXCTAssertTrue\(\s*true\s*\)")
BRACES = {"js", "go", "jvm", "cs", "php", "rs", "dart", "swift"}


def body_span(lang, lines, start):
    """(first, last) 1-based line numbers of the case declared at `start`."""
    n = len(lines)
    if lang == "py":
        ind = len(lines[start - 1]) - len(lines[start - 1].lstrip())
        end = start
        for j in range(start, n):
            s = lines[j]
            if s.strip() and len(s) - len(s.lstrip()) <= ind:
                break
            end = j + 1
        return start, end
    if lang in ("rb", "ex"):
        ind = len(lines[start - 1]) - len(lines[start - 1].lstrip())
        for j in range(start, n):
            s = lines[j]
            if s.strip() == "end" and len(s) - len(s.lstrip()) <= ind:
                return start, j + 1
        return start, min(n, start + 40)
    if lang in BRACES:
        depth, opened = 0, False
        for j in range(start - 1, min(n, start + 400)):
            code = re.sub(r"(['\"`])(?:\\.|(?!\1).)*\1", "''", lines[j])
            code = re.sub(r"//.*$", "", code)
            for ch in code:
                if ch == "{":
                    depth, opened = depth + 1, True
                elif ch == "}":
                    depth -= 1
            if not opened and j >= start + 1:
                return start, start              # arrow body on one line, no braces
            if opened and depth <= 0:
                return start, j + 1
        return start, min(n, start + 40)
    return start, min(n, start + 30)


def classify(lang, body_lines):
    strong_rx = re.compile("(?:%s)|%s" % (ti.ASSERT[lang], HELPER))
    weak_rx = re.compile(WEAK[lang]) if lang in WEAK else None
    taut_rx = re.compile(TAUTOLOGY)
    strong = weak = taut = 0
    for s in body_lines:
        t = s.strip()
        if not t or t.startswith(("//", "#", "*", "/*")):
            continue
        hits = len(strong_rx.findall(s))
        if not hits:
            continue
        if taut_rx.search(s):
            taut += 1
        elif weak_rx and weak_rx.search(s):
            weak += 1
        else:
            strong += hits
    if strong:
        return None
    if taut:
        return "tautology"
    if weak:
        return "weak-oracle"
    return "no-assertion"


MESSAGES = {
    "no-assertion": "test case `%s` asserts nothing — it passes against any implementation, including a wrong one",
    "weak-oracle": "test case `%s` only asserts that something exists, is truthy or did not throw — the wrong value passes it",
    "tautology": "test case `%s` asserts something that cannot fail",
}


def check_file(repo, path, added, whole):
    lang = ti.lang_of(path)
    fp = os.path.join(repo, path)
    if not lang or not os.path.isfile(fp):
        return [], 0
    text = open(fp, encoding="utf-8", errors="replace").read()
    lines = text.split("\n")
    out, n = [], 0
    seen = set()
    for name, ln in ti.cases(lang, text):
        if ln in seen:
            continue
        seen.add(ln)
        a, b = body_span(lang, lines, ln)
        if not whole and not any(a <= x <= b for x in added):
            continue
        n += 1
        kind = classify(lang, lines[a - 1:b])
        if kind:
            out.append({"kind": kind, "file": path, "line": ln, "case": name, "message": MESSAGES[kind] % name})
    return out, n


def main(argv):
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    flags = {a for a in argv if a.startswith("--") and "=" not in a}
    if (set(opts) - {"base", "head", "repo", "files"}) or (flags - {"--json", "--all"}) or any(not a.startswith("--") for a in argv):
        print(__doc__.split("\n\n")[0].split("\n", 1)[1], file=sys.stderr)
        return 2
    repo = os.path.abspath(opts.get("repo", "."))
    findings, checked, files = [], 0, []
    try:
        if opts.get("files"):
            files = [f for f in opts["files"].split(",") if f]
            for f in files:
                got, n = check_file(repo, f, set(), True)
                findings += got
                checked += n
            base = head = None
        else:
            ti.git(repo, "rev-parse", "--git-dir")
            base = ti.resolve_base(repo, opts.get("base"))
            head = opts.get("head")
            if head:
                head = ti.git(repo, "rev-parse", "--verify", head + "^{commit}").strip()
            diff = ti.parse_diff(ti.git(repo, "diff", "-U0", "--no-color", "--no-ext-diff", base, *([head] if head else [])))
            added = {k: {ln for ln, _ in e["add"]} for k, e in diff.items() if e["new"]}
            if not head:
                for p in ti.git(repo, "ls-files", "-o", "--exclude-standard").splitlines():
                    if p and os.path.isfile(os.path.join(repo, p)):
                        added[p] = set(range(1, 100000))
            for path, lines in sorted(added.items()):
                if not ti.TEST_PATH.search(path):
                    continue
                if head:   # read the committed content, not the working tree
                    content = subprocess.run(["git", "-C", repo, "show", "%s:%s" % (head, path)], capture_output=True,
                                             text=True, errors="replace").stdout
                    lang = ti.lang_of(path)
                    if not lang:
                        continue
                    ls = content.split("\n")
                    for name, ln in ti.cases(lang, content):
                        a, b = body_span(lang, ls, ln)
                        if "--all" not in flags and not any(a <= x <= b for x in lines):
                            continue
                        checked += 1
                        kind = classify(lang, ls[a - 1:b])
                        if kind:
                            findings.append({"kind": kind, "file": path, "line": ln, "case": name,
                                             "message": MESSAGES[kind] % name})
                    continue
                files.append(path)
                got, n = check_file(repo, path, lines, "--all" in flags)
                findings += got
                checked += n
    except RuntimeError as e:
        print("oracle-check: %s" % e, file=sys.stderr)
        return 2
    if "--json" in flags:
        print(json.dumps({"base": base, "head": head or ("worktree" if base else None), "cases_checked": checked,
                          "findings": findings}, indent=2))
    else:
        print("oracle-check — %d changed test case(s) checked" % checked)
        for f in findings:
            print("  %-13s %s:%s — %s" % (f["kind"], f["file"], f["line"], f["message"]))
        print("summary: %d finding(s)" % len(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
