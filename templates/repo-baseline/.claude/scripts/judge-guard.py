#!/usr/bin/env python3
"""judge-guard.py — what a judge may run, read and be told. Engine of .claude/hooks/judge-bash-guard.sh.

A judge is an agent whose `agent_type` (from the hook input — never from the model) is in
REFRACT_JUDGE_AGENTS (default: verifier). Every other agent passes untouched.

  Bash          the judge runs tests, probes and scanners, and reads. Nothing that writes the
                repository, nothing that writes git, nothing that reaches past localhost. Each
                segment of a compound command must start with an allowed head (ALLOWED below);
                redirects may target /dev/null or a scratch directory only.
  Read/Grep/Glob the builder's narrative is out of reach: run ledgers, commit messages, session
                logs, the status / changelog entries the builder wrote about itself.
  Agent/Task    brief-lint: a dispatch TO a judge carries paths and a mode, never the builder's
                account of its work ("I implemented…", "all tests pass", "safe to merge", a ledger,
                a PR body, commit messages). Framing a change as safe is how a reviewer is
                defeated; the brief is checked before the judge ever reads it
                (templates/snippets/delegation-brief.md).

Exit 2 = deny with the reason on stderr; 0 = allow. Opt out per project: .claude/.no-judge-guard.

HONEST LIMIT. Test runners execute project code, and project code can write files — running the
suite is what a judge is for, so that is accepted. The guard closes the judge's OWN write paths.
"""
import json
import os
import re
import shlex
import sys

SCRATCH = ("/tmp/", "/private/tmp/", "/var/folders/", "/dev/null")
LOCAL_HOSTS = ("localhost", "127.0.0.1", "0.0.0.0", "[::1]", "::1")
NARRATIVE_PATHS = re.compile(r"(^|/)(ledger\.md|COMMIT_EDITMSG|session-log\.md)$|(^|/)\.git/logs/|(^|/)ai/status\.md$"
                             r"|(^|/)ai/dynamic/changelog\.md$")
BRIEF_FORBIDDEN = [
    (re.compile(r"ledger\.md|COMMIT_EDITMSG|session-log|ai/status\.md|ai/dynamic/changelog", re.I),
     "cites the builder's own record (ledger, status, changelog, session log)"),
    (re.compile(r"\bgit\s+log\b|\bcommit messages?\b|\b(PR|pull request)\s+(description|body|text|summary)\b", re.I),
     "cites commit messages or PR text"),
    (re.compile(r"\b(I|we)\s+(have\s+|'ve\s+)?(implemented|added|fixed|changed|updated|wrote|written|refactored|built|"
                r"verified|tested|made|completed)\b", re.I), "carries the builder's narrative (\"I implemented…\")"),
    (re.compile(r"\b(all\s+)?tests?\s+(now\s+)?(pass|passes|are\s+green)\b|\bshould\s+(now\s+)?(pass|work)\b", re.I),
     "asserts the outcome the judge is there to establish"),
    (re.compile(r"\b(is|are|looks|seems)\s+(correct|safe|fine|good|done)\b|\bsafe\s+to\s+merge\b|\bready\s+to\s+(ship|merge)\b"
                r"|\bjust\s+(confirm|verify|check|rubber.?stamp)\b|\bno\s+issues\b", re.I),
     "frames the change as safe or done"),
]
TEST_TOOLS = {"jest", "vitest", "mocha", "ava", "tap", "playwright", "cypress", "pytest", "py.test", "tox", "nox",
              "rspec", "phpunit", "pest", "karma", "jasmine", "uvu", "node:test", "behave", "cucumber-js",
              "eslint", "tsc", "vue-tsc", "mypy", "pyright", "ruff", "flake8", "pylint", "golangci-lint",
              "rubocop", "prettier", "biome", "semgrep", "gitleaks", "osv-scanner", "trivy", "pip-audit",
              "bandit", "hadolint", "shellcheck", "axe", "lighthouse", "lhci", "k6", "hyperfine", "stylelint",
              "squawk", "sqlfluff", "detox", "maestro", "swiftlint", "ktlint", "phpstan", "psalm", "brakeman",
              "standard", "xo", "c8", "nyc"}
