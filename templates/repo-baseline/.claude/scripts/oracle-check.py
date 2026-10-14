#!/usr/bin/env python3
"""oracle-check.py — does each new or changed test actually assert something?

Usage:  oracle-check.py [--base=<ref>] [--head=<ref>] [--repo=<dir>] [--files=a,b] [--all] [--json]
        oracle-check.py --self-test
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
                 arguments (`not.toHaveBeenCalled()` pins "no side effect" — precedents/testing.md § 20 —
                 and counts as an oracle); Python bare `assert x`, `assert x is not None`, assertIsNotNone,
                 assertTrue(x); Go assert.NotNil / require.NoError / assert.True alone
  tautology      an assertion that cannot fail: expect(true).toBe(true), assert True,
                 assertEqual(a, a), expect(x).toBe(x)

Per-case bodies are delimited by braces (JS/TS, Go, JVM, .NET, PHP, Rust, Dart, Swift) — an arrow body
with no braces by the call's closing parenthesis, over as many lines as it takes — indentation (Python)
or `end` (Ruby, Elixir). A case "declared" inside a comment (`it (\`x\`)` in a docblock) is not a case.

PRECEDENT COLUMN (JS/TS rows). A row whose weak lines are HTTP status checks carries `precedent`:
`§16 status-4xx` (a refusal status is the behaviour — bulk-close by precedents/testing.md § 16),
`§16 2xx-paired` (2xx only, but another case in the file asserts the body of the same route) or
`§16 2xx-unpaired` (2xx only and nothing pins the body — § 16 flips back: read it). NOT COVERED: snapshot-only tests (a snapshot is an oracle, if a
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
          r"|(?<!\.not)\.toHaveBeenCalled\(\s*\)|\.toBeInstanceOf\(\s*Object\s*\)|\bexpect\([^()]*(?:\([^()]*\))?[^()]*\)\s*;?\s*$",
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
STATUS = re.compile(r"\.expect\(\s*([1-5]\d\d)\s*[,)]|\bstatus(?:Code)?\b[^\n]{0,40}?\.(?:toBe|toEqual)\(\s*([1-5]\d\d)\s*\)"
                    r"|toHaveProperty\(\s*['\"]status(?:Code)?['\"]\s*,\s*([1-5]\d\d)|toHaveStatus\(\s*([1-5]\d\d)")
ROUTE = re.compile(r"\.(?:get|post|put|patch|delete|head|options)\(\s*([`'\"])(/[^`'\"$?]*)")
BODY = re.compile(r"\.body\b[^\n]*\.(?:toEqual|toStrictEqual|toMatchObject|toBe|toContain\w*|toHaveLength|toHaveProperty)\(|expect\(\s*(?:res|response|r)\.body")


TOKENS = re.compile(r"""'(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*"|`(?:\\.|[^`\\])*`|(?<!:)//[^\n]*|/\*[\s\S]*?\*/""")


def mask_comments(text):
    """Blank `//` and `/* */` comments outside string literals, keeping every newline (line numbers hold).
    A `/*` inside a string — a glob such as 'src/**/*.ts' — is not a comment."""
    return TOKENS.sub(lambda m: m.group(0) if m.group(0)[0] in "'\"`" else re.sub(r"[^\n]", " ", m.group(0)), text)


def precedent(lang, body, siblings):
    """§ 16 tag for a weak JS/TS row whose weak lines are status checks; None otherwise."""
    if lang != "js":
        return None
    codes = [int(next(g for g in m.groups() if g)) for m in STATUS.finditer(body)]
    if not codes:
        return None
    if any(c >= 400 for c in codes):
        return "§16 status-4xx"
    routes = {m.group(2).rstrip("/") for m in ROUTE.finditer(body)}
    paired = any(BODY.search(o) and routes & {m.group(2).rstrip("/") for m in ROUTE.finditer(o)} for o in siblings)
    return "§16 2xx-paired" if paired else "§16 2xx-unpaired"


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
            if not opened and j >= start + 1:    # an arrow body with no braces: it ends where the call's parenthesis closes
                return start, paren_end(lines, start)
            if opened and depth <= 0:
                return start, j + 1
        return start, min(n, start + 40)
    return start, min(n, start + 30)


def paren_end(lines, start):
    depth, seen = 0, False
    for j in range(start - 1, min(len(lines), start + 60)):
        code = re.sub(r"(['\"`])(?:\\.|(?!\1).)*\1", "''", lines[j])
        for ch in re.sub(r"//.*$", "", code):
            if ch == "(":
                depth, seen = depth + 1, True
            elif ch == ")":
                depth -= 1
        if seen and depth <= 0:
            return j + 1
    return start


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
    return scan(lang, path, text, added, whole)


