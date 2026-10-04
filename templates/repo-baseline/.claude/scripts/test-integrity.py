#!/usr/bin/env python3
"""test-integrity.py — did this change weaken the tests that judge it?

Usage:  test-integrity.py [--base=<ref>] [--head=<ref>] [--repo=<dir>] [--json] [--quiet]
Exit:   0  no finding    1  at least one finding    2  usage or git error

WHY. A change asked to turn red tests green has cheaper moves than the fix: delete the test, drop
the assertion that fails, mark it skip, lower the coverage floor, take the test step out of CI.
Each is a one-line diff a reviewer reads past, and a green suite afterwards proves nothing. This
script reads the diff for those moves, so "the tests pass" can be checked against "the tests that
existed still exist and still assert".

WHAT IS READ. base..head, where base defaults to the merge-base of HEAD with the first of
origin/HEAD · origin/main · origin/master · main · master that exists, and head defaults to the
WORKING TREE (staged, unstaged and untracked files) — pass --head=HEAD in CI. Heuristics are
language-agnostic in shape with per-stack patterns (JS/TS, Python, Go, JVM, .NET, Ruby, PHP, Rust,
Dart, Swift, Elixir). Every finding cites file:line — the BASE line for something removed, the
HEAD line for something added.

  deleted-test-file           a test file removed, unless every case it held reappears elsewhere
  deleted-test-case           a named case present at base and gone at head (moved is not gone)
  fewer-assertions            the assertion count over the changed test files dropped; cites each
                              removed assertion line (moving a test between files is not a drop)
  new-skip                    an added skip / only / xfail / xit / fdescribe / @Disabled / t.Skip …
  lowered-coverage-threshold  a coverage floor lowered or deleted in config
  removed-ci-test-step        a CI file lost a line that ran tests, or a test line gained `|| true`

NOT COVERED in v1, named so a clean run is not read as covering them: widened numeric tolerances,
snapshot rewrites, `NODE_ENV === 'test'` branches in production code, equality overrides.
"""
import json
import os
import re
import subprocess
import sys
from collections import Counter

LANG = {".js": "js", ".jsx": "js", ".ts": "js", ".tsx": "js", ".mjs": "js", ".cjs": "js",
        ".vue": "js", ".svelte": "js", ".py": "py", ".go": "go", ".java": "jvm", ".kt": "jvm",
        ".kts": "jvm", ".scala": "jvm", ".groovy": "jvm", ".cs": "cs", ".rb": "rb", ".php": "php",
        ".rs": "rs", ".dart": "dart", ".swift": "swift", ".ex": "ex", ".exs": "ex"}