READ_HEADS = {"ls", "cat", "head", "tail", "wc", "grep", "egrep", "fgrep", "rg", "sort", "uniq", "cut", "tr", "diff",
              "cmp", "stat", "file", "tree", "pwd", "echo", "printf", "true", "false", "test", "[", "jq", "yq",
              "basename", "dirname", "realpath", "readlink", "which", "type", "date", "sha256sum", "shasum", "md5",
              "md5sum", "xxd", "od", "strings", "column", "nl", "comm", "paste", "seq", "env", "printenv", "uname",
              "sleep", "expr", "cd"}
GIT_READ = {"diff", "status", "ls-files", "ls-tree", "rev-parse", "merge-base", "cat-file", "blame", "grep",
            "show", "rev-list", "describe", "name-rev", "for-each-ref", "check-ignore", "hash-object"}
INTERPRETERS = {"python", "python3", "node", "ruby", "php", "deno", "bun", "perl"}
SNIPPET_WRITES = re.compile(r"open\([^)]*['\"][wax+]|\.write|unlink|remove\(|rmtree|rename|replace\(|mkdir|subprocess|"
                            r"os\.system|child_process|spawn|exec\(|execSync|\bfs\.|shutil|socket|urllib|requests\.|"
                            r"https?\.(request|get)|fetch\(|File\.write|IO\.write|file_put_contents|`|\bsystem\(")
RUNNER_MODULES = {"pytest", "unittest", "mypy", "pyright", "ruff", "flake8", "pylint", "bandit", "pip_audit",
                  "doctest", "timeit", "cProfile", "json.tool"}
REPO_SCRIPTS = re.compile(r"(^|/)\.claude/(scripts/(oracle-check|test-integrity|standards-check|refract_records|gate-check)\.py"
                          r"|scripts/lock-acceptance\.sh|hooks/test-lane\.sh)$")


def judges():
    return {j.strip() for j in os.environ.get("REFRACT_JUDGE_AGENTS", "verifier").split(",") if j.strip()}


def base(agent):
    return (agent or "").rsplit(":", 1)[-1]


def deny(msg):
    print("Blocked by judge-guard: " + msg, file=sys.stderr)
    return 2


def scratch(target):
    t = os.path.expandvars(target)
    tmp = os.environ.get("TMPDIR", "")
    return t.startswith(SCRATCH) or (tmp and t.startswith(tmp))


def segments(cmd):
    """Tokens per simple command; None when the command cannot be parsed safely."""
    if re.search(r"\$\(|`|<\(|>\(|<<", cmd):
        return None
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=";&|<>")
        lex.whitespace_split = True
        lex.commenters = ""
        toks = list(lex)
    except ValueError:
        return None
    segs, cur = [], []
    for t in toks:
        if t in (";", "&&", "||", "|", "&", "|&", ";;"):
            if cur:
                segs.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        segs.append(cur)
    return segs


def check_redirects(seg):
    """Strip redirections from a segment; return (args, error)."""
    out, i = [], 0
    while i < len(seg):
        t = seg[i]
        if t in (">", ">>", ">|", "&>", "&>>", ">&") or re.fullmatch(r"[0-9]?>{1,2}\|?", t):
            target = seg[i + 1] if i + 1 < len(seg) else ""
            if out and re.fullmatch(r"[0-9]", out[-1]):
                out.pop()                                # the fd number of `2>…` is not an argument
            if t == ">&" or target in ("&1", "&2") or re.fullmatch(r"&?[0-9]", target):
                i += 2
                continue
            if not scratch(target):
                return None, "a redirect writes `%s` — a judge writes only to /dev/null or a scratch dir (/tmp, $TMPDIR)" % target
            i += 2
            continue
        if t in ("<",):
            i += 2
            continue
        out.append(t)
        i += 1
    return out, None