def scan(lang, path, text, added, whole):
    lines = text.split("\n")
    out, n, seen, spans = [], 0, set(), []
    for name, ln in ti.cases(lang, mask_comments(text) if lang in BRACES else text):
        if ln in seen:
            continue
        seen.add(ln)
        spans.append((name, ln) + body_span(lang, lines, ln))
    bodies = ["\n".join(lines[a - 1:b]) for _, _, a, b in spans]
    for k, (name, ln, a, b) in enumerate(spans):
        if not whole and not any(a <= x <= b for x in added):
            continue
        n += 1
        kind = classify(lang, lines[a - 1:b])
        if kind:
            row = {"kind": kind, "file": path, "line": ln, "case": name, "message": MESSAGES[kind] % name}
            tag = precedent(lang, bodies[k], bodies[:k] + bodies[k + 1:]) if kind == "weak-oracle" else None
            if tag:
                row["precedent"] = tag
            out.append(row)
    return out, n


def self_test():
    """Synthetic files through scan(); every case below is a regression a real repo produced."""
    js = """import { it, expect } from 'vitest';
/**
 * Only the owner edits it (`SectionGuideDialog.tsx`) — a docblock, not a case.
 */
// it('is a comment, not a case', () => {})
const glob = 'src/**/*.ts'; it('reads a glob string', () => { expect(glob).toEqual('src/**/*.ts'); });
it.each([[1, 2]])('adds %i', (a, b) =>
  expect(a + 1).toBe(b),
);
it('sends nothing when the cart is empty', () => {
  expect(send).not.toHaveBeenCalled();
});
it('calls send', () => {
  expect(send).toHaveBeenCalled();
});
it('refuses a stranger', async () => {
  await request(app).get('/api/v1/orders/1').expect(403);
});
it('lists orders', async () => {
  await request(app).get('/api/v1/orders').expect(200);
});
it('lists orders with their totals', async () => {
  const res = await request(app).get('/api/v1/orders');
  expect(res.body).toEqual([{ id: 1 }]);
});
it('lists refunds', async () => {
  await request(app).get('/api/v1/refunds').expect(200);
});
it('does nothing', () => {
  run();
});
it('is always true', () => { expect(true).toBe(true); });
"""
    rows, n = scan("js", "x.test.ts", js, set(), True)
    got = {r["case"]: (r["kind"], r.get("precedent")) for r in rows}
    names = {c for c, _ in ti.cases("js", mask_comments(js))}
    want_names = {"reads a glob string", "adds %i", "sends nothing when the cart is empty", "calls send", "refuses a stranger",
                  "lists orders", "lists orders with their totals", "lists refunds", "does nothing", "is always true"}
    want = {"calls send": ("weak-oracle", None), "refuses a stranger": ("weak-oracle", "§16 status-4xx"),
            "lists orders": ("weak-oracle", "§16 2xx-paired"), "lists refunds": ("weak-oracle", "§16 2xx-unpaired"),
            "does nothing": ("no-assertion", None), "is always true": ("tautology", None)}
    checks = [
        (n == 10 and names == want_names, "10 cases: the docblock `it (` and the `// it(` line are not cases (got %d: %s)" % (n, sorted(names ^ want_names))),
        ("adds %i" not in got, "an arrow it.each body over two lines holds its expect (got %s)" % got.get("adds %i")),
        ("sends nothing when the cart is empty" not in got, "not.toHaveBeenCalled() alone is an oracle (§ 20)"),
        ("reads a glob string" not in got, "a `/*` inside a string is not a comment"),
    ] + [(got.get(k) == v, "%s → %s (got %s)" % (k, v, got.get(k))) for k, v in want.items()]
    fails = [m for ok, m in checks if not ok]
    for m in fails:
        print("FAIL  " + m)
    print("oracle-check self-test: %d/%d passed" % (len(checks) - len(fails), len(checks)))
    return 1 if fails else 0


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    flags = {a for a in argv if a.startswith("--") and "=" not in a}
    if (set(opts) - {"base", "head", "repo", "files"}) or (flags - {"--json", "--all"}) or any(not a.startswith("--") for a in argv):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
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
                    got, n = scan(lang, path, content, lines, "--all" in flags)
                    findings += got
                    checked += n
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
            print("  %-13s %s:%s — %s%s" % (f["kind"], f["file"], f["line"], f["message"],
                                          "  [%s]" % f["precedent"] if f.get("precedent") else ""))
        print("summary: %d finding(s)" % len(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