ASSERT = {
    "js": r"\bexpect(?:Type)?\s*\(|\bassert(?:\.\w+)?\s*\(|\.should\b|\bt\.(?:is|not|deepEqual|true|false|throws|equal|ok|assert|snapshot)\s*\(",
    "py": r"^\s*assert\b|\bself\.assert\w+\s*\(|\bpytest\.raises\s*\(|\.assert_\w+\s*\(",
    "go": r"\bt\.(?:Error|Errorf|Fatal|Fatalf|Fail|FailNow)\s*\(|\b(?:assert|require)\.\w+\s*\(",
    "jvm": r"\bassert\w*\s*\(|\bverify\s*\(|\bshould\w*\b|\bexpect\s*\(",
    "cs": r"\bAssert\.\w+\s*\(|\.Should\w*\s*\(|\bVerify\s*\(",
    "rb": r"\bexpect\s*[({]|\bassert\w*\b|\.should\b|\bmust_\w+|\brefute\w*\b",
    "php": r"\$this->assert\w+\s*\(|\bself::assert\w+\s*\(|\bexpect\s*\(|\bassert\w*\s*\(",
    "rs": r"\b(?:debug_)?assert(?:_eq|_ne)?!\s*\(",
    "dart": r"\bexpect(?:Later|Async)?\s*\(",
    "swift": r"\bXCTAssert\w*\s*\(|#expect\s*\(|#require\s*\(",
    "ex": r"\bassert\b|\brefute\b",
}
SKIP = {
    "js": r"\b(?:it|test|describe|context|suite|specify)\.(?:skip|only|todo|fixme)\b|\b(?:xit|xdescribe|xtest|xcontext|fit|fdescribe|ftest)\s*\(",
    "py": r"@pytest\.mark\.(?:skip|skipif|xfail)\b|@unittest\.(?:skip\w*|expectedFailure)\b|\bpytest\.(?:skip|xfail)\s*\(|\bself\.skipTest\s*\(",
    "go": r"\bt\.Skip(?:f|Now)?\s*\(",
    "jvm": r"@(?:Disabled\w*|Ignore)\b|\b(?:xit|xtest|xdescribe|xshould)\s*\(|\.config\s*\(\s*enabled\s*=\s*false",
    "cs": r"\[\s*(?:Fact|Theory)\s*\(\s*Skip\s*=|\[\s*Ignore\b|\[\s*Explicit\b",
    "rb": r"^\s*(?:xit|xdescribe|xcontext|xspecify|fit|fdescribe|fcontext)\b|^\s*(?:skip|pending)\b|\bfocus:\s*true|:focus\b",
    "php": r"->markTest(?:Skipped|Incomplete)\s*\(|->(?:skip|only|todo)\s*\(|@group\s+(?:skip|ignore)\b",
    "rs": r"#\[\s*ignore\b",
    "dart": r"\bskip:\s*(?:true|['\"])|\bsolo:\s*true",
    "swift": r"\bXCTSkip\w*\b|\.disabled\s*\(",
    "ex": r"@(?:module)?tag\s+(?::skip|skip:)",
}
QUOTED = r"""(['"`])(.+?)\1"""
CASE_LINE = {   # a case declared on one line
    "js": r"\b(?:it|test|specify)(?:\.(?:only|skip|concurrent|each\s*\(.*?\)))?\s*\(\s*" + QUOTED,
    "dart": r"\b(?:test|testWidgets)\s*\(\s*" + QUOTED,
    "py": r"^\s*(?:async\s+)?def\s+(test\w*)\s*\(",
    "go": r"^func\s+(Test\w*)\s*\(",
    "rb": r"^\s*(?:it|specify|scenario|test)\s*\(?\s*" + QUOTED + r"|^\s*def\s+(test_\w+)",
    "php": r"function\s+(test\w+)\s*\(|^\s*(?:it|test)\s*\(\s*" + QUOTED,
    "ex": r"^\s*test\s+\"(.+?)\"",
    "swift": r"func\s+(test\w+)\s*\(",
    "jvm": r"\b(?:test|should)\s*\(\s*\"(.+?)\"",
}
CASE_ANNOT = {  # annotation, then the declaration within a few lines
    "jvm": (r"@(?:Test|ParameterizedTest|RepeatedTest|TestFactory)\b", r"\bfun\s+(`[^`]+`|\w+)|\bvoid\s+(\w+)\s*\("),
    "cs": (r"\[\s*(?:Fact|Theory|Test|TestMethod|TestCase)\b", r"\b(?:void|Task)\s+(\w+)\s*\("),
    "rs": (r"#\[\s*(?:\w+::)?test\b", r"\bfn\s+(\w+)"),
    "swift": (r"@Test\b", r"\bfunc\s+(\w+)"),
}
TEST_PATH = re.compile(
    r"(^|/)(tests?|__tests__|spec|specs|e2e|integration_test|androidTest|testFixtures)/"
    r"|\.(test|spec|e2e-spec|e2e)\.[a-z]+$|_(test|spec)\.[a-z]+$|(^|/)test_[^/]+\.py$"
    r"|(Test|Tests|Spec|IT)\.(java|kt|kts|scala|groovy|cs|php|swift)$")
CI_FILE = re.compile(r"(^|/)(\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.yml|\.circleci/config\.yml|"
                     r"azure-pipelines\.yml|bitbucket-pipelines\.yml|Jenkinsfile|\.travis\.yml|"
                     r"\.buildkite/[^/]+\.ya?ml|\.drone\.yml)$")