def url_hosts_local(args):
    for a in args:
        m = re.match(r"^(?:https?|wss?)://(\[[^\]]+\]|[^/:?#]+)", a)
        if m and m.group(1).lower() not in LOCAL_HOSTS:
            return m.group(1)
    return None


def check_segment(args):
    """None when allowed, else the reason."""
    while args and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", args[0]):
        args = args[1:]
    while args and args[0] in ("time", "nice", "command", "nohup", "timeout", "env"):
        args = args[2:] if args[0] == "timeout" else args[1:]
        while args and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", args[0]):
            args = args[1:]
    if not args:
        return None
    head = os.path.basename(args[0])
    rest = args[1:]
    if head in ("bash", "sh") and rest and REPO_SCRIPTS.search(rest[0]):
        args, head, rest = rest, os.path.basename(rest[0]), rest[1:]
    if REPO_SCRIPTS.search(args[0]) or head in ("test-lane.sh",):
        if head == "gate-check.py" and "--no-evidence" not in rest:
            return "gate-check.py writes evidence; pass --no-evidence"
        if head == "lock-acceptance.sh" and not ({"--check", "--status"} & set(rest)):
            return "a judge checks a lock (--check / --status); it never locks or reopens one"
        if head == "refract_records.py" and (not rest or rest[0] not in ("check", "status", "scope", "validate")):
            return "refract_records.py: a judge may only check, status, scope or validate"
        if head == "test-lane.sh" and rest and rest[0] not in ("run", "verified", "classify"):
            return "test-lane.sh %s — a judge runs tests through `run`; red/green records are the builder's evidence" % rest[0]
        return None
    if head == "find":
        bad = [a for a in rest if a in ("-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprintf", "-fls")]
        return "find %s writes or executes" % bad[0] if bad else None
    if head == "sed":
        return "sed -i edits in place" if any(re.match(r"-[a-zA-Z]*i|--in-place", a) for a in rest) else None
    if head == "awk" or head == "gawk":
        return "awk with system() or an output redirect writes" if any(re.search(r"system\(|print[^;]*>", a) for a in rest) else None
    if head in READ_HEADS:
        return None
    if head == "git":
        r = list(rest)
        while r and r[0] in ("-C", "-c", "--no-pager", "--git-dir", "--work-tree"):
            r = r[2:] if r[0] in ("-C", "-c", "--git-dir", "--work-tree") else r[1:]
        sub = r[0] if r else ""
        if sub not in GIT_READ:
            return "`git %s` — a judge reads git (diff, status, show <rev>:<path>, blame, ls-files…), never writes it, and never reads commit messages (log)" % sub
        if sub == "show" and not all(":" in a for a in r[1:] if not a.startswith("-")):
            return "`git show <commit>` prints the commit message (builder narrative) — use `git show <rev>:<path>` or `git diff`"
        return None
    if head in ("curl", "wget", "http", "https", "xh"):
        far = url_hosts_local(rest)
        if far:
            return "%s reaches `%s` — a judge's probes stay on localhost" % (head, far)
        if not any(re.match(r"^(?:https?|wss?)://", a) for a in rest) and not any(h in " ".join(rest) for h in LOCAL_HOSTS):
            return "%s without a localhost URL" % head
        outs = [rest[i + 1] for i, a in enumerate(rest[:-1]) if a in ("-o", "--output", "-O", "--output-document")]
        if any(not scratch(o) for o in outs) or "-O" in rest and not outs:
            return "%s writes a file outside the scratch dir" % head
        return None
    if head in ("psql", "mysql", "sqlite3", "redis-cli", "mongosh"):
        joined = " ".join(rest)
        hosts = re.findall(r"(?:-h|--host)[= ]?(\S+)|@([\w.-]+)[:/]", joined)
        far = [h[0] or h[1] for h in hosts if (h[0] or h[1]) not in LOCAL_HOSTS]
        return "%s targets `%s` — probes run against a local copy only" % (head, far[0]) if far else None
    if head in ("npm", "pnpm", "yarn", "bun") and rest:
        r = [a for a in rest if not a.startswith("-")]
        verb = r[0] if r else ""
        if verb in ("test", "t", "tst"):
            return None
        if verb in ("run", "run-script") and len(r) > 1:
            return None if re.search(r"test|spec|lint|type|check|e2e|vitest|jest|bench|audit", r[1]) else \
                "`%s run %s` is not a test, lint, type-check or bench script" % (head, r[1])
        if verb == "audit" and "fix" not in r:
            return None
        if verb in ("exec", "x", "dlx") and len(r) > 1:
            return None if r[1] in TEST_TOOLS else "`%s %s %s` — only test, lint and scan tools" % (head, verb, r[1])
        if head == "bun" and verb and verb.endswith((".ts", ".js")):
            return check_segment(["node"] + rest)
        if head == "yarn" and verb in TEST_TOOLS:
            return None
        return "`%s %s` — installs, publishes and arbitrary scripts are not a judge's to run" % (head, verb)
    if head in ("npx", "bunx"):
        r = [a for a in rest if not a.startswith("-")]
        return None if r and r[0] in TEST_TOOLS else "`%s %s` — only test, lint and scan tools" % (head, r[0] if r else "")
    if head in TEST_TOOLS:
        fixers = {"--fix", "--write", "-w", "--autocorrect", "-a", "-A", "--fix-dry-run=false", "--apply"}
        if head == "tsc" and "--noEmit" not in rest and "--build" in rest:
            return "tsc --build emits files — pass --noEmit"
        if head in ("ruff", "prettier", "biome") and rest and rest[0] in ("format",) and "--check" not in rest and "--diff" not in rest:
            return "%s format rewrites files — use --check" % head
        if head == "prettier" and "--check" not in rest and "-c" not in rest and "--list-different" not in rest:
            return "prettier without --check rewrites files"
        bad = [a for a in rest if a in fixers or a.startswith("--fix")]
        return "`%s %s` rewrites files — a judge reports, it never fixes" % (head, bad[0]) if bad else None
    if head == "go":
        return None if rest and rest[0] in ("test", "vet", "list", "version", "env") else "`go %s` — only go test / vet" % (rest[0] if rest else "")
    if head == "cargo":
        return None if rest and rest[0] in ("test", "check", "clippy", "nextest", "bench", "tree", "audit") and "--fix" not in rest \
            else "`cargo %s` — only test / check / clippy / bench" % (rest[0] if rest else "")
    if head in ("mvn", "mvnw", "./mvnw", "gradle", "gradlew", "./gradlew"):
        bad = [a for a in rest if a in ("install", "deploy", "publish", "release") or a.endswith(":publish")]
        return "`%s %s` publishes or installs" % (head, bad[0]) if bad else None
    if head == "dotnet":
        return None if rest and rest[0] in ("test", "build", "list") else "`dotnet %s` — only dotnet test" % (rest[0] if rest else "")
    if head in ("flutter", "dart", "swift", "mix", "rails", "rake", "xcodebuild", "deno"):
        r = rest[0] if rest else ""
        ok = {"flutter": ("test", "analyze"), "dart": ("test", "analyze"), "swift": ("test", "build"),
              "mix": ("test", "credo", "format"), "rails": ("test",), "rake": ("test", "spec"),
              "xcodebuild": ("test", "-scheme", "-workspace", "-project"), "deno": ("test", "lint", "check", "bench")}[head]
        if head == "mix" and r == "format" and "--check-formatted" not in rest:
            return "mix format rewrites files — use --check-formatted"
        return None if r in ok else "`%s %s` — only its test / analyze verbs" % (head, r)
    if head in ("bundle", "poetry", "uv", "pipenv", "pdm", "hatch"):
        r = [a for a in rest if not a.startswith("-")]
        if r and r[0] in ("exec", "run"):
            return check_segment(r[1:])
        return "`%s %s` — only `%s exec|run <test tool>`" % (head, r[0] if r else "", head)
    if head == "php" and rest[:2] == ["artisan", "test"]:
        return None
    if head in INTERPRETERS:
        if "-m" in rest:
            mod = rest[rest.index("-m") + 1] if rest.index("-m") + 1 < len(rest) else ""
            return None if mod in RUNNER_MODULES else "`%s -m %s` — only test and lint modules" % (head, mod)
        for flag in ("-c", "-e", "--eval", "-p", "--print", "-r"):
            if flag in rest:
                snippet = rest[rest.index(flag) + 1] if rest.index(flag) + 1 < len(rest) else ""
                return "the inline %s snippet writes, spawns or reaches the network — a probe reads" % head \
                    if SNIPPET_WRITES.search(snippet) else None
        script = next((a for a in rest if not a.startswith("-")), "")
        if REPO_SCRIPTS.search(script) or scratch(script) or re.search(r"(^|/)(tests?|spec|__tests__)/|[._-](test|spec)\.", script):
            return None
        return "`%s %s` — a judge runs test files, scratch probes (/tmp) and .claude/scripts checks only" % (head, script)
    if head.startswith("vendor/bin/") or head in ("phpunit", "pest"):
        return None
    if re.search(r"(^|/)node_modules/\.bin/", args[0]):
        return None if os.path.basename(args[0]) in TEST_TOOLS else "`%s` is not a test, lint or scan tool" % args[0]
    return "`%s` is not on the judge's list (tests, linters, type checkers, scanners, read-only shell, read-only git, localhost probes)" % head


