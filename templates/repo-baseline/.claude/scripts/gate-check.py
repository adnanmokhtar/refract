#!/usr/bin/env python3
"""gate-check.py — the gates that decide "done", run by a script instead of remembered by a model.

Usage:  gate-check.py [--local | --ci] [--base=<ref>] [--repo=<dir>] [--only=G1,G7]
                      [--mode=shadow|warn|block] [--json] [--hook-json] [--no-evidence]
Exit:   0  no gate in `block` mode FAILed — shadow and warn results are printed, never fatal
        2  a `block` gate FAILed; or, in --local, G1 could not run because the heavy-test lane
           stayed busy (the one UNVERIFIED the agent can resolve itself — see run_g1)
        1  usage error, or not inside a git work tree

WHY. The Stop hook this replaces blocked on red tests alone, knew six ecosystems and exited 0
when it found no runner: a session could end "done" with a red typecheck, a deleted test or a key
in the diff. A model can hold every standard in context and still skip one; a script cannot.

SCOPE.  --local (default; what verify-gate.sh runs at Stop): the files this change touched —
        everything since the merge-base with the default branch, plus staged, unstaged and
        untracked work. Tests go through .claude/hooks/test-lane.sh when it is installed, and the
        agent's own green lane run on exactly this tree is accepted instead of repeated.
        --ci: base..HEAD in a clean checkout; the full suite runs directly.

GATES (v2). Verdicts: PASS · FAIL · UNVERIFIED (could not be checked — never PASS) · N-A (reason).
  G0  acceptance-lock every run contract in this change (ai/runs/<run>/acceptance.json) is locked, and
                      it and every test it names still hash to .claude/locks/<run>.json
  G1  tests           the project's own suite; runner detected per stack (detect_runner)
  G1  acceptance      INFERENTIAL — the verifier's verdict.json for each run contract: present, valid,
                      signed by a judge (stamped by persist-verdict.sh), fresh, and PASS
  G2  test-integrity  test-integrity.py beside this file
  G2  oracle          oracle-check.py: new / changed test cases that assert nothing, or nothing that
                      could fail (QG-15)
  G3  secrets         gitleaks over base..HEAD in --ci when installed, else the shipped
                      secret-scan.sh hook over every added line; RAN or SKIPPED is recorded
  G4  perf            behavior-diff.py --gate=G4: each performance baseline entry in the touched scope,
                      base (a worktree at the merge-base) and HEAD measured INTERLEAVED by
                      perf-compare.py against THR-PERF-REGRESSION. CI only — --local reports N-A unless
                      REFRACT_G4_LOCAL=1 (ten interleaved pairs per entry is not a Stop-hook cost)
  G7  lint · typecheck · standards — the configured linter and type checker over the touched
                      files; standards-check.py --json beside this file
  G7  review          INFERENTIAL — persisted reviews (ai/runs/<run>/reviews/*.json) and the verifier's
                      refute verdict: fresh, and no confirmed IMPORTANT finding standing
  G12 state-matrix    state-matrix-lint.py (ui-ux pack, .claude/skills/state-matrix/scripts/) over each run in
                      the change: every touched UI surface has a row for each THR-UI-STATES state, n-a with a
                      reason or proved by a story or test that exists. Lint not installed: N-A with no UI run,
                      UNVERIFIED with one. Its inferential half is @ux-reviewer's persisted review (G7 review)
  G14 behaviour       behavior-diff.py: every behavioural baseline entry (.claude/baselines/) whose scope
                      the change touched, re-run at HEAD and compared with the base side; a difference no
                      acceptance criterion declares (`changes_baseline`) FAILs, and so does a T2/T3 run
                      whose modified source no entry covers. --local: quick kinds; --ci: every kind
  G15 trailer         every commit in base..HEAD carries `Assisted-by:` or `Co-Authored-By:`
  G15 signer          every inferential record was stamped by its hook, and its signer is not among
                      the agents that authored the change it judged

INFERENTIAL RECORDS bind to the change they judged: refract_records.py stamps each with the blob hash
of every path the change touched. If code changes after a review, the record is STALE, and a stale
record is a FAIL — the review was of a different change. New inferential gates ship in shadow mode
and earn warn, then block (.claude/gates.json); the deterministic lock check ships in block.

MODES. Per check, from .claude/gates.json: shadow (record only) · warn (record + print) · block
(record + print + exit 2 on FAIL). --mode= overrides every check; CI v1 runs --mode=shadow.

WHY gates.json AND NOT gates.yaml. The standard library parses JSON, not YAML, and PyYAML is not
guaranteed. A hand-rolled "tiny YAML subset" parser fails SILENTLY — an inline comment, a quoted
value or a tab misread flips a gate from block to shadow and nothing says so. A JSON syntax error
is loud: this script reports it and runs the documented v1 defaults.

EVIDENCE. .claude/evidence/<HEAD sha>/<gate>-<check>.json, one record per check,
shaped by Refract's templates/schemas/refract/evidence.schema.json. The directory gets a
.gitignore of `*` on first write: an untracked record would change the tree fingerprint that
test-lane.sh verifies a green run against, and every later stop would re-run the whole suite.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
# No __pycache__ in the project: an untracked .claude/scripts/__pycache__/ changes the tree
# fingerprint test-lane.sh verifies a green run against, so importing refract_records would void
# the agent's own green run and make every Stop re-run the suite. Measured, by the fixture
# `green-lane-run-is-accepted`.
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
try:
    import refract_records as rr
except ImportError:          # an older install: the inferential gates report UNVERIFIED, nothing else changes
    rr = None
VERSION = "2"
CHECKS = [("G0", "acceptance-lock"), ("G1", "tests"), ("G1", "acceptance"), ("G2", "test-integrity"),
          ("G2", "oracle"), ("G3", "secrets"), ("G4", "perf"), ("G7", "lint"), ("G7", "typecheck"), ("G7", "standards"),
          ("G7", "review"), ("G12", "state-matrix"), ("G14", "behaviour"), ("G15", "trailer"), ("G15", "signer")]
DEFAULTS = {"G0": {"acceptance-lock": "block"}, "G1": {"tests": "block", "acceptance": "shadow"},
            "G2": {"test-integrity": "warn", "oracle": "shadow"}, "G3": {"secrets": "block"},
            "G4": {"perf": "shadow"},
            "G7": {"lint": "block", "typecheck": "block", "standards": "warn", "review": "shadow"},
            "G12": {"state-matrix": "shadow"},
            "G14": {"behaviour": "shadow"},
            "G15": {"trailer": "shadow", "signer": "shadow"}}
INFERENTIAL = {("G1", "acceptance"), ("G7", "review")}
MODES = ("shadow", "warn", "block")
TIMEOUT = int(os.environ.get("REFRACT_GATE_TIMEOUT", "540"))
JS = (".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".vue", ".svelte")
CITE = re.compile(r"(?m)^\s*(?:\S+\s+)?([\w./@+-]+\.[A-Za-z0-9]+)[:(](\d+)")


def run(cmd, cwd, timeout=None, env=None, stdin=None):
    """-> (exit code, or None when it could not start or timed out; stdout; stderr)"""
    # Never inherit stdin: under a Stop hook it carries Claude Code's payload, not input for a test runner.
    feed = {"input": stdin} if stdin is not None else {"stdin": subprocess.DEVNULL}
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors="replace", timeout=timeout,
                           env=dict(os.environ, **(env or {})), shell=isinstance(cmd, str),
                           executable="/bin/bash" if isinstance(cmd, str) else None, **feed)
    except (OSError, subprocess.TimeoutExpired) as e:
        return None, "", str(e)
    return r.returncode, r.stdout or "", r.stderr or ""


def git(repo, *args):
    rc, out, _ = run(["git", "-c", "core.quotepath=false"] + list(args), repo)
    return out.strip() if rc == 0 else None


class Ctx:
    def __init__(self, repo, scope, want_base):
        self.repo, self.scope = repo, scope
        self.head = git(repo, "rev-parse", "--verify", "-q", "HEAD")
        self.base = self.resolve_base(want_base)
        rng = [self.base] + (["HEAD"] if scope == "ci" else []) if self.base else []
        changed = (git(repo, "diff", "--name-only", "--diff-filter=d", *rng) or "").splitlines() if rng else []
        self.untracked = [] if scope == "ci" else (git(repo, "ls-files", "-o", "--exclude-standard") or "").splitlines()
        self.touched = sorted({p for p in changed + self.untracked if p})
        self.dirty = bool(git(repo, "status", "--porcelain"))
        h = hashlib.sha256((self.head or "unborn").encode())
        h.update(subprocess.run(["git", "-C", repo, "diff", "HEAD", "--binary"], capture_output=True).stdout)
        for p in self.untracked:
            fp = os.path.join(repo, p)
            if os.path.isfile(fp):
                h.update(p.encode() + open(fp, "rb").read())
        self.tree = h.hexdigest()

    def resolve_base(self, want):
        if not self.head:
            return None
        cands = [want] if want else []
        env = os.environ
        if env.get("GITHUB_BASE_REF"):
            cands.append("origin/" + env["GITHUB_BASE_REF"])
        cands += [env.get("CI_MERGE_REQUEST_DIFF_BASE_SHA", ""), "origin/HEAD", "origin/main",
                  "origin/master", "main", "master"]
        for c in filter(None, cands):
            mb = git(self.repo, "merge-base", "HEAD", c)
            if mb:
                return mb
            if c == want:
                print("gate-check: --base=%s does not resolve here — using the default base" % want, file=sys.stderr)
        return self.head


def rec(gate, check, verdict, reason=None, execution="RAN", tool=None, command=None, rc=None,
        out="", findings=None):
    return {"gate": gate, "check": check, "verdict": verdict, "execution": execution, "reason": reason,
            "producer": "computational", "tool": tool, "command": command, "exit_code": rc,
            "output_sha256": hashlib.sha256(out.encode()).hexdigest() if out else None,
            "output_tail": "\n".join(out.rstrip().split("\n")[-60:])[-6000:] if out else None,
            "findings": findings or []}


def cite(out, limit=30):
    seen, res = set(), []
    for m in CITE.finditer(out):
        key = (m.group(1), int(m.group(2)))
        if key not in seen and len(res) < limit:
            seen.add(key)
            res.append({"file": key[0], "line": key[1], "message": out[m.start():].split("\n", 1)[0].strip()[:200]})
    return res


# ── G1 tests ───────────────────────────────────────────────────────────────────────────────────
def read(repo, p):
    fp = os.path.join(repo, p)
    return open(fp, encoding="utf-8", errors="replace").read() if os.path.isfile(fp) else ""


def has(repo, *paths):
    return any(os.path.exists(os.path.join(repo, p)) for p in paths)


def detect_runner(repo):
    """-> (command, None) or (None, why). First match wins: the most specific manifest first."""
    ex = lambda *ps: has(repo, *ps)
    need = lambda b, cmd, what: (cmd, None) if shutil.which(b) else (None, "%s declares the suite but `%s` is not installed" % (what, b))
    scripts = scripts_of(repo)
    if scripts.get("test") and "no test specified" not in scripts["test"]:
        for lock, pm, cmd in (("bun.lockb", "bun", "bun run test"), ("bun.lock", "bun", "bun run test"),
                              ("pnpm-lock.yaml", "pnpm", "pnpm test"), ("yarn.lock", "yarn", "yarn test")):
            if ex(lock):
                return need(pm, cmd, "package.json")
        return need("npm", "npm test --silent", "package.json")
    if ex("gradlew"):
        return ("./gradlew test --quiet" if os.access(os.path.join(repo, "gradlew"), os.X_OK) else "sh ./gradlew test --quiet"), None
    if ex("build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"):
        return need("gradle", "gradle test --quiet", "build.gradle")
    if ex("mvnw"):
        return ("./mvnw -q test" if os.access(os.path.join(repo, "mvnw"), os.X_OK) else "sh ./mvnw -q test"), None
    if ex("pom.xml"):
        return need("mvn", "mvn -q test", "pom.xml")
    if any(f.endswith((".sln", ".csproj", ".fsproj")) for f in os.listdir(repo)):
        return need("dotnet", "dotnet test", "a .NET solution/project")
    if ex("pubspec.yaml"):
        flutter = re.search(r"(?m)^\s*sdk:\s*flutter\b|^flutter:", read(repo, "pubspec.yaml"))
        return need("flutter", "flutter test", "pubspec.yaml (Flutter)") if flutter else need("dart", "dart test", "pubspec.yaml")
    if ex("Package.swift"):
        return need("swift", "swift test", "Package.swift")
    if ex("Cargo.toml"):
        return need("cargo", "cargo test --quiet", "Cargo.toml")
    if ex("go.mod"):
        return need("go", "go test ./...", "go.mod")
    if ex("Gemfile") and ex("spec", ".rspec"):
        return ("bundle exec rspec", None) if shutil.which("bundle") else need("rspec", "rspec", "Gemfile + spec/")
    if ex("composer.json", "phpunit.xml", "phpunit.xml.dist"):
        for b in ("vendor/bin/pest", "vendor/bin/phpunit"):
            if ex(b):
                return b, None
        return need("phpunit", "phpunit", "composer.json / phpunit.xml")
    if ex("mix.exs"):
        return need("mix", "mix test", "mix.exs")
    if ex("pyproject.toml", "pytest.ini", "setup.cfg", "tox.ini", "setup.py", "conftest.py"):
        if shutil.which("pytest"):
            return "pytest -q", None
        if run([sys.executable, "-c", "import pytest"], repo)[0] == 0:
            return "python3 -m pytest -q", None
        return None, "a Python manifest declares the project but pytest is not installed"
    return None, ("no test runner detected — looked for a package.json test script, Gradle, Maven, .NET, "
                  "Flutter/Dart, SwiftPM, Cargo, Go, RSpec, PHPUnit/Pest, Mix and pytest")


def run_g1(ctx):
    cmd, why = detect_runner(ctx.repo)
    if not cmd:
        return rec("G1", "tests", "UNVERIFIED", why, execution="SKIPPED")
    lane = os.path.join(ctx.repo, ".claude", "hooks", "test-lane.sh")
    if ctx.scope == "local" and os.path.isfile(lane) and not os.path.exists(os.path.join(ctx.repo, ".claude", ".no-test-lane")):
        if run(["bash", lane, "verified", cmd], ctx.repo)[0] == 0:
            return rec("G1", "tests", "PASS", "the agent's own green run of `%s` through test-lane.sh, on exactly "
                       "this tree" % cmd, tool="test-lane.sh verified", command=cmd, rc=0)
        rc, out, err = run(["bash", lane, "run", cmd], ctx.repo, timeout=TIMEOUT,
                           env={"CLAUDE_TEST_LANE_WAIT": os.environ.get("CLAUDE_VERIFY_GATE_WAIT", "240")})
        if rc == 75:
            return rec("G1", "tests", "UNVERIFIED", "lane-busy: the heavy-test lane stayed busy, so the suite did "
                       "not run. Run it through the lane in the background, then stop once it is green — this "
                       "gate accepts that run instead of repeating it:  \"%s\" run '%s'" % (lane, cmd),
                       execution="SKIPPED", command=cmd, out=err)
        tool = "test-lane.sh run"
    else:
        rc, out, err = run(cmd, ctx.repo, timeout=None if ctx.scope == "ci" else TIMEOUT)
        tool = cmd.split()[0]
    if rc is None:
        return rec("G1", "tests", "UNVERIFIED", "`%s` did not finish: %s" % (cmd, err[:200]), execution="SKIPPED", command=cmd)
    if rc == 5 and "pytest" in cmd:          # pytest's own code for "collected no tests": nothing was verified
        return rec("G1", "tests", "UNVERIFIED", "`%s` collected no tests" % cmd, tool=tool, command=cmd, rc=rc, out=out + err)
    return rec("G1", "tests", "PASS" if rc == 0 else "FAIL", None if rc == 0 else "`%s` exited %d" % (cmd, rc),
               tool=tool, command=cmd, rc=rc, out=out + err, findings=cite(out + err) if rc else [])


# ── G2 test integrity ──────────────────────────────────────────────────────────────────────────
def run_g2(ctx):
    ti = os.path.join(HERE, "test-integrity.py")
    if not os.path.isfile(ti):
        return rec("G2", "test-integrity", "UNVERIFIED", "test-integrity.py is not installed beside gate-check.py", "SKIPPED")
    if not ctx.base:
        return rec("G2", "test-integrity", "N-A", "no commit to compare against (unborn branch)")
    cmd = [sys.executable, ti, "--repo=" + ctx.repo, "--base=" + ctx.base, "--json"] + (["--head=HEAD"] if ctx.scope == "ci" else [])
    rc, out, err = run(cmd, ctx.repo, timeout=TIMEOUT)
    shown = ".claude/scripts/test-integrity.py --base=%s%s" % (ctx.base[:12], " --head=HEAD" if ctx.scope == "ci" else "")
    if rc not in (0, 1):
        return rec("G2", "test-integrity", "UNVERIFIED", "test-integrity.py failed: %s" % err.strip()[:200], "SKIPPED", command=shown, rc=rc)
    found = json.loads(out).get("findings", [])
    return rec("G2", "test-integrity", "FAIL" if found else "PASS", "%d finding(s)" % len(found) if found else None,
               tool="test-integrity.py", command=shown, rc=rc, out=out,
               findings=[{"file": f["file"], "line": f["line"], "rule": f["kind"], "message": f["message"]} for f in found])


# ── G3 secrets ─────────────────────────────────────────────────────────────────────────────────
def added_lines(ctx):
    """{path: [(line, text)]} — every line this change adds; untracked files whole, in --local."""
    res, cur, in_hunk, ln = {}, None, False, 0
    rng = [ctx.base] + (["HEAD"] if ctx.scope == "ci" else [])
    out = run(["git", "-c", "core.quotepath=false", "diff", "-U0", "--no-color", "--no-ext-diff"] + rng, ctx.repo)[1]
    for l in out.split("\n"):
        if l.startswith("diff --git "):
            cur, in_hunk = None, False
        elif not in_hunk and l.startswith("+++ "):
            cur = None if l[4:] == "/dev/null" else l[6:]
        elif l.startswith("@@"):
            m = re.match(r"@@ -\S+ \+(\d+)", l)
            in_hunk, ln = True, int(m.group(1)) if m else 0
        elif in_hunk and cur and l.startswith("+"):
            res.setdefault(cur, []).append((ln, l[1:]))
            ln += 1
    for p in ctx.untracked:
        fp = os.path.join(ctx.repo, p)
        if os.path.isfile(fp) and os.path.getsize(fp) < 1_000_000:
            res[p] = list(enumerate(read(ctx.repo, p).split("\n"), 1))
    return res


def run_g3(ctx):
    gl = shutil.which("gitleaks")
    if gl and ctx.scope == "ci" and ctx.base and ctx.base != ctx.head:
        fd, rep = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        cmd = [gl, "detect", "--source", ".", "--log-opts", "%s..HEAD" % ctx.base, "--redact", "--no-banner",
               "--report-format", "json", "--report-path", rep, "--exit-code", "1"]
        rc, out, err = run(cmd, ctx.repo, timeout=TIMEOUT)
        if rc in (0, 1):
            leaks = json.loads(read("/", rep) or "[]") or []
            os.unlink(rep)
            f = [{"file": x.get("File"), "line": x.get("StartLine"), "rule": x.get("RuleID"),
                  "message": x.get("Description")} for x in leaks]
            return rec("G3", "secrets", "FAIL" if f else "PASS", "%d leak(s)" % len(f) if f else None,
                       tool="gitleaks", command=" ".join(cmd[1:7]), rc=rc, out=out + err, findings=f)
        print("gate-check: gitleaks exited %s — falling back to secret-scan.sh" % rc, file=sys.stderr)
    hook = os.path.join(ctx.repo, ".claude", "hooks", "secret-scan.sh")
    if os.path.exists(os.path.join(ctx.repo, ".claude", ".no-secret-scan")):
        return rec("G3", "secrets", "UNVERIFIED", "secret-scan is opted out here (.claude/.no-secret-scan) and "
                   "gitleaks did not run", "SKIPPED")
    if not os.path.isfile(hook):
        return rec("G3", "secrets", "UNVERIFIED", "neither gitleaks nor .claude/hooks/secret-scan.sh is available", "SKIPPED")
    added = added_lines(ctx) if ctx.base else {}
    if not added:
        return rec("G3", "secrets", "N-A", "no added lines in scope", tool="secret-scan.sh")

    def flagged(path, text):    # the hook's real input shape: an absolute path and the new content
        payload = json.dumps({"tool_name": "Write", "tool_input": {"file_path": os.path.join(ctx.repo, path), "content": text}})
        rc, _, err = run(["bash", hook], ctx.repo, stdin=payload)
        return rc == 2, err.strip().split("\n")[0].replace("Blocked by secret-scan: ", "")
    findings = []
    for path, lines in sorted(added.items()):
        hit, why = flagged(path, "\n".join(s for _, s in lines))
        if not hit:
            continue
        per_line = [{"file": path, "line": ln, "rule": "secret", "message": w}
                    for ln, s in lines for h, w in [flagged(path, s)] if h]
        findings += per_line or [{"file": path, "line": lines[0][0], "rule": "secret", "message": why}]
    n = sum(len(v) for v in added.values())
    return rec("G3", "secrets", "FAIL" if findings else "PASS", "%d secret(s)" % len(findings) if findings else None,
               tool="secret-scan.sh", command="secret-scan.sh over %d added line(s) in %d file(s)" % (n, len(added)),
               findings=findings)


# ── G7 lint · typecheck · standards ────────────────────────────────────────────────────────────
section = lambda repo, f, header: header in read(repo, f)
local_bin = lambda rel: lambda r: os.path.join(r, rel) if os.access(os.path.join(r, rel), os.X_OK) else None
on_path = lambda *names: lambda r: next((shutil.which(n) for n in names if shutil.which(n)), None)


def scripts_of(repo):
    try:
        return json.loads(read(repo, "package.json") or "{}").get("scripts") or {}
    except (ValueError, AttributeError):
        return {}


def pkg_script(repo, names):
    return next((n for n in names if n in scripts_of(repo)), None)


TYPE_SCRIPTS = ("typecheck", "type-check", "check-types", "tsc", "types")
PM = lambda r: next((pm for lock, pm in (("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"), ("bun.lockb", "bun"), ("bun.lock", "bun")) if has(r, lock)), "npm")
GO_PKGS = lambda d: ["./" + x if x != "." else "." for x in d]
TOOLS = [  # (check, name, extensions, configured?, binary, argv(binary, files, dirs, repo))
    ("lint", "eslint", JS, lambda r: has(r, "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", "eslint.config.ts",
                                         ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".eslintrc.yml",
                                         ".eslintrc.yaml") or '"eslintConfig"' in read(r, "package.json"),
     local_bin("node_modules/.bin/eslint"), lambda b, f, d, r: [b, "--format", "json"] + f),
    ("lint", "ruff", (".py",), lambda r: has(r, "ruff.toml", ".ruff.toml") or section(r, "pyproject.toml", "[tool.ruff"),
     on_path("ruff"), lambda b, f, d, r: [b, "check"] + f),
    ("lint", "flake8", (".py",), lambda r: has(r, ".flake8") or section(r, "setup.cfg", "[flake8]") or section(r, "tox.ini", "[flake8]"),
     on_path("flake8"), lambda b, f, d, r: [b] + f),
    ("lint", "golangci-lint", (".go",), lambda r: has(r, ".golangci.yml", ".golangci.yaml", ".golangci.toml", ".golangci.json"),
     on_path("golangci-lint"), lambda b, f, d, r: [b, "run"] + GO_PKGS(d)),
    ("lint", "rubocop", (".rb",), lambda r: has(r, ".rubocop.yml"),
     lambda r: local_bin("bin/rubocop")(r) or shutil.which("rubocop"), lambda b, f, d, r: [b, "--format", "emacs"] + f),
    ("lint", "swiftlint", (".swift",), lambda r: has(r, ".swiftlint.yml"), on_path("swiftlint"), lambda b, f, d, r: [b, "lint", "--quiet"] + f),
    ("typecheck", "package.json type-check script", JS, lambda r: pkg_script(r, TYPE_SCRIPTS) is not None,
     lambda r: shutil.which(PM(r)), lambda b, f, d, r: [b, "run", pkg_script(r, TYPE_SCRIPTS)]),
    ("typecheck", "tsc", (".ts", ".tsx", ".mts", ".cts"), lambda r: has(r, "tsconfig.json") and pkg_script(r, TYPE_SCRIPTS) is None,
     local_bin("node_modules/.bin/tsc"), lambda b, f, d, r: [b, "--noEmit", "-p", "tsconfig.json"]),
    ("typecheck", "mypy", (".py",), lambda r: has(r, "mypy.ini", ".mypy.ini") or section(r, "pyproject.toml", "[tool.mypy") or section(r, "setup.cfg", "[mypy"),
     on_path("mypy"), lambda b, f, d, r: [b] + f),
    ("typecheck", "pyright", (".py",), lambda r: has(r, "pyrightconfig.json") or section(r, "pyproject.toml", "[tool.pyright"),
     on_path("pyright"), lambda b, f, d, r: [b] + f),
    ("typecheck", "go vet", (".go",), lambda r: has(r, "go.mod"), on_path("go"), lambda b, f, d, r: [b, "vet"] + GO_PKGS(d)),
    ("typecheck", "cargo check", (".rs",), lambda r: has(r, "Cargo.toml"), on_path("cargo"), lambda b, f, d, r: [b, "check", "--quiet"]),
    ("typecheck", "dart analyze", (".dart",), lambda r: has(r, "analysis_options.yaml"), on_path("dart"), lambda b, f, d, r: [b, "analyze"] + f),
    ("typecheck", "phpstan", (".php",), lambda r: has(r, "phpstan.neon", "phpstan.neon.dist", "phpstan.dist.neon"),
     lambda r: local_bin("vendor/bin/phpstan")(r) or shutil.which("phpstan"),
     lambda b, f, d, r: [b, "analyse", "--no-progress", "--error-format=raw"] + f),
]


def eslint_findings(out, repo):
    try:
        return [{"file": os.path.relpath(x["filePath"], repo), "line": m.get("line"), "rule": m.get("ruleId"),
                 "message": m.get("message", "")[:200]}
                for x in json.loads(out) for m in x.get("messages", []) if m.get("severity") == 2][:30]
    except (ValueError, KeyError, TypeError):
        return cite(out)


def run_g7_tools(ctx, check):
    files = [f for f in ctx.touched if os.path.isfile(os.path.join(ctx.repo, f))]
    if not files:
        return rec("G7", check, "N-A", "no touched files")
    picked = [(name, fs, binf(ctx.repo), argv) for c, name, exts, conf, binf, argv in TOOLS
              for fs in [[f for f in files if f.endswith(exts)]] if c == check and fs and conf(ctx.repo)]
    if not picked:
        exts = sorted({os.path.splitext(f)[1] for f in files if os.path.splitext(f)[1]})
        return rec("G7", check, "N-A", "no %s configured for the touched %s file(s)"
                   % ("linter" if check == "lint" else "type checker", " ".join(exts) or "extension-less"))
    findings, ran, missing, outs, failed = [], [], [], "", []
    for name, fs, b, argv in picked:
        if not b:
            missing.append("%s (configured, not installed)" % name)
            continue
        cmd = argv(b, fs, sorted({os.path.dirname(f) or "." for f in fs}), ctx.repo)
        rc, out, err = run(cmd, ctx.repo, timeout=TIMEOUT)
        ran.append(name)
        outs += out + err
        if rc is None:
            missing.append("%s (did not finish)" % name)
        elif rc != 0:
            failed.append(name)
            got = eslint_findings(out, ctx.repo) if name == "eslint" else cite(out + err)
            findings += got or [{"message": "%s exited %d: %s" % (name, rc, (out + err).strip()[:200])}]
    verdict = "FAIL" if failed else "UNVERIFIED" if missing else "PASS"
    reason = "; ".join(filter(None, ["%s failed" % ", ".join(failed) if failed else "", ", ".join(missing)])) or None
    return rec("G7", check, verdict, reason, execution="RAN" if ran else "SKIPPED", tool=", ".join(ran) or None,
               command=" · ".join(n for n, _, _, _ in picked), out=outs, findings=findings)


def run_g7_standards(ctx):
    sc = os.path.join(HERE, "standards-check.py")
    if not os.path.isfile(sc):
        return rec("G7", "standards", "UNVERIFIED", "standards-check.py is not installed beside gate-check.py", "SKIPPED")
    if not ctx.base or not ctx.touched:
        return rec("G7", "standards", "N-A", "no touched files")
    cmd = [sys.executable, sc, ctx.repo, "--changed=" + ctx.base, "--json"]
    rc, out, err = run(cmd, ctx.repo, timeout=TIMEOUT)
    shown = ".claude/scripts/standards-check.py . --changed=%s --json" % ctx.base[:12]
    if rc not in (0, 1):
        return rec("G7", "standards", "UNVERIFIED", "standards-check.py failed: %s" % err.strip()[:200], "SKIPPED", command=shown, rc=rc)
    rows = json.loads(out).get("rows", [])
    opened = [r for r in rows if r["status"] == "OPEN"]
    where = lambda w: (w.split(":")[0], int(w.split(":")[1]) if w.count(":") == 1 and w.split(":")[1].isdigit() else None)
    return rec("G7", "standards", "FAIL" if opened else "PASS",
               "%d OPEN row(s)" % len(opened) if opened else "%d row(s) fired, none OPEN" % len(rows),
               tool="standards-check.py", command=shown, rc=rc, out=out,
               findings=[{"file": where(r["where"])[0], "line": where(r["where"])[1], "rule": r["id"],
                          "message": r["message"]} for r in opened])


# ── G15 provenance trailer ─────────────────────────────────────────────────────────────────────
def run_g15(ctx):
    if not ctx.base or ctx.base == ctx.head:
        return rec("G15", "trailer", "N-A", "no commits in base..HEAD")
    out = run(["git", "log", "--format=%H%x1f%s%x1f%B%x1e", "%s..HEAD" % ctx.base], ctx.repo)[1]
    commits = [c.strip("\n").split("\x1f") for c in out.split("\x1e") if c.strip()]
    bare = [(c[0], c[1]) for c in commits if len(c) == 3 and not re.search(r"(?im)^(assisted-by|co-authored-by):\s*\S", c[2])]
    return rec("G15", "trailer", "FAIL" if bare else "PASS",
               "%d of %d commit(s) carry no Assisted-by: / Co-Authored-By: trailer — an agent-written commit "
               "must say so" % (len(bare), len(commits)) if bare else "%d commit(s), all carry a trailer" % len(commits),
               tool="git log", command="git log %s..HEAD" % ctx.base[:12],
               findings=[{"commit": h, "message": s[:120]} for h, s in bare[:30]])


# ── Phase 2: the contract, the judge and the records ────────────────────────────────────────────
def runs_in_change(ctx):
    """Run ids this change created or touched (their ai/runs/<id>/ files or their lock)."""
    ids = set()
    for p in ctx.touched:
        m = re.match(r"^ai/runs/([^/]+)/", p) or re.match(r"^\.claude/locks/([^/]+)\.json$", p)
        if m:
            ids.add(m.group(1))
    return sorted(ids)


def load(path):
    try:
        return json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError):
        return None


def no_records(gate, check):
    return rec(gate, check, "UNVERIFIED", "refract_records.py is not installed beside gate-check.py — re-run "
               "apply-baseline-sync.sh", "SKIPPED")


def run_g0(ctx):
    if not rr:
        return no_records("G0", "acceptance-lock")
    runs = [r for r in runs_in_change(ctx) if os.path.isfile(os.path.join(ctx.repo, "ai", "runs", r, "acceptance.json"))]
    if not runs:
        return rec("G0", "acceptance-lock", "N-A", "no acceptance contract in this change")
    findings = []
    for r in runs:
        lock = rr.load_lock(ctx.repo, r)
        if not lock:
            findings.append({"file": "ai/runs/%s/acceptance.json" % r, "line": None, "rule": "unlocked",
                             "message": "contract written but never locked — .claude/scripts/lock-acceptance.sh %s" % r})
            continue
        diffs = rr.lock_diffs(ctx.repo, lock)
        if lock.get("state") != "locked":
            diffs.insert(0, ".claude/locks/%s.json: reopened for %s and never re-sealed" % (r, lock.get("editor")))
        findings += [{"file": d.split(":", 1)[0], "line": None, "rule": "lock-mismatch", "message": d} for d in diffs]
    return rec("G0", "acceptance-lock", "FAIL" if findings else "PASS",
               "%d locked file(s) differ from their lock — restore them, or a human reopens the contract" % len(findings)
               if findings else "%d run contract(s) locked and intact" % len(runs),
               tool="refract_records.py", command="lock-acceptance.sh --check " + " ".join(runs), findings=findings)


def judge_set():
    return set(filter(None, os.environ.get("REFRACT_JUDGE_AGENTS", "verifier").split(",")))


def judge_record(ctx, path, kind):
    """-> list of problems with one persisted inferential record ([] = sound and fresh)."""
    rel = os.path.relpath(path, ctx.repo)
    obj = load(path)
    if obj is None:
        return ["%s does not parse" % rel]
    try:
        errs = rr.validate(obj, rr.load_schema(kind, ctx.repo))
    except FileNotFoundError as e:
        return [str(e)]
    if errs:
        return ["%s: %s" % (rel, e) for e in errs[:3]]
    probs = []
    sig = obj.get("signer") or {}
    if not sig.get("stamped_by") or not sig.get("agent_type"):
        probs.append("%s carries no hook-stamped signer" % rel)
    fresh, diffs = rr.freshness(ctx.repo, obj, ctx.scope == "ci", ctx.base)
    if not fresh:
        probs.append("%s is STALE — %s" % (rel, "; ".join(diffs[:4])))
    return probs


def run_g1_acceptance(ctx):
    if not rr:
        return no_records("G1", "acceptance")
    runs = [r for r in runs_in_change(ctx) if os.path.isfile(os.path.join(ctx.repo, "ai", "runs", r, "acceptance.json"))]
    if not runs:
        return rec("G1", "acceptance", "N-A", "no acceptance contract in this change")
    findings, notes = [], []
    for r in runs:
        vp = os.path.join(ctx.repo, "ai", "runs", r, "verdict.json")
        rel = "ai/runs/%s/verdict.json" % r
        if not os.path.isfile(vp):
            findings.append({"file": rel, "line": None, "rule": "no-verdict",
                             "message": "no verdict — dispatch the verifier in acceptance mode (delegation-brief.md)"})
            continue
        probs = judge_record(ctx, vp, "verdict")
        v = load(vp) or {}
        if rr.agent_base((v.get("signer") or {}).get("agent_type")) not in judge_set():
            probs.append("%s is signed by `%s`, not a judge" % (rel, (v.get("signer") or {}).get("agent_type")))
        if v.get("verdict") != "PASS":
            failing = [c["id"] for c in v.get("criteria", []) if c.get("status") != "PASS"]
            probs.append("%s says %s%s" % (rel, v.get("verdict"), (" — not passing: " + ", ".join(failing)) if failing else ""))
        findings += [{"file": rel, "line": None, "rule": "acceptance", "message": m} for m in probs]
        notes.append("%s %s" % (r, v.get("verdict")))
    return rec("G1", "acceptance", "FAIL" if findings else "PASS",
               "; ".join(f["message"] for f in findings[:2])[:300] if findings else "verifier PASS, fresh: " + ", ".join(notes),
               tool="refract_records.py", command="verdict.json × %d run(s)" % len(runs), findings=findings)


def run_g7_review(ctx):
    if not rr:
        return no_records("G7", "review")
    findings, unverified, n = [], [], 0
    for r in runs_in_change(ctx):
        rd = os.path.join(ctx.repo, "ai", "runs", r)
        reviews = sorted(os.path.join(rd, "reviews", f) for f in (os.listdir(os.path.join(rd, "reviews"))
                         if os.path.isdir(os.path.join(rd, "reviews")) else []) if f.endswith(".json"))
        refute = os.path.join(rd, "verdict-refute.json")
        for p in reviews:
            n += 1
            findings += [{"file": os.path.relpath(p, ctx.repo), "line": None, "rule": "review", "message": m}
                         for m in judge_record(ctx, p, "findings")]
        important = [p for p in reviews if any(f.get("severity") == "IMPORTANT" for f in (load(p) or {}).get("findings", []))]
        if os.path.isfile(refute):
            n += 1
            probs = judge_record(ctx, refute, "verdict")
            v = load(refute) or {}
            if v.get("verdict") == "FAIL":
                probs += ["confirmed IMPORTANT: %s:%s — %s" % (f.get("file"), f.get("line"), f.get("claim", "")[:120])
                          for f in v.get("findings", []) if f.get("bucket") == "confirmed" and f.get("severity") == "IMPORTANT"]
            elif v.get("verdict") == "CONCERNS":
                unverified.append("ai/runs/%s/verdict-refute.json: unconfirmed IMPORTANT candidate(s) — run the probe each names" % r)
            findings += [{"file": "ai/runs/%s/verdict-refute.json" % r, "line": None, "rule": "refute", "message": m} for m in probs]
        elif important:
            unverified.append("ai/runs/%s: %d review(s) carry IMPORTANT candidates the verifier never refuted" % (r, len(important)))
    if not n:
        return rec("G7", "review", "N-A", "no persisted review in this change")
    verdict = "FAIL" if findings else "UNVERIFIED" if unverified else "PASS"
    return rec("G7", "review", verdict, "; ".join([f["message"] for f in findings[:2]] + unverified[:2])[:300] or
               "%d record(s) fresh, nothing confirmed IMPORTANT" % n, tool="refract_records.py",
               command="reviews/*.json + verdict-refute.json", findings=findings + [{"message": u} for u in unverified])


def run_g15_signer(ctx):
    if not rr:
        return no_records("G15", "signer")
    findings, n = [], 0
    for r in runs_in_change(ctx):
        rd = os.path.join(ctx.repo, "ai", "runs", r)
        paths = [os.path.join(rd, f) for f in ("verdict.json", "verdict-refute.json") if os.path.isfile(os.path.join(rd, f))]
        if os.path.isdir(os.path.join(rd, "reviews")):
            paths += [os.path.join(rd, "reviews", f) for f in sorted(os.listdir(os.path.join(rd, "reviews"))) if f.endswith(".json")]
        for p in paths:
            n += 1
            o, rel = load(p) or {}, os.path.relpath(p, ctx.repo)
            sig = o.get("signer") or {}
            who = rr.agent_base(sig.get("agent_type"))
            want = "persist-verdict.sh" if os.path.basename(p).startswith("verdict") else "persist-review.sh"
            if sig.get("stamped_by") != want or not who:
                findings.append({"file": rel, "line": None, "rule": "unstamped", "message": "%s was not stamped by %s" % (rel, want)})
            elif who in [rr.agent_base(a) for a in o.get("authors", [])]:
                findings.append({"file": rel, "line": None, "rule": "self-signed",
                                 "message": "%s is signed by `%s`, which also authored the change it judges" % (rel, who)})
            elif want == "persist-verdict.sh" and who not in judge_set():
                findings.append({"file": rel, "line": None, "rule": "not-a-judge", "message": "%s is signed by `%s`, not a judge" % (rel, who)})
    if not n:
        return rec("G15", "signer", "N-A", "no inferential record in this change")
    return rec("G15", "signer", "FAIL" if findings else "PASS",
               "%d of %d record(s) self-signed or unstamped" % (len(findings), n) if findings
               else "%d record(s), each hook-stamped and signed by someone other than its author" % n,
               tool="refract_records.py", findings=findings)


def run_g2_oracle(ctx):
    oc = os.path.join(HERE, "oracle-check.py")
    if not os.path.isfile(oc):
        return rec("G2", "oracle", "UNVERIFIED", "oracle-check.py is not installed beside gate-check.py", "SKIPPED")
    if not ctx.base:
        return rec("G2", "oracle", "N-A", "no commit to compare against (unborn branch)")
    cmd = [sys.executable, oc, "--repo=" + ctx.repo, "--base=" + ctx.base, "--json"] + (["--head=HEAD"] if ctx.scope == "ci" else [])
    rc, out, err = run(cmd, ctx.repo, timeout=TIMEOUT)
    shown = ".claude/scripts/oracle-check.py --base=%s%s" % (ctx.base[:12], " --head=HEAD" if ctx.scope == "ci" else "")
    if rc not in (0, 1):
        return rec("G2", "oracle", "UNVERIFIED", "oracle-check.py failed: %s" % err.strip()[:200], "SKIPPED", command=shown, rc=rc)
    data = json.loads(out)
    found = data.get("findings", [])
    if not data.get("cases_checked"):
        return rec("G2", "oracle", "N-A", "no new or changed test case", tool="oracle-check.py", command=shown, rc=rc)
    return rec("G2", "oracle", "FAIL" if found else "PASS",
               "%d of %d changed test case(s) with no real oracle" % (len(found), data["cases_checked"]) if found
               else "%d changed test case(s), each asserts something that could fail" % data["cases_checked"],
               tool="oracle-check.py", command=shown, rc=rc, out=out,
               findings=[{"file": f["file"], "line": f["line"], "rule": f["kind"], "message": f["message"]} for f in found])


# ── G12 usability and state coverage ───────────────────────────────────────────────────────────
STATE_LINT = os.path.join(".claude", "skills", "state-matrix", "scripts", "state-matrix-lint.py")
UI_LANES = {"frontend", "mobile"}


def run_g12(ctx):
    """The computational half of G12: the ui-ux pack's state-matrix-lint.py, once per run in the change.
    The lint's own exit convention: 0 no finding (PASS, or N-A with its reason), 1 findings, anything
    else could not run — UNVERIFIED, never PASS."""
    runs = runs_in_change(ctx)
    ui = [r for r in runs if UI_LANES & set((load(os.path.join(ctx.repo, "ai", "runs", r, "run.json")) or {}).get("lanes") or [])]
    lint = os.path.join(ctx.repo, STATE_LINT)
    if not os.path.isfile(lint):
        if ui:
            return rec("G12", "state-matrix", "UNVERIFIED", "%d UI run(s) (%s) and %s is not installed — the ui-ux pack "
                       "ships it (/setup-project --include=ui-ux)" % (len(ui), ", ".join(ui), STATE_LINT), "SKIPPED")
        return rec("G12", "state-matrix", "N-A", "no UI run in this change (state-matrix-lint.py, ui-ux pack, not installed)")
    if not runs:
        return rec("G12", "state-matrix", "N-A", "no run contract in this change")
    shown = "%s --run=ai/runs/<id> --base=%s --json × %d run(s)" % (STATE_LINT, (ctx.base or "none")[:12], len(runs))
    findings, errors, verdicts, notes, outs, rcs = [], [], [], [], [], []
    for r in runs:
        cmd = [sys.executable, lint, "--run=ai/runs/" + r, "--repo=" + ctx.repo, "--json"] + (["--base=" + ctx.base] if ctx.base else [])
        rc, out, err = run(cmd, ctx.repo, timeout=TIMEOUT)
        rcs.append(rc if rc is not None else -1)
        try:
            d = json.loads(out) if rc in (0, 1) else None
        except ValueError:
            d = None
        if not isinstance(d, dict):
            errors.append("ai/runs/%s: state-matrix-lint.py could not run (exit %s): %s" % (r, rc, (err or out).strip()[-160:]))
            continue
        outs.append(out)
        verdicts.append(d.get("verdict"))
        notes.append("%s %s%s" % (r, d.get("verdict"), " (%s)" % d["reason"] if d.get("reason") else ""))
        findings += [{"file": x.get("file"), "line": x.get("line") if isinstance(x.get("line"), int) else None,
                      "rule": x.get("kind"), "message": x.get("message") or ""} for x in d.get("findings", [])]
    verdict = ("FAIL" if findings else "UNVERIFIED" if errors else "PASS" if "PASS" in verdicts else "N-A")
    reason = ("%d finding(s): %s" % (len(findings), "; ".join(f["message"] for f in findings[:2])) if findings
              else "; ".join(errors[:2]) if errors else "; ".join(notes))[:300]
    return rec("G12", "state-matrix", verdict, reason, "SKIPPED" if verdict == "UNVERIFIED" and not outs else "RAN",
               tool="state-matrix-lint.py", command=shown, rc=max(rcs) if rcs else None, out="\n".join(outs),
               findings=findings + [{"message": e} for e in errors])


# ── G4 performance · G14 behavioural baseline ──────────────────────────────────────────────────
def run_baseline_gate(ctx, gate):
    """Both gates are behavior-diff.py: one manifest reader, one scope rule, one AC-declaration rule."""
    check = "perf" if gate == "G4" else "behaviour"
    bd = os.path.join(HERE, "behavior-diff.py")
    if not os.path.isfile(bd):
        return rec(gate, check, "UNVERIFIED", "behavior-diff.py is not installed beside gate-check.py", "SKIPPED")
    if not ctx.base or ctx.base == ctx.head and not ctx.touched:
        return rec(gate, check, "N-A", "no commit to compare against")
    if gate == "G4" and ctx.scope == "local" and os.environ.get("REFRACT_G4_LOCAL") != "1":
        return rec(gate, check, "N-A", "G4 measures in CI (--ci): ten interleaved base/head pairs per performance entry is "
                   "not a Stop-hook cost — REFRACT_G4_LOCAL=1 runs it here")
    cmd = [sys.executable, bd, "--gate=" + gate, "--repo=" + ctx.repo, "--base=" + ctx.base, "--json"] + \
        (["--ci"] if ctx.scope == "ci" else []) + (["--touched=" + ",".join(ctx.touched)] if ctx.scope == "local" else [])
    rc, out, err = run(cmd, ctx.repo, timeout=None if ctx.scope == "ci" else TIMEOUT)
    shown = ".claude/scripts/behavior-diff.py --gate=%s --base=%s%s" % (gate, ctx.base[:12], " --ci" if ctx.scope == "ci" else "")
    try:
        d = json.loads(out)
    except ValueError:
        return rec(gate, check, "UNVERIFIED", "behavior-diff.py failed (exit %s): %s" % (rc, (err or out).strip()[-200:]),
                   "SKIPPED", command=shown, rc=rc)
    findings = [{"file": d.get("manifest"), "line": None, "rule": "%s/%s" % (e["kind"], e["status"].lower()),
                 "message": "%s: %s" % (e["id"], e.get("reason") or e["status"])}
                for e in d.get("entries", []) if e["status"] not in ("SAME", "EXPLAINED")]
    findings += [{"file": p, "line": None, "rule": "uncaptured", "message": "modified source no baseline entry covers"}
                 for p in d.get("uncaptured", [])[:30]]
    return rec(gate, check, d.get("verdict", "UNVERIFIED"), d.get("reason"), tool="behavior-diff.py", command=shown,
               rc=rc, out=out, findings=findings)


RUNNERS = {("G0", "acceptance-lock"): run_g0, ("G1", "acceptance"): run_g1_acceptance, ("G2", "oracle"): run_g2_oracle,
           ("G7", "review"): run_g7_review, ("G15", "signer"): run_g15_signer,
           ("G1", "tests"): run_g1, ("G2", "test-integrity"): run_g2, ("G3", "secrets"): run_g3,
           ("G7", "lint"): lambda c: run_g7_tools(c, "lint"), ("G7", "typecheck"): lambda c: run_g7_tools(c, "typecheck"),
           ("G7", "standards"): run_g7_standards, ("G15", "trailer"): run_g15,
           ("G12", "state-matrix"): run_g12,
           ("G4", "perf"): lambda c: run_baseline_gate(c, "G4"), ("G14", "behaviour"): lambda c: run_baseline_gate(c, "G14")}


def load_modes(repo, override):
    modes = {g: dict(v) for g, v in DEFAULTS.items()}
    src, p = "the v1 defaults", os.path.join(repo, ".claude", "gates.json")
    if os.path.isfile(p):
        try:
            for g, v in (json.load(open(p, encoding="utf-8")).get("gates") or {}).items():
                for c, m in ({c: v for c in modes.get(g, {})} if isinstance(v, str) else v).items():
                    if g in modes and c in modes[g] and m in MODES:
                        modes[g][c] = m
                    else:
                        print("gate-check: .claude/gates.json — ignored %s %s=%r (unknown gate, check or mode)" % (g, c, m), file=sys.stderr)
            src = ".claude/gates.json"
        except (ValueError, OSError, AttributeError) as e:
            print("gate-check: .claude/gates.json is unreadable (%s) — running the v1 defaults" % e, file=sys.stderr)
    elif os.path.isfile(os.path.join(repo, ".claude", "gates.yaml")):
        print("gate-check: .claude/gates.yaml is not read — gate modes live in .claude/gates.json", file=sys.stderr)
    if override:
        modes, src = {g: {c: override for c in v} for g, v in modes.items()}, "--mode=" + override
    return modes, src


def main(argv):
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    flags = {a for a in argv if a.startswith("--") and "=" not in a}
    bad = (set(opts) - {"base", "repo", "only", "mode"}) | (flags - {"--local", "--ci", "--json", "--hook-json", "--no-evidence"})
    if bad or opts.get("mode", "shadow") not in MODES or {"--local", "--ci"} <= flags or any(not a.startswith("--") for a in argv):
        print(__doc__.split("\n\n")[0].split("\n", 1)[1], file=sys.stderr)
        return 1
    repo = git(os.path.abspath(opts.get("repo", ".")), "rev-parse", "--show-toplevel")
    if not repo:
        print("gate-check: not inside a git work tree", file=sys.stderr)
        return 1
    scope = "ci" if "--ci" in flags else "local"
    ctx = Ctx(repo, scope, opts.get("base"))
    modes, src = load_modes(repo, opts.get("mode"))
    only = set(opts["only"].split(",")) if opts.get("only") else None
    records = []
    for gate, check in CHECKS:
        if only and gate not in only:
            continue
        t0 = time.time()
        if scope == "local" and not ctx.touched and ctx.base == ctx.head:
            r = rec(gate, check, "N-A", "nothing changed since %s" % (ctx.head or "an unborn HEAD")[:12])
        else:
            r = RUNNERS[(gate, check)](ctx)
        if (gate, check) in INFERENTIAL:
            r["producer"] = "inferential"
        r.update({"schema": "refract/evidence/v1", "mode": modes[gate][check], "scope": scope, "commit": ctx.head,
                  "base": ctx.base, "tree": ctx.tree, "dirty": ctx.dirty, "duration_ms": int((time.time() - t0) * 1000),
                  "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "stamped_by": "gate-check.py",
                  "gate_check_version": VERSION, "agent_type": None, "author_agent": None})
        records.append(r)
    edir = os.path.join(".claude", "evidence", ctx.head or "unborn")
    if "--no-evidence" not in flags:
        os.makedirs(os.path.join(repo, edir), exist_ok=True)
        gi = os.path.join(repo, ".claude", "evidence", ".gitignore")
        if not os.path.exists(gi):
            open(gi, "w").write("# gate-check.py evidence: local records, never committed (see gate-check.py § EVIDENCE)\n*\n")
        for r in records:
            name = "%s-%s" % (r["gate"], r["check"])
            with open(os.path.join(repo, edir, name + ".json"), "w") as fh:
                json.dump(r, fh, indent=2)
                fh.write("\n")
    lane_busy = lambda r: r["gate"] == "G1" and (r["reason"] or "").startswith("lane-busy")
    blocking = [r for r in records if r["mode"] == "block" and (r["verdict"] == "FAIL" or (scope == "local" and lane_busy(r)))]
    scoped = [r for r in records if r["mode"] != "shadow"] or records
    verdict = next((v for v in ("FAIL", "UNVERIFIED") if any(r["verdict"] == v for r in scoped)), "PASS")
    log = lambda s: print(s, file=sys.stderr)
    log("gate-check — %s · base %s · %d touched file(s) · modes from %s"
        % (scope, (ctx.base or "none")[:12], len(ctx.touched), src))
    for r in records:
        log("  %-4s %-15s %-11s %-7s %s" % (r["gate"], r["check"], r["verdict"], r["mode"], (r["reason"] or r["command"] or "")[:150]))
        if r["mode"] != "shadow" and r["verdict"] == "FAIL":
            for f in r["findings"][:8]:
                at = "%s:%s" % (f.get("file"), f.get("line")) if f.get("file") else f.get("commit", "")[:12]
                log("       %s — %s" % (at, (f.get("message") or "")[:160]))
    excluded = len(records) - len(scoped)
    log("verdict: %s%s%s · evidence %s/" % (verdict, " — blocking: " + ", ".join("%s %s" % (r["gate"], r["check"]) for r in blocking) if blocking else "",
                                           " (%d shadow check(s) not counted)" % excluded if excluded else
                                           " (shadow — recorded, not enforced)" if all(r["mode"] == "shadow" for r in records) else "",
                                           edir if "--no-evidence" not in flags else "(not written)"))
    if "--json" in flags:
        print(json.dumps({"verdict": verdict, "blocking": [r["gate"] + " " + r["check"] for r in blocking], "records": records}, indent=2))
    elif "--hook-json" in flags and not blocking and verdict != "PASS":
        notes = ["%s %s %s%s" % (r["gate"], r["check"], r["verdict"], ": " + r["reason"][:90] if r["reason"] else "")
                 for r in scoped if r["verdict"] in ("FAIL", "UNVERIFIED")]
        print(json.dumps({"systemMessage": "gate-check %s — %s (evidence: %s/)" % (verdict, "; ".join(notes), edir)}))
    return 2 if blocking else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