TEST_CMD = re.compile(
    r"(?i)\b(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?test\b|\b(?:jest|vitest|mocha|pytest|rspec|phpunit|pest|tox|nox)\b"
    r"|\bgo\s+test\b|\bcargo\s+(?:test|nextest)\b|\bmvnw?\b.*\b(?:test|verify)\b|\bgradlew?\b.*\b(?:test|check)\b"
    r"|\bdotnet\s+test\b|\b(?:flutter|dart|swift|mix|rails|make)\s+test\b|\bxcodebuild\b.*\btest\b"
    r"|\bplaywright\s+test\b|\bcypress\s+run\b")
# Which keys state a coverage FLOOR depends on the file: `target` is a floor in codecov.yml and a
# compiler level in pom.xml, `lines` a floor in a jest config and noise elsewhere. Specific keys
# (fail_under, --cov-fail-under, minimum_coverage, …) count in every file listed here.
THR_SPECIFIC = r"fail[_-]?under|cov[_-]fail[_-]under|coverage[_-]?threshold|minimum[_-]?coverage|min[_-]?coverage"
COV_FILES = (
    (r"(^|/)((jest|vitest|vite|karma)\.config\.\w+|\.nycrc(\.\w+)?|\.c8rc(\.\w+)?|package\.json)$",
     r"\bbranches\b|\bfunctions\b|\blines\b|\bstatements\b"),
    (r"(^|/)\.?codecov\.ya?ml$", r"\btarget\b"),
    (r"(^|/)(pom\.xml|build\.gradle(\.kts)?)$", r"\bminimum\b|\bcoveredratio\b"),
    (r"(^|/)(\.simplecov|tarpaulin\.toml|pyproject\.toml|setup\.cfg|tox\.ini|\.coveragerc|pytest\.ini|"
     r"Makefile|\.gitlab-ci\.yml|\.github/workflows/[^/]+\.ya?ml)$", None),
)
NUM_AFTER = r"[^0-9\n]{0,24}?(\d+(?:\.\d+)?)"


def git(repo, *args, ok=(0,)):
    r = subprocess.run(["git", "-C", repo, "-c", "core.quotepath=false"] + list(args),
                       capture_output=True, text=True, errors="replace")
    if r.returncode not in ok:
        raise RuntimeError("git %s: %s" % (" ".join(args[:3]), r.stderr.strip()[:300]))
    return r.stdout