def check_bash(cmd):
    segs = segments(cmd)
    if segs is None:
        return "command substitution, process substitution, heredocs and unparseable quoting are not allowed — run the steps as separate commands"
    for seg in segs:
        args, err = check_redirects(seg)
        if err:
            return err
        why = check_segment(args)
        if why:
            return why
    return None


def brief_lint(prompt):
    probs = [why for rx, why in BRIEF_FORBIDDEN if rx.search(prompt)]
    if not re.search(r"\brun_id\b", prompt):
        probs.append("names no run_id")
    if not re.search(r"\bmode\b\W{0,4}(acceptance|refute)\b", prompt, re.I):
        probs.append("names no mode (acceptance | refute)")
    if len(prompt) > 4000:
        probs.append("is %d characters — a brief is paths and a mode, not an account" % len(prompt))
    return probs


def main():
    if os.path.exists(".claude/.no-judge-guard"):
        return 0
    try:
        hook = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return 0
    tool = hook.get("tool_name") or ""
    ti = hook.get("tool_input") or {}
    if tool in ("Agent", "Task"):
        if base(ti.get("subagent_type")) not in judges():
            return 0
        probs = brief_lint(ti.get("prompt") or "")
        if probs:
            return deny("the brief to `%s` %s. A judge gets paths and a mode only — run_id, mode, the contract or "
                        "candidate files, the diff — never the builder's account of its work "
                        "(templates/snippets/delegation-brief.md). Rewrite the brief and dispatch again."
                        % (ti.get("subagent_type"), "; ".join(dict.fromkeys(probs))))
        return 0
    if base(hook.get("agent_type")) not in judges():
        return 0
    if tool in ("Read", "Grep", "Glob"):
        target = ti.get("file_path") or ti.get("path") or ""
        if target and NARRATIVE_PATHS.search(target.replace(os.sep, "/")):
            return deny("%s is the builder's narrative (ledger, commit message, session log, status entry). A judge "
                        "grades the code and the contract, not the account of them." % target)
        return 0
    if tool == "Bash":
        why = check_bash(ti.get("command") or "")
        return deny(why + ". Allowed: tests and test runners, linters/type checkers/scanners in check mode, "
                    "read-only shell and git, probes to localhost, scratch files under /tmp.") if why else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
