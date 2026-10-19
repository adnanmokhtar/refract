#!/usr/bin/env python3
"""lint-fixture-leakage.py — shipped text may not name a benchmark fixture's seeded specifics.

WHY. Phase-6 benchmark runs (2026-10-19) found code-quality's error-handling-scan and
correctness-smell-scan, and frontend's client-data-scan, teaching their lesson with the
review-decoys fixture's own answer key: the seeded file and line (`refunds.ts:28`,
`useRefund.ts:9`), the seeded function (`notifyCustomer`). A detector that carries the answer
scores the benchmark by recognition, not by detection, and every recall number measured with it is
inflated. The fixtures exist to measure the skills; the skills must not know them.

VOCABULARY, built from every benchmarks/fixtures/<name>/:
  line   a seeded file's basename followed by a line number (`refunds.ts:28`) — DEFECTS.md `file:`;
  path   a seeded file's fixture-relative path with 3+ segments (`src/orders/refunds.ts`), stage
         prefixes (change/, base/, v1/, …) removed;
  base   a distinctive file basename anywhere in a fixture: a compound stem of 8+ characters
         (`useRefund.ts`, `export-carrier.ts`) present in fewer than 3 fixtures;
  ident  a compound identifier (8+ characters, camelCase or snake_case) on a seeded `anchor:` line
         that the fixture itself declares and no other fixture declares (`notifyCustomer`).
ALLOWED: a fixture's NAME (`On \\`stale-knowledge\\`: 55/59` is a measurement, not leakage), the
words in ALLOW below (generic names a fixture happens to share with real code), benchmarks/
itself, CHANGELOGs, and templates/packs/*/evals/ (eval cases are fixture copies by design, checked
byte-for-byte by lint-pack-evals.py).

RATCHET. The skills were written from the fixtures, so legacy hits exist (2026-10-19). They live per
file in scripts/_fixture-leakage-baseline.txt and may only shrink: a new file with a hit, or a file
whose count grows, fails; a file that shrank fails until --record locks the lower count in.

Usage:  lint-fixture-leakage.py [--self-test] [--quiet] [--list] [--record] [--repo-root=<dir>]
Exit:   1 on a new or grown leak (--list: on any hit); 0 otherwise. --self-test seeds a fixture + a skill that cites it (must FAIL),
        then the genericized skill (must PASS).
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict

# Generic names a fixture shares with ordinary code: flagging them would flag the language, not
# the fixture. Add a word only when it is a library/framework name or plain English.
ALLOW = {
    "LedgerLine", "supabaseAdmin",  # detector-regex vocabulary (ledger-scan, llm-trust-scan), not fixture echoes
    "docker-compose.yml", "docker-compose.yaml", "pnpm-workspace.yaml", "pnpm-lock.yaml",
    "package-lock.json", "tsconfig.base.json", "eslint.config.mjs", "eslint.config.js",
    "stylelint.config.mjs", "vite.config.ts", "vitest.config.ts", "jest.config.js",
    "next.config.js", "next.config.mjs", "playwright.config.ts", "tailwind.config.ts",
    "requirements.txt", "eslint-suppressions.json", "release-please-config.json",
    "compose.override.yaml", "bitbucket-pipelines.yml", "azure-pipelines.yml",
    "Jenkinsfile.groovy", "dependabot.yml", "mkdocs.yml", "cucumber.js", "opencode.json",
    "pyproject.toml", "setup.cfg", "settings.gradle", "build.gradle.kts", "settings.py",
    "api-client.ts", "apiClient.ts", "http-client.ts", "httpClient.ts",
    "AndroidManifest.xml", "PrivacyInfo.xcprivacy", "GoogleService-Info.plist", "Info.plist",
    "dbt_project.yml", "nest-cli.json", "values-prod.yaml", "values.yaml", "copilot-instructions.md",
    "AGENTS.md", "CLAUDE.md", "CONTRIBUTING.md", "README.md", "SECURITY.md", ".dependency-cruiser.cjs",
    "useEffect", "useState", "useCallback", "useMemo", "useQuery", "useMutation",
    "handleSubmit", "onSubmit", "getServerSideProps", "createServer", "createClient",
    # framework APIs, design-system component names and plain domain verbs/nouns a real codebase
    # writes without having seen any fixture (measured 2026-10-19: each appears across many packs):
    "trackEvent", "IconButton", "searchParams", "filePath", "accessToken", "onBackPressed", "DataTable",
    "retryAfter", "OrderRepository", "sendEmail", "ErrorState", "withTransaction", "catchError", "daysLeft",
    "OrderEvent", "cancelOrder", "deleteOrder", "periodEnd", "periodStart", "hasFeature", "errorText",
    "authorizationUrl", "enableProguardInReleaseBuilds", "CreditNote", "useDebounce", "removeItem", "onScroll",
    "getByName", "currentPlan", "applyDiscount", "amountOff", "CartContext", "CartSummary", "totalMinor",
    "taxMinor", "verifyWebhookSignature", "CreateOrderUseCase", "withTenant", "BillingError", "LedgerError",
}
STAGE = re.compile(r"^(?:change|base|v1|v2|solution|wrong/[^/]+|holdout|clean-overlay|noise)/")
DECL = re.compile(r"\b(?:function\*?|class|interface|type|enum|def|func|fun|const|let|var|struct|trait|module)\s+"
                  r"(?:\([^)]*\)\s*)?([A-Za-z_][A-Za-z0-9_]*)")
METH = re.compile(r"^\s*(?:(?:public|private|protected|static|async|export|override|readonly)\s+)*"
                  r"([a-z][A-Za-z0-9_]*)\s*\([^)]*\)\s*(?::[^{=]*)?\{")
# A fixture shaped like an installed project stages Refract's own knowledge files (ai/, .claude/, the
# tool-adapter files): their names are Refract's vocabulary, not the fixture's.
KNOWLEDGE = re.compile(r"(^|/)(ai|\.claude|\.cursor|\.opencode|\.windsurf|\.github/(copilot|instructions))(/|-)|"
                       r"(^|/)(CLAUDE|AGENTS|GEMINI)\.md$")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
TOKEN = re.compile(r"[A-Za-z0-9_][\w.\-/]*(?::\d+)?")
BASELINE = "scripts/_fixture-leakage-baseline.txt"
TEXT_EXT = {".md", ".txt", ".json", ".yaml", ".yml", ".sh", ".py", ".jq", ".awk", ".toml", ".mjs", ".js", ".ts"}


def compound(stem):
    return len(stem) >= 8 and bool(re.search(r"[a-z][A-Z]", stem) or re.search(r"[a-z0-9][-_][a-z]", stem))


def read(p):
    try:
        with open(p, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def own_names(root):
    """Basenames Refract itself ships (ai/ knowledge files, hooks, commands): a fixture that contains
    them is shaped like an installed project, and naming them is Refract talking about itself."""
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard",
                          "templates", "commands", "scripts", "agents", "hooks"],
                         cwd=root, capture_output=True, text=True).stdout.split("\n")
    return {os.path.basename(x) for x in out if x}


def vocabulary(fx_root, own=frozenset()):
    fixtures = sorted(d for d in os.listdir(fx_root) if os.path.isdir(os.path.join(fx_root, d)))
    decls, bases, own_staged = {}, {}, set()
    for f in fixtures:
        d, b = set(), set()
        for dp, _dn, fn in os.walk(os.path.join(fx_root, f)):
            for n in fn:
                if n == "DEFECTS.md":
                    continue
                if KNOWLEDGE.search(os.path.relpath(os.path.join(dp, n), os.path.join(fx_root, f))):
                    own_staged.add(n)
                    continue
                b.add(n)
                t = read(os.path.join(dp, n))
                if t is None:
                    continue
                for line in t.split("\n"):
                    d.update(m.group(1) for m in DECL.finditer(line))
                    m = METH.match(line)
                    if m:
                        d.add(m.group(1))
        decls[f], bases[f] = d, b
    dcount = Counter(w for f in fixtures for w in decls[f])
    bcount = Counter(n for f in fixtures for n in bases[f])
    line_v, path_v, base_v, ident_v = {}, {}, {}, {}
    generic = lambda n: n in ALLOW or n in own or n in own_staged or bcount[n] >= 3
    for f in fixtures:
        for n in bases[f]:
            stem = n.rsplit(".", 1)[0]
            if compound(stem) and not generic(n):
                base_v.setdefault(n, f)
        t = read(os.path.join(fx_root, f, "DEFECTS.md")) or ""
        for blk in re.findall(r"```defect\n(.*?)```", t, re.S):
            kv = dict(re.findall(r"^(\w+):\s*(.*)$", blk, re.M))
            rel = STAGE.sub("", kv.get("file", "").strip())
            if rel and not KNOWLEDGE.search(rel):
                bn = os.path.basename(rel)
                if not generic(bn):
                    line_v.setdefault(bn, (f, set()))[1].add("/".join(rel.split("/")[-2:]))
                    if rel.count("/") >= 2:
                        path_v.setdefault(rel, f)
            for w in IDENT.findall(kv.get("anchor", "")):
                if compound(w) and w in decls[f] and dcount[w] == 1 and w not in ALLOW:
                    ident_v.setdefault(w, f)
    return line_v, path_v, base_v, ident_v


def scan(root, quiet=False, mode="check"):
    fx_root = os.path.join(root, "benchmarks", "fixtures")
    if not os.path.isdir(fx_root):
        print("lint-fixture-leakage: REFUSED — no benchmarks/fixtures under %s" % root)
        return 2
    line_v, path_v, base_v, ident_v = vocabulary(fx_root, own_names(root))
    if not (line_v and ident_v):
        print("lint-fixture-leakage: REFUSED — empty vocabulary (DEFECTS.md format changed?)")
        return 2
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "templates", "commands"],
                         cwd=root, capture_output=True, text=True).stdout.split("\n")
    hits = []
    for rel in out:
        if not rel or "CHANGELOG" in rel or re.search(r"(^|/)evals/", rel) or os.path.splitext(rel)[1] not in TEXT_EXT:
            continue
        t = read(os.path.join(root, rel))
        if t is None:
            continue
        for n, line in enumerate(t.split("\n"), 1):
            for m in TOKEN.finditer(line):
                tok = m.group(0).rstrip(".-/")
                lm = re.match(r"^(.*?):(\d+)$", tok)
                name = lm.group(1) if lm else tok
                bn = name.rsplit("/", 1)[-1]
                if lm and bn in line_v:
                    fx, tails = line_v[bn]
                    # a short plain stem (`export.ts:1`, `list.ts:18`) is anyone's file: it counts only
                    # with the seeded parent directory (`orders/list.ts:18`)
                    stem = bn.rsplit(".", 1)[0]
                    if compound(stem) or len(stem) >= 7 or "/".join(name.split("/")[-2:]) in tails:
                        hits.append((rel, n, "line", tok, fx))
                        continue
                segs = name.split("/")
                p = next(("/".join(segs[i:]) for i in range(len(segs) - 2) if "/".join(segs[i:]) in path_v), None)
                if p:
                    hits.append((rel, n, "path", name, path_v[p]))
                    continue
                if bn in base_v:
                    hits.append((rel, n, "base", bn, base_v[bn]))
                    continue
            for w in set(IDENT.findall(line)):
                if w in ident_v:
                    hits.append((rel, n, "ident", w, ident_v[w]))
    per = Counter(h[0] for h in hits)
    bpath = os.path.join(root, BASELINE)
    if mode == "list":
        for rel, n, kind, tok, fx in hits:
            print("  %s:%d  [%s] %s  (benchmarks/fixtures/%s)" % (rel, n, kind, tok, fx))
        print("fixture-leakage: %d hit(s) in %d file(s)" % (len(hits), len(per)))
        return 1 if hits else 0
    if mode == "record":
        with open(bpath, "w") as fh:
            fh.write("# Fixture-specific names still in shipped text, per file, counted by scripts/lint-fixture-leakage.py.\n"
                     "# May only shrink. Regenerate after genericizing a file (never to admit a new one):\n"
                     "#   python3 scripts/lint-fixture-leakage.py --record\n")
            for rel in sorted(per):
                fh.write("%s\t%d\n" % (rel, per[rel]))
        print("recorded %d file(s), %d hit(s) -> %s" % (len(per), len(hits), BASELINE))
        return 0
    base = {}
    if os.path.exists(bpath):
        for line in open(bpath, encoding="utf-8"):
            if line.strip() and not line.startswith("#"):
                f, c = line.rstrip("\n").split("\t")
                base[f] = int(c)
    grown = sorted(f for f in per if per[f] > base.get(f, 0))
    shrunk = sorted(f for f in base if per.get(f, 0) < base[f])
    if grown:
        print("FAIL — fixture-specific names in shipped text (a skill that carries the answer key scores the benchmark "
              "by recognition). Genericize: same lesson, neutral file, path and function names:")
        for rel, n, kind, tok, fx in hits:
            if rel in grown:
                print("  %s:%d  [%s] %s  (benchmarks/fixtures/%s)" % (rel, n, kind, tok, fx))
        for f in grown:
            print("  %s: %d hit(s), baseline %d" % (f, per[f], base.get(f, 0)))
        return 1
    if shrunk:
        print("FAIL — genericized, but %s still admits the old count (re-record so it cannot come back):" % BASELINE)
        for f in shrunk:
            print("  %s: baseline %d, now %d" % (f, base[f], per.get(f, 0)))
        print("  python3 scripts/lint-fixture-leakage.py --record")
        return 1
    if not quiet:
        print("fixture-leakage: no new leak (%d legacy hit(s) in %d file(s) ratcheted; vocabulary %d line, %d path, "
              "%d base, %d ident terms)" % (len(hits), len(per), len(line_v), len(path_v), len(base_v), len(ident_v)))
    return 0


def self_test():
    td = tempfile.mkdtemp(prefix="leak-selftest.")
    try:
        fx = os.path.join(td, "benchmarks", "fixtures", "demo-fx", "change", "src", "orders")
        os.makedirs(fx)
        with open(os.path.join(fx, "refunds.ts"), "w") as fh:
            fh.write("export async function settleLedgerRefund(id: string) {\n  postLedgerEntry(id);\n}\n"
                     "function postLedgerEntry(id: string) { return id; }\n")
        os.makedirs(os.path.join(td, "benchmarks", "fixtures", "demo-fx", "change", "web"))
        with open(os.path.join(td, "benchmarks", "fixtures", "demo-fx", "change", "web", "useLedgerRefund.ts"), "w") as fh:
            fh.write("export const x = 1;\n")
        with open(os.path.join(td, "benchmarks", "fixtures", "demo-fx", "DEFECTS.md"), "w") as fh:
            fh.write("```defect\nid: D-1\nfile: change/src/orders/refunds.ts\nline: 2\nanchor:   postLedgerEntry(id);\n```\n")
        sk = os.path.join(td, "templates", "packs", "demo", "skills", "x")
        os.makedirs(sk)
        os.makedirs(os.path.join(td, "scripts"))
        skill = os.path.join(sk, "SKILL.md")
        with open(skill, "w") as fh:
            fh.write("BAD: refunds.ts:2 calls postLedgerEntry(id) unawaited (see src/orders/refunds.ts, useLedgerRefund.ts)\n"
                     "Measured on `demo-fx`: 1/1.\n")
        subprocess.run(["git", "init", "-q", td], check=True)
        subprocess.run(["git", "-C", td, "add", "-A"], check=True)
        devnull = open(os.devnull, "w")
        old = sys.stdout
        sys.stdout = devnull
        try:
            rc_bad = scan(td)
        finally:
            sys.stdout = old
        if rc_bad != 1:
            print("SELF-TEST FAIL — seeded leak must exit 1, got %s" % rc_bad)
            return 1
        line_v, path_v, base_v, ident_v = vocabulary(os.path.join(td, "benchmarks", "fixtures"))
        want = ("refunds.ts" in line_v and "src/orders/refunds.ts" in path_v and "useLedgerRefund.ts" in base_v
                and "postLedgerEntry" in ident_v)
        if not want:
            print("SELF-TEST FAIL — vocabulary missed a seeded term: %r" % ((line_v, path_v, base_v, ident_v),))
            return 1
        with open(skill, "w") as fh:
            fh.write("BAD: payments.ts:14 calls sendReceipt(id) unawaited (a fire-and-forget side effect)\n"
                     "Measured on `demo-fx`: 1/1.\n")
        sys.stdout = devnull
        try:
            rc_good = scan(td)
        finally:
            sys.stdout = old
        if rc_good != 0:
            print("SELF-TEST FAIL — genericized text (fixture NAME kept) must pass, got %s" % rc_good)
            return 1
        # The ratchet: a recorded legacy hit passes, a new one fails, a fixed one must be re-recorded.
        def run(mode="check"):
            sys.stdout = devnull
            try:
                return scan(td, mode=mode)
            finally:
                sys.stdout = old
        with open(skill, "w") as fh:
            fh.write("BAD: refunds.ts:2 calls sendReceipt(id) unawaited\n")
        subprocess.run(["git", "-C", td, "add", "-A"], check=True)
        steps = [("record", run("record"), 0), ("legacy hit admitted", run(), 0)]
        with open(skill, "a") as fh:
            fh.write("and postLedgerEntry(id)\n")
        steps.append(("grown file FAILS", run(), 1))
        with open(skill, "w") as fh:
            fh.write("BAD: payments.ts:14 calls sendReceipt(id) unawaited\n")
        steps.append(("shrunk but not re-recorded FAILS", run(), 1))
        steps.append(("re-record", run("record"), 0))
        steps.append(("clean after re-record", run(), 0))
        bad = [n for n, got, want in steps if got != want]
        if bad:
            print("SELF-TEST FAIL — ratchet: %s" % ", ".join(bad))
            return 1
        print("self-test: pass (4 seeded term kinds FAIL; neutral names + fixture name PASS; ratchet admits, "
              "blocks growth, forces re-record)")
        return 0
    finally:
        shutil.rmtree(td, ignore_errors=True)


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    quiet, mode = False, "check"
    for a in argv:
        if a == "--self-test":
            return self_test()
        if a == "--quiet":
            quiet = True
        elif a in ("--record", "--list"):
            mode = a[2:]
        elif a.startswith("--repo-root="):
            root = a.split("=", 1)[1]
        else:
            print("unknown arg: %s" % a, file=sys.stderr)
            return 2
    return scan(root, quiet, mode)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