def resolve_base(repo, want):
    if want:
        return git(repo, "rev-parse", "--verify", want + "^{commit}").strip()
    for cand in ("origin/HEAD", "origin/main", "origin/master", "main", "master"):
        r = subprocess.run(["git", "-C", repo, "merge-base", "HEAD", cand], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    return git(repo, "rev-parse", "--verify", "HEAD^{commit}").strip()


def parse_diff(text):
    """unified -U0 diff -> {path: {"old": path|None, "new": path|None, "add": [(ln, s)], "rem": [(ln, s)]}}"""
    files, cur, in_hunk, ol, nl = {}, None, False, 0, 0
    for line in text.split("\n"):
        if line.startswith("diff --git "):
            cur, in_hunk = {"old": None, "new": None, "add": [], "rem": []}, False
        elif cur is None:
            continue
        elif not in_hunk and line.startswith("--- "):
            p = line[4:]
            cur["old"] = None if p == "/dev/null" else p[2:]
        elif not in_hunk and line.startswith("+++ "):
            p = line[4:]
            cur["new"] = None if p == "/dev/null" else p[2:]
            files[cur["new"] or cur["old"]] = cur
        elif line.startswith("@@"):
            m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
            if m:
                in_hunk, ol, nl = True, int(m.group(1)), int(m.group(2))
        elif in_hunk and line.startswith("-"):
            cur["rem"].append((ol, line[1:])); ol += 1
        elif in_hunk and line.startswith("+"):
            cur["add"].append((nl, line[1:])); nl += 1
    return files


def lang_of(path):
    return LANG.get(os.path.splitext(path)[1].lower())


def code_lines(text):
    """(line_no, line) for lines that are not wholly comments."""
    for i, l in enumerate(text.split("\n"), 1):
        s = l.strip()
        if not s or s.startswith(("//", "#", "/*", "*", "<!--")) and not s.startswith(("#[", "#expect", "#require")):
            continue
        yield i, l


def assertions(lang, text):
    rx = re.compile(ASSERT[lang])
    return sum(len(rx.findall(l)) for _, l in code_lines(text))


def cases(lang, text):
    """[(name, line)] for every named test case this file declares."""
    out, lines = [], text.split("\n")
    one = re.compile(CASE_LINE[lang]) if lang in CASE_LINE else None
    ann = CASE_ANNOT.get(lang)
    for i, l in enumerate(lines, 1):
        if one:
            for m in one.finditer(l):
                name = next((g for g in m.groups()[::-1] if g and g not in "'\"`"), None)
                if name:
                    out.append((name, i))
        if ann and re.search(ann[0], l):
            for j in range(i - 1, min(i + 4, len(lines))):
                d = re.search(ann[1], lines[j])
                if d:
                    out.append((next(g for g in d.groups() if g), j + 1))
                    break
    return out


def norm(s):
    return re.sub(r"\s+", " ", s.strip().lstrip("-").strip().replace("run:", "").strip())


def cov_keys(path):
    for pat, extra in COV_FILES:
        if re.search(pat, path):
            return THR_SPECIFIC + ("|" + extra if extra else "")
    return None


def thresholds(rx, lines):
    """[(key, value, line)] coverage floors stated on these lines."""
    out = []
    for ln, s in lines:
        if s.strip().startswith(("#", "//")):
            continue
        for m in re.finditer(r"(?i)(%s)%s" % (rx, NUM_AFTER), s):
            out.append((re.sub(r"[^a-z]", "", m.group(1).lower()), float(m.group(2)), ln))
    return out


def check(repo, base, head):
    findings = []
    add = lambda kind, f, ln, msg: findings.append({"kind": kind, "file": f, "line": ln, "message": msg})
    diff_args = ["diff", "-U0", "-M", "--no-color", "--no-ext-diff", base] + ([head] if head else [])
    files = parse_diff(git(repo, *diff_args))
    if not head:
        for p in git(repo, "ls-files", "-o", "--exclude-standard").splitlines():
            fp = os.path.join(repo, p)
            if p and os.path.isfile(fp) and os.path.getsize(fp) < 2_000_000:
                body = open(fp, encoding="utf-8", errors="replace").read()
                files[p] = {"old": None, "new": p, "rem": [],
                            "add": list(enumerate(body.split("\n"), 1))}

    def content(rev, path):
        if not path:
            return ""
        if rev is None:
            fp = os.path.join(repo, path)
            return open(fp, encoding="utf-8", errors="replace").read() if os.path.isfile(fp) else ""
        r = subprocess.run(["git", "-C", repo, "show", "%s:%s" % (rev, path)],
                           capture_output=True, text=True, errors="replace")
        return r.stdout if r.returncode == 0 else ""

    tests = {}                      # key -> (lang, base_text, head_text, entry)
    for key, e in files.items():
        lang = lang_of(key)
        if not lang:
            continue
        on_path = TEST_PATH.search(e["old"] or "") or TEST_PATH.search(e["new"] or "")
        if not on_path and lang != "rs":
            continue
        b, h = content(base, e["old"]), content(head, e["new"])
        if on_path or "#[test]" in b + h:            # Rust keeps unit tests beside the code
            tests[key] = (lang, b, h, e)

    base_names, head_names = Counter(), Counter()
    for lang, b, h, _ in tests.values():
        base_names.update(n for n, _ in cases(lang, b))
        head_names.update(n for n, _ in cases(lang, h))
    lost = base_names - head_names                       # names that are gone everywhere

    a_base = sum(assertions(l, b) for l, b, _, _ in tests.values())
    a_head = sum(assertions(l, h) for l, _, h, _ in tests.values())
    for key, (lang, b, h, e) in sorted(tests.items()):
        if e["new"] is None:                                         # deleted file
            held = cases(lang, b)
            gone = [n for n, _ in held if lost[n] > 0]
            if gone or (not held and assertions(lang, b)):
                add("deleted-test-file", e["old"], 1, "test file deleted — %d case(s) it held exist "
                    "nowhere else in the change%s" % (len(gone), (": " + ", ".join(gone[:5])) if gone else ""))
            continue
        before, after = Counter(n for n, _ in cases(lang, b)), Counter(n for n, _ in cases(lang, h))
        for name, ln in cases(lang, b):
            if before[name] > after[name] and lost[name] > 0:
                add("deleted-test-case", e["old"], ln, "test case `%s` removed and not re-added anywhere "
                    "in this change" % name)
                lost[name] -= 1
                before[name] -= 1
        nb, nh = assertions(lang, b), assertions(lang, h)
        if b and nh < nb and a_head < a_base:
            rx = re.compile(ASSERT[lang])
            removed = [ln for ln, s in e["rem"] if rx.search(s) and not s.strip().startswith(("//", "#"))]
            add("fewer-assertions", e["old"] or e["new"], removed[0] if removed else 1,
                "assertions %d -> %d in this file (%d across the changed tests); removed at line(s) %s"
                % (nb, nh, a_head - a_base, ", ".join(map(str, removed[:8])) or "?"))
        gone_lines = {s.strip() for _, s in e["rem"]}
        rx = re.compile(SKIP[lang])
        for ln, s in e["add"]:
            if rx.search(s) and s.strip() not in gone_lines and not s.strip().startswith(("//", "# ")):
                add("new-skip", e["new"], ln, "test disabled or focused: %s" % s.strip()[:100])

    head_ci = "\n".join(content(head, e["new"]) for e in files.values() if e["new"] and CI_FILE.search(e["new"]))
    for key, e in sorted(files.items()):
        path = e["new"] or e["old"]
        rx = cov_keys(path)
        if rx:
            was, now = thresholds(rx, e["rem"]), thresholds(rx, e["add"])
            head_all = thresholds(rx, list(enumerate(content(head, e["new"]).split("\n"), 1)))
            for k, v, ln in was:
                same = [x for x in now if x[0] == k]
                if same and min(x[1] for x in same) < v:
                    nk = min(same, key=lambda x: x[1])
                    add("lowered-coverage-threshold", path, nk[2], "coverage floor `%s` lowered %g -> %g" % (k, v, nk[1]))
                elif not same and sum(1 for x in head_all if x[0] == k) < sum(1 for x in was if x[0] == k):
                    add("lowered-coverage-threshold", e["old"] or path, ln, "coverage floor `%s` (%g) removed" % (k, v))
        if CI_FILE.search(e["old"] or "") or CI_FILE.search(e["new"] or ""):
            readded = {norm(s) for _, s in e["add"]}
            for ln, s in e["rem"]:
                if TEST_CMD.search(s) and not s.strip().startswith("#") and norm(s) not in readded \
                        and norm(s) not in norm(head_ci):
                    add("removed-ci-test-step", e["old"], ln, "CI no longer runs: %s" % s.strip()[:100])
            for ln, s in e["add"]:
                if TEST_CMD.search(s) and re.search(r"\|\|\s*(true|:)\b|;\s*exit\s+0\b", s):
                    add("removed-ci-test-step", e["new"], ln, "CI test step made non-blocking: %s" % s.strip()[:100])
    return findings, len(files)


def main(argv):
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    flags = {a for a in argv if a.startswith("--") and "=" not in a}
    unknown = (set(opts) - {"base", "head", "repo"}) | (flags - {"--json", "--quiet"})
    if unknown or any(not a.startswith("--") for a in argv):
        print("usage: test-integrity.py [--base=<ref>] [--head=<ref>] [--repo=<dir>] [--json] [--quiet]",
              file=sys.stderr)
        return 2
    repo = os.path.abspath(opts.get("repo", "."))
    try:
        git(repo, "rev-parse", "--git-dir")
        base = resolve_base(repo, opts.get("base"))
        head = opts.get("head")
        if head:
            head = git(repo, "rev-parse", "--verify", head + "^{commit}").strip()
        findings, n = check(repo, base, head)
    except RuntimeError as e:
        print("test-integrity: %s" % e, file=sys.stderr)
        return 2
    if "--json" in flags:
        print(json.dumps({"base": base, "head": head or "worktree", "files_changed": n,
                          "findings": findings}, indent=2))
    elif "--quiet" not in flags or findings:
        print("test-integrity — %s..%s — %d changed file(s)" % (base[:12], (head or "worktree")[:12], n))
        for f in findings:
            print("  %-28s %s:%s — %s" % (f["kind"], f["file"], f["line"], f["message"]))
        print("summary: %d finding(s)" % len(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
