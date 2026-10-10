#!/usr/bin/env python3
"""ci-graph.py — the GitHub Actions job graph, for checks a regex cannot decide.

WHY. Who needs whom, which job holds which permission and environment, what a concurrency group
covers and which job a required check names are cross-job facts. A grep sees one line; this script
parses every workflow with a real YAML loader and joins them. Detectors (devops pipeline-integrity,
pipeline-cache, deploy-safety; security ci-security-scan; testing suite-execution-scan) take its rows
as structural facts and still read the code before reporting (precedents/devops.md).

LOADER. PyYAML, else Ruby psych (`ruby -ryaml`), else `uv run --with pyyaml==6.0.2` (may need the
network; CI_GRAPH_NO_UV=1 disables it), else exit 2 `NOT-RUN (no YAML loader)`. No hand-rolled YAML
subset: one that fails silently would print "clean". YAML 1.1 loaders read the `on:` key as boolean
true, so it is remapped to "on" (precedents/devops.md § 44). Line numbers come from a text scan,
because the loaders drop marks.

Usage:
  ci-graph.py [ROOT|FILE…] [--all | --check=pin-priv,deploy-concurrency,deploy-gate,timeout,matrix,cache-keys]
              [--required [--repo=o/r] [--branch=b] | --contexts=a,b [--merge-queue] | --settings-dir=DIR [--branch=b]]
              [--deploy-ancestors]
              [--job-of=FILE:LINE] [--shell-of=FILE:LINE] [--serial-chains] [--json]
  ci-graph.py [ROOT] --diff-guard=<git-ref> [--allow-job=FILE:JOB …] [--allow-workflow=FILE:KEY …]
  ci-graph.py --diff-guard OLD.yml NEW.yml [--allow-job=FILE:JOB …] [--allow-workflow=FILE:KEY …]
--settings-dir=DIR reads the same `gh api` responses offline from JSON files (rules-branches-<b>.json,
required-status-checks.json, environments.json, rulesets.json): the required join as --required would, plus
ENVIRONMENT and RULESET fact rows. No token, no network; a DIR with no rules file is UNREADABLE (exit 2).
Only the `=` forms take a value: `--diff-guard REF` (a space) means "two files follow", and a bare
`--allow-job` / `--allow-workflow` is refused (exit 2). `--allow-workflow` names ONE workflow-level key
(on, concurrency, permissions); it never lets a job's keys through — that is `--allow-job`.
  ci-graph.py --self-test
Rows: `file:line: CODE key=value…`. Exit 0 clean · 1 at least one finding row · 2 NOT-RUN (no loader,
a parse error, no workflow found, the settings API unreadable). No arguments = `. --all`.
GitHub Actions only; GitLab, CircleCI and Azure are grep + read until they are modelled.
"""
import contextlib, io, json, os, re, shutil, subprocess, sys, tempfile
from itertools import product

# kubectl takes global flags before the verb in most CI shapes (`kubectl --kubeconfig "$K" -n ns apply`): the
# flag-tolerant form gitops-audit's OOB pattern uses — any run of non-separator text, then whitespace, then the verb.
KUBECTL = r"kubectl\b[^\n|;&]*?\s"
MUT = re.compile(r"\b(" + KUBECTL + r"(apply|set\s+image|replace|rollout\s+restart)|kustomize\s+edit\s+set\s+image|helm\s+(upgrade|install|rollback)|terraform\s+apply|tofu\s+apply|pulumi\s+up|fly\s+deploy|railway\s+up|vercel\b[^\n]*--prod|netlify\s+deploy[^\n]*--prod|npm\s+publish|pnpm\s+publish|yarn\s+npm\s+publish|twine\s+upload|cargo\s+publish|gem\s+push|docker\s+(push|buildx\s+imagetools\s+create)|crane\s+(copy|tag)|gh\s+release\s+(create|upload)|aws\s+(ecs\s+update-service|lambda\s+update-function-code|s3\s+sync)|gcloud\s+run\s+deploy|az\s+webapp\s+deploy|serverless\s+deploy|cdk\s+deploy|argocd\s+app\s+sync)\b")
# The MUT verbs that only publish an artifact (a package, an image, a release asset) and deploy no environment:
# a job whose only verb is one of these is `deploy-via=publish-verb` — JOB prints it as publishes=yes, deploys=no,
# and the deploy-concurrency check skips DEPLOY-NOGROUP / GROUP-NOT-ENV for it (DEPLOY-CANCEL still fires).
PUB_VERB = re.compile(r"\b(npm\s+publish|pnpm\s+publish|yarn\s+npm\s+publish|twine\s+upload|cargo\s+publish|gem\s+push|docker\s+(push|buildx\s+imagetools\s+create)|crane\s+(copy|tag)|gh\s+release\s+(create|upload))\b")
# A deploy made by an action, not a shell verb: any action whose name says deploy (azure/webapps-deploy,
# aws-actions/amazon-ecs-deploy-task-definition, google-github-actions/deploy-cloudrun, actions/deploy-pages,
# easingthemes/ssh-deploy…, and a local `./.github/actions/deploy`; `deployment` status actions such as
# chrnorm/deployment-action excluded), plus remote-shell and hosting actions
# whose only job is to ship. CMD_DEPLOY: actions that deploy only for some command input (None = the default
# command deploys unless `command:` says otherwise).
DEPLOY_ACTIONS = re.compile(r"^[^@]*deploy(?!ment)|^(appleboy/(ssh|scp)-action|burnett01/rsync-deployments|amondnet/vercel-action|nwtgck/actions-netlify|peaceiris/actions-gh-pages|azure/functions-action|dokku/github-action)@", re.I)
CMD_DEPLOY = {"superfly/flyctl-actions": ("args", r"\bdeploy\b"), "pulumi/actions": ("command", r"^\s*up\b"),
              "cloudflare/wrangler-action": ("command", None)}
ACTION_SHELL_INPUTS = ("script", "run", "command", "args", "cmd")
PUBLISH_ACTIONS = re.compile(r"^(docker/build-push-action|pypa/gh-action-pypi-publish|softprops/action-gh-release|goreleaser/goreleaser-action|JS-DevTools/npm-publish|changesets/action)@", re.I)
TESTISH = re.compile(r"\b((npm|pnpm|yarn|bun)\s+(run\s+)?test\b|npx\s+(jest|vitest|mocha|playwright\s+test|cypress\s+run)|jest\b|vitest\b|pytest\b|tox\b|nox\b|go\s+test\b|cargo\s+(test|nextest)\b|mvn\b[^\n]*\b(test|verify)\b|gradlew?\b[^\n]*\b(test|check)\b|rspec\b|phpunit\b|artisan\s+test\b|dotnet\s+test\b|mix\s+test\b|make\s+(test|check)\b)")
STATUS_FN = re.compile(r"\b(always|failure|cancelled)\s*\(\s*\)|success\(\)\s*\|\|\s*failure\(\)")
WAIT = re.compile(r"\b(" + KUBECTL + r"rollout\s+status|argo\s+rollouts\s+status|helm\s+(upgrade|install)\b[^\n]*--wait)\b")
SHA = re.compile(r"^[0-9a-f]{40}$")
FINDING = {"PIN×PRIV", "DEPLOY-CANCEL", "DEPLOY-NOGROUP", "GROUP-NOT-ENV", "ENV-SPLIT-GROUPS", "DEPLOY-UNGATED",
           "DEPLOY-ALWAYS", "WORKFLOW_RUN-NO-CONCLUSION", "NO-TIMEOUT", "WAIT-NO-TIMEOUT", "MATRIX-EXCLUDES-RUNTIME",
           "MATRIX-DYNAMIC-UNGUARDED", "CACHE-KEY-NO-HASH", "CACHE-NODE-MODULES", "CACHE-PREFIX-SKIP-INSTALL",
           "REQUIRED-UNMATCHED", "REQUIRED-PATH-FILTERED", "REQUIRED-IF-SKIP", "REQUIRED-NEEDS-SKIP", "NO-MERGE-GROUP",
           "DUP-NAME", "AGGREGATOR-WEAK", "GUARD-CHANGED", "GUARD-JOB-REMOVED", "GUARD-JOB-ADDED"}
CHECKS = ["pin-priv", "deploy-concurrency", "deploy-gate", "timeout", "matrix", "cache-keys"]
GUARD_JOB_KEYS = ["if", "needs", "concurrency", "permissions", "environment", "runs-on", "secrets"]
GUARD_WF_KEYS = ["on", "concurrency", "permissions"]

# ---------------------------------------------------------------- loading
RUBY = ("require 'yaml'; require 'json'; require 'date'; out = ARGV.map { |f| begin; "
        "{'path' => f, 'data' => YAML.safe_load(File.read(f), permitted_classes: [Date, Time, Symbol], aliases: true)}; "
        "rescue Exception => e; {'path' => f, 'error' => e.message.lines.first.to_s.strip}; end }; puts JSON.generate(out)")
PYLOAD = ("import json,sys,yaml\nout=[]\nfor f in sys.argv[1:]:\n  try: out.append({'path':f,'data':yaml.safe_load(open(f))})\n"
          "  except Exception as e: out.append({'path':f,'error':str(e).splitlines()[0] if str(e) else type(e).__name__})\n"
          "print(json.dumps(out,default=str))")
_LOADER = []


def loader():
    if _LOADER:
        return _LOADER[0]
    kind = None
    try:
        import yaml  # noqa: F401
        kind = "pyyaml"
    except ImportError:
        if shutil.which("ruby") and subprocess.run(["ruby", "-ryaml", "-e", ""], capture_output=True).returncode == 0:
            kind = "ruby-psych"
        elif shutil.which("uv") and not os.environ.get("CI_GRAPH_NO_UV"):
            kind = "uv-pyyaml"
    _LOADER.append(kind)
    return kind


def load_many(paths):
    """{path: (data, error)}; data has the `on` key remapped."""
    kind, res = loader(), {}
    if not paths:
        return res
    if kind == "pyyaml":
        import yaml
        for p in paths:
            try:
                res[p] = (yaml.safe_load(open(p, encoding="utf-8")), None)
            except Exception as e:  # noqa: BLE001 — any loader error is a NOT-RUN row
                res[p] = (None, (str(e).splitlines() or [type(e).__name__])[0])
    elif kind in ("ruby-psych", "uv-pyyaml"):
        cmd = (["ruby", "-e", RUBY] if kind == "ruby-psych" else
               ["uv", "run", "--quiet", "--no-project", "--with", "pyyaml==6.0.2", "python3", "-c", PYLOAD])
        r = subprocess.run(cmd + list(paths), capture_output=True, text=True, timeout=180)
        if r.returncode != 0:
            for p in paths:
                res[p] = (None, "loader failed: " + (r.stderr.strip().splitlines() or ["?"])[-1][:160])
        else:
            for o in json.loads(r.stdout):
                res[o["path"]] = (o.get("data"), o.get("error"))
    for p, (d, e) in list(res.items()):
        if isinstance(d, dict) and "on" not in d:
            for k in (True, "true"):
                if k in d:
                    d["on"] = d.pop(k)
    return res


# ---------------------------------------------------------------- line index (loaders drop marks)
def indent(l):
    return len(l) - len(l.lstrip(" "))


def meaningful(l):
    s = l.strip()
    return s and not s.startswith("#")


class Index:
    def __init__(self, path):
        self.lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
        self.jobs = {}  # id -> (start, end) 1-based inclusive
        n, jl = len(self.lines), None
        for i, l in enumerate(self.lines):
            if re.match(r"^jobs\s*:\s*(#.*)?$", l):
                jl = i
                break
        if jl is None:
            return
        ind, starts = None, []
        for i in range(jl + 1, n):
            l = self.lines[i]
            if not meaningful(l):
                continue
            if indent(l) == 0:
                n = i
                break
            if ind is None:
                ind = indent(l)
            m = re.match(r"^ {%d}([\w-]+|\"[^\"]+\"|'[^']+')\s*:" % ind, l)
            if m:
                starts.append((m.group(1).strip("'\""), i))
        for k, (jid, s) in enumerate(starts):
            e = (starts[k + 1][1] if k + 1 < len(starts) else n) - 1
            self.jobs[jid] = (s + 1, e + 1)

    def key_line(self, key, lo=1, hi=None, nth=0):
        hi = hi or len(self.lines)
        pat = re.compile(r"^\s*(-\s+)?%s\s*:" % re.escape(key))
        seen = 0
        for i in range(lo - 1, min(hi, len(self.lines))):
            if pat.match(self.lines[i]):
                if seen == nth:
                    return i + 1
                seen += 1
        return 0

    def top_line(self, key):
        for i, l in enumerate(self.lines):
            if re.match(r"^%s\s*:" % re.escape(key), l):
                return i + 1
        return 0

    def steps(self, jid):
        """[(start, end)] of each step of a job, 1-based."""
        if jid not in self.jobs:
            return []
        lo, hi = self.jobs[jid]
        sl = self.key_line("steps", lo, hi)
        if not sl:
            return []
        base, out, item = indent(self.lines[sl - 1]), [], None
        for i in range(sl, hi):
            l = self.lines[i]
            if not meaningful(l):
                continue
            if indent(l) <= base and not l.lstrip().startswith("-"):
                break
            if l.lstrip().startswith("- "):
                if item is None:
                    item = indent(l)
                if indent(l) == item:
                    out.append(i + 1)
                elif indent(l) < item:
                    break
        return [(s, (out[k + 1] - 1 if k + 1 < len(out) else hi)) for k, s in enumerate(out)]

    def job_at(self, line):
        for jid, (s, e) in self.jobs.items():
            if s <= line <= e:
                return jid
        return None


# ---------------------------------------------------------------- model
def perms(x):
    if x is None:
        return None
    if isinstance(x, str):
        return {"*": "write"} if x == "write-all" else {"*": "read"} if x == "read-all" else {}
    return {str(k): str(v) for k, v in (x or {}).items()} if isinstance(x, dict) else {}


def triggers(on):
    if isinstance(on, str):
        return {on: {}}
    if isinstance(on, list):
        return {str(t): {} for t in on}
    return {str(k): (v or {}) for k, v in on.items()} if isinstance(on, dict) else {}


def needs_of(j):
    n = j.get("needs") or []
    return [n] if isinstance(n, str) else [str(x) for x in n]


def env_name(j):
    e = j.get("environment")
    return str(e.get("name", "")) if isinstance(e, dict) else (str(e) if e else "")


def run_text(j):
    return "\n".join(str(s.get("run", "")) for s in (j.get("steps") or []) if isinstance(s, dict))


class Workflow:
    def __init__(self, path, data, rel):
        self.path, self.rel, self.d, self.ix = path, rel, data if isinstance(data, dict) else {}, Index(path)
        self.on = triggers(self.d.get("on"))
        self.perms = perms(self.d.get("permissions"))
        self.conc = self.d.get("concurrency")
        self.jobs = {str(k): (v if isinstance(v, dict) else {}) for k, v in (self.d.get("jobs") or {}).items()}

    def jl(self, jid):
        return self.ix.jobs.get(jid, (0, 0))[0]

    def job_perms(self, jid):
        j = self.jobs[jid]
        return perms(j.get("permissions")) if "permissions" in j else self.perms

    def privileged(self, jid):
        j, p = self.jobs[jid], self.job_perms(jid) or {}
        why = sorted(k for k, v in p.items() if v == "write")
        if env_name(j):
            why.append("environment")
        if "secrets." in json.dumps(j.get("steps") or []) or j.get("secrets") == "inherit":
            why.append("secrets")
        return why

    def deploy_via(self, jid):
        """Why a job counts as a deploy: environment, a shell verb, a deploy action, or "" (not a deploy)."""
        j = self.jobs[jid]
        if env_name(j):
            return "environment"
        rt = run_text(j)
        if any(not PUB_VERB.fullmatch(m.group(0)) for m in MUT.finditer(rt)):
            return "verb"
        for s in j.get("steps") or []:
            if not isinstance(s, dict) or not s.get("uses"):
                continue
            u, w = str(s["uses"]), (s.get("with") or {}) if isinstance(s.get("with"), dict) else {}
            name = u.split("@", 1)[0].lower()
            cmd = next(((k, rx) for a, (k, rx) in CMD_DEPLOY.items() if name == a), None)
            if cmd:
                v = str(w.get(cmd[0], "")).strip()
                if (cmd[1] is None and (not v or re.search(r"\b(deploy|publish)\b", v))) or (cmd[1] and re.search(cmd[1], v)):
                    return "action:" + name
                continue
            if DEPLOY_ACTIONS.match(u):
                return "action:" + name
            if MUT.search("\n".join(str(w.get(k, "")) for k in ACTION_SHELL_INPUTS)):
                return "action-input:" + name
        return "publish-verb" if MUT.search(rt) else ""

    def deploys(self, jid):
        return bool(self.deploy_via(jid))

    def publishes(self, jid):
        for s in self.jobs[jid].get("steps") or []:
            if isinstance(s, dict) and PUBLISH_ACTIONS.match(str(s.get("uses", ""))):
                w = s.get("with") or {}
                if "build-push-action" not in str(s.get("uses")) or str(w.get("push", "")).lower() not in ("", "false"):
                    return True
                # push via the exporter, no `push:` input: outputs: type=image,push=true / type=registry
                if re.search(r"\bpush\s*=\s*true\b|\btype\s*=\s*registry\b", str(w.get("outputs", "")), re.I):
                    return True
        return False

    def testish(self, jid):
        j = self.jobs[jid]
        return bool(TESTISH.search(run_text(j))) or ("uses" in j and re.search(r"test|check|ci", jid + str(j.get("name", "")), re.I))

    def ancestors(self, jid, seen=None):
        seen = set() if seen is None else seen
        for n in needs_of(self.jobs.get(jid, {})):
            if n in self.jobs and n not in seen:
                seen.add(n)
                self.ancestors(n, seen)
        return seen

    def check_names(self, jid):
        j = self.jobs[jid]
        name = str(j.get("name") or jid)
        m = (j.get("strategy") or {}).get("matrix")
        if not isinstance(m, dict):
            return [name]
        combos = matrix_combos(m)
        if not combos:
            return [name]
        out = []
        for c in combos:
            if "${{" in name:
                out.append(re.sub(r"\$\{\{\s*matrix\.([\w-]+)\s*\}\}", lambda x: str(c.get(x.group(1), "")), name))
            else:
                out.append("%s (%s)" % (name, ", ".join(str(v) for v in c.values())))
        return out


def matrix_combos(m):
    keys = [k for k, v in m.items() if k not in ("include", "exclude") and isinstance(v, list)]
    if any(isinstance(v, str) for k, v in m.items() if k not in ("include", "exclude")):
        return []
    combos = [dict(zip(keys, vals)) for vals in product(*[m[k] for k in keys])] if keys else []
    for ex in m.get("exclude") or []:
        if isinstance(ex, dict):
            combos = [c for c in combos if not all(str(c.get(k)) == str(v) for k, v in ex.items())]
    for inc in m.get("include") or []:
        if isinstance(inc, dict):
            hit = [c for c in combos if all(str(c.get(k)) == str(v) for k, v in inc.items() if k in keys)]
            if not hit or not any(k in keys for k in inc):
                combos.append(dict(inc))
    return combos


# ---------------------------------------------------------------- checks
def row(rows, wf, line, code, **kv):
    rows.append({"file": wf.rel if wf else "-", "line": line, "code": code, **kv})


def c_pin_priv(wf, rows):
    for jid, j in wf.jobs.items():
        why = wf.privileged(jid)
        if not why:
            continue
        lo, hi = wf.ix.jobs.get(jid, (1, None))
        uses = [str(s.get("uses")) for s in (j.get("steps") or []) if isinstance(s, dict) and s.get("uses")]
        if j.get("uses"):
            uses.append(str(j["uses"]))
        seen = {}
        for u in uses:
            if u.startswith("./"):
                continue
            if u.startswith("docker://"):
                pinned = "@sha256:" in u
            else:
                pinned = bool(SHA.match(u.split("@", 1)[1])) if "@" in u else False
            nth = seen.get(u, 0)
            seen[u] = nth + 1
            if not pinned:
                line = find_value_line(wf.ix, "uses", u, lo, hi, nth)
                fp = u.split("/", 1)[0].lower() in ("actions", "github")
                row(rows, wf, line, "PIN×PRIV", job=jid, uses=u, perms=",".join(why), **({"party": "first-party"} if fp else {}))


def find_value_line(ix, key, val, lo, hi, nth=0):
    pat = re.compile(r"^\s*(-\s+)?%s\s*:\s*['\"]?%s['\"]?\s*(#.*)?$" % (re.escape(key), re.escape(val)))
    seen = 0
    for i in range(lo - 1, min(hi or len(ix.lines), len(ix.lines))):
        if pat.match(ix.lines[i]):
            if seen == nth:
                return i + 1
            seen += 1
    return lo


def conc_parts(c):
    if isinstance(c, str):
        return c, False
    if isinstance(c, dict):
        return str(c.get("group", "")), c.get("cancel-in-progress")
    return "", False


def env_keyed(group, env):
    g = group.lower()
    if re.search(r"environment|inputs\.env|matrix\.env|\benv\b", g):
        return True
    e = env.lower()
    return bool(e) and (e in g or (len(e) >= 4 and e[:4] in g))


def c_deploy_concurrency(wf, rows, env_groups):
    for jid, j in wf.jobs.items():
        via = wf.deploy_via(jid)
        if not via:
            continue
        env, line = env_name(j), wf.jl(jid)
        scope, c = ("job", j.get("concurrency")) if j.get("concurrency") is not None else ("workflow", wf.conc)
        group, cancel = conc_parts(c)
        if c is not None and env:
            env_groups.setdefault(env, set()).add((wf.rel, group))
        if cancel is True or str(cancel).lower() == "true" or "${{" in str(cancel):
            span = wf.ix.jobs.get(jid, (1, None)) if scope == "job" else (1, None)
            cl = wf.ix.key_line("cancel-in-progress", *span) if scope == "job" else top_conc_line(wf, "cancel-in-progress")
            kv = {"scope": scope, "job": jid, "group": group, "env": env or "-"}
            if "${{" in str(cancel):
                kv["cancel"] = str(cancel)
            row(rows, wf, cl or line, "DEPLOY-CANCEL", **kv)
        elif via == "publish-verb":
            continue   # publish-only: no environment to serialise; release-integrity-scan §3 owns a re-run that re-publishes
        elif c is None:
            row(rows, wf, line, "DEPLOY-NOGROUP", job=jid, env=env or "-")
        elif not env_keyed(group, env):
            row(rows, wf, line, "GROUP-NOT-ENV", job=jid, group=group, env=env or "-")


def top_conc_line(wf, key):
    s = wf.ix.top_line("concurrency")
    if not s:
        return 0
    for i in range(s, len(wf.ix.lines)):
        l = wf.ix.lines[i]
        if meaningful(l) and indent(l) == 0:
            break
        if re.match(r"^\s+%s\s*:" % re.escape(key), l):
            return i + 1
    return s


def c_deploy_gate(wf, rows):
    for jid, j in wf.jobs.items():
        if not (wf.deploys(jid) or wf.publishes(jid)):
            continue
        anc = wf.ancestors(jid)
        line = wf.jl(jid)
        if not any(wf.testish(a) for a in anc) and not wf.testish(jid):
            row(rows, wf, line, "DEPLOY-UNGATED", job=jid, needs=",".join(sorted(anc)) or "-")
        for a in [jid] + sorted(anc):
            cond = str(wf.jobs[a].get("if", ""))
            if STATUS_FN.search(cond):
                row(rows, wf, wf.ix.key_line("if", *wf.ix.jobs.get(a, (1, None))) or line, "DEPLOY-ALWAYS",
                    job=jid, via=a, **{"if": cond.strip()})
                break
        if "workflow_run" in wf.on and "conclusion" not in " ".join(str(wf.jobs[a].get("if", "")) for a in [jid] + sorted(anc)):
            row(rows, wf, line, "WORKFLOW_RUN-NO-CONCLUSION", job=jid)


def c_timeout(wf, rows):
    for jid, j in wf.jobs.items():
        if "uses" not in j and "timeout-minutes" not in j:
            row(rows, wf, wf.jl(jid), "NO-TIMEOUT", job=jid)
        for k, s in enumerate(j.get("steps") or []):
            r = str(s.get("run", "")) if isinstance(s, dict) else ""
            for m in WAIT.finditer(r):
                tail = r[m.start():].split("\n", 1)[0]
                if "--timeout" not in tail and "timeout-minutes" not in s:
                    sp = wf.ix.steps(jid)
                    row(rows, wf, sp[k][0] if k < len(sp) else wf.jl(jid), "WAIT-NO-TIMEOUT", job=jid, step=k + 1, cmd=m.group(0))


RUNTIME_KEYS = re.compile(r"^(node|node-version|nodejs|python|python-version|go|go-version|ruby|ruby-version|java|java-version|php|php-version|dotnet|dotnet-version)$", re.I)


def declared_runtimes(root):
    out = set()
    for f in (".nvmrc", ".node-version", ".python-version", ".ruby-version", ".go-version"):
        p = os.path.join(root, f)
        if os.path.isfile(p):
            out |= set(re.findall(r"\d+(?:\.\d+)?", open(p).read())[:1])
    pj = os.path.join(root, "package.json")
    if os.path.isfile(pj):
        try:
            out |= set(re.findall(r"\d+", str((json.load(open(pj)).get("engines") or {}).get("node", ""))))
        except (ValueError, OSError):
            pass
    return out


def c_matrix(wf, rows, root):
    decl = declared_runtimes(root)
    for jid, j in wf.jobs.items():
        m = (j.get("strategy") or {}).get("matrix")
        line = wf.ix.key_line("matrix", *wf.ix.jobs.get(jid, (1, None))) or wf.jl(jid)
        if isinstance(m, str) and "fromjson" in m.lower().replace(" ", ""):
            if not re.search(r"!=\s*['\"](\[\])?['\"]|length|!\s*fromjson", str(j.get("if", "")), re.I):
                row(rows, wf, line, "MATRIX-DYNAMIC-UNGUARDED", job=jid, matrix=m)
            continue
        if not isinstance(m, dict):
            continue
        combos = matrix_combos(m)
        for k, vals in m.items():
            if not RUNTIME_KEYS.match(str(k)) or not isinstance(vals, list):
                continue
            for v in vals:
                if not any(str(c.get(k)) == str(v) for c in combos):
                    row(rows, wf, line, "MATRIX-EXCLUDES-RUNTIME", job=jid, key=k, value=v,
                        declared=",".join(sorted(decl)) or "none-read")


def c_cache_keys(wf, rows):
    for jid, j in wf.jobs.items():
        steps, sp = j.get("steps") or [], wf.ix.steps(jid)
        for k, s in enumerate(steps):
            if not isinstance(s, dict) or not re.match(r"actions/cache(/restore|/save)?@", str(s.get("uses", ""))):
                continue
            w, line = s.get("with") or {}, (sp[k][0] if k < len(sp) else wf.jl(jid))
            if "hashFiles(" not in str(w.get("key", "")):
                row(rows, wf, line, "CACHE-KEY-NO-HASH", job=jid, step=k + 1, key=str(w.get("key", "")))
            if "node_modules" in str(w.get("path", "")):
                row(rows, wf, line, "CACHE-NODE-MODULES", job=jid, step=k + 1)
            sid = s.get("id")
            if w.get("restore-keys") and sid:
                for t in steps[k + 1:]:
                    cond = str(t.get("if", "")) if isinstance(t, dict) else ""
                    if "steps.%s.outputs.cache-hit" % sid in cond and not re.search(r"cache-hit\s*[!=]=\s*['\"]true['\"]", cond):
                        row(rows, wf, line, "CACHE-PREFIX-SKIP-INSTALL", job=jid, step=k + 1, **{"if": cond})


# ---------------------------------------------------------------- required checks
def gh_json(args):
    if not shutil.which("gh"):
        return None, "gh not installed"
    r = subprocess.run(["gh", "api"] + args, capture_output=True, text=True, timeout=60)
    if r.returncode == 0:
        try:
            return json.loads(r.stdout or "null"), None
        except ValueError:
            return None, "unparseable response"
    return None, (r.stderr.strip().splitlines() or ["exit %d" % r.returncode])[0][:160]


def fetch_required(root, repo, branch):
    if not repo:
        r = subprocess.run(["git", "-C", root, "remote", "get-url", "origin"], capture_output=True, text=True)
        m = re.search(r"github\.com[:/]([^/]+/[^/.\s]+)", r.stdout)
        repo = m.group(1) if m else None
    if not repo:
        return None, False, "no GitHub origin (pass --repo=o/r or --contexts=…)"
    if not branch:
        d, err = gh_json(["repos/%s" % repo])
        if err:
            return None, False, "gh api repos/%s: %s" % (repo, err)
        branch = d.get("default_branch", "main")
    ctx, mq, readable = set(), False, 0
    d, err = gh_json(["repos/%s/rules/branches/%s" % (repo, branch)])
    if not err:
        readable += 1
        for r in d or []:
            if r.get("type") == "required_status_checks":
                ctx |= {c.get("context") for c in (r.get("parameters") or {}).get("required_status_checks", [])}
            if r.get("type") == "merge_queue":
                mq = True
    d, err2 = gh_json(["repos/%s/branches/%s/protection/required_status_checks" % (repo, branch)])
    if not err2:
        readable += 1
        ctx |= set(d.get("contexts") or []) | {c.get("context") for c in d.get("checks") or []}
    elif "not protected" in err2.lower():
        readable += 1
    if not readable:
        return None, False, "gh api repos/%s/rules/branches/%s: %s" % (repo, branch, err)
    return {c for c in ctx if c}, mq, None


def settings_dir(root, d, branch, wfs, rows):
    """Offline settings: the same read-only `gh api` responses saved as JSON files in DIR (a snapshot, a fixture).
    rules-branches-<branch>.json (GET …/rules/branches/<b>) and/or required-status-checks.json (GET …/branches/<b>/
    protection/required_status_checks) give the required set and the merge queue; environments.json (GET …/environments)
    gives ENVIRONMENT rows; rulesets.json (GET …/rulesets) gives RULESET rows. Returns (contexts, merge_queue, error)."""
    base = d if os.path.isabs(d) else os.path.join(root, d)
    if not os.path.isdir(base):
        return None, False, "settings-dir %s: not a directory" % d
    rel = lambda f: os.path.relpath(os.path.join(base, f), root)

    def load(f):
        try:
            return json.load(open(os.path.join(base, f))), open(os.path.join(base, f)).read().split("\n")
        except (OSError, ValueError) as e:
            return None, str(e)[:120]

    def line_of(lines, pat, start=0):
        for i in range(start, len(lines)):
            if re.search(pat, lines[i]):
                return i + 1
        return 0
    rules = sorted(f for f in os.listdir(base) if re.match(r"rules-branches-.+\.json$", f))
    if branch:
        rules = [f for f in rules if f == "rules-branches-%s.json" % branch]
    elif len(rules) > 1:
        rules = [f for f in rules if f in ("rules-branches-main.json", "rules-branches-master.json")][:1] or rules[:1]
    ctx, mq, read = set(), False, 0
    for f in rules:
        dd, _ = load(f)
        if isinstance(dd, list):
            read += 1
            for r in dd:
                if r.get("type") == "required_status_checks":
                    ctx |= {c.get("context") for c in (r.get("parameters") or {}).get("required_status_checks", [])}
                if r.get("type") == "merge_queue":
                    mq = True
    if os.path.isfile(os.path.join(base, "required-status-checks.json")):
        dd, _ = load("required-status-checks.json")
        if isinstance(dd, dict):
            read += 1
            ctx |= set(dd.get("contexts") or []) | {c.get("context") for c in dd.get("checks") or []}
    if os.path.isfile(os.path.join(base, "environments.json")):
        dd, lines = load("environments.json")
        envs = (dd or {}).get("environments") if isinstance(dd, dict) else None
        used = {env_name(wf.jobs[j]) for wf in wfs for j in wf.jobs if env_name(wf.jobs[j]) and "${{" not in env_name(wf.jobs[j])}
        for e in envs or []:
            name = str(e.get("name"))
            nl = line_of(lines, r'"name"\s*:\s*"%s"' % re.escape(name))
            pol = e.get("deployment_branch_policy")
            bp = "NONE" if not pol else ("protected" if pol.get("protected_branches") else "custom")
            revs = sum(len(r.get("reviewers") or []) for r in e.get("protection_rules") or [] if r.get("type") == "required_reviewers")
            wait = sum(int(r.get("wait_timer") or 0) for r in e.get("protection_rules") or [] if r.get("type") == "wait_timer")
            line = (line_of(lines, r'"deployment_branch_policy"\s*:\s*null', nl) if bp == "NONE" else 0) or nl
            rows.append({"file": rel("environments.json"), "line": line, "code": "ENVIRONMENT", "env": name, "branch-policy": bp,
                         "reviewers": revs, "wait-timer": wait, "admin-bypass": "yes" if e.get("can_admins_bypass") else "no",
                         "used-by-workflows": "yes" if name in used else "no"})
        for name in sorted(used - {str(e.get("name")) for e in envs or []}):
            rows.append({"file": rel("environments.json"), "line": 1, "code": "ENVIRONMENT", "env": name, "branch-policy": "ABSENT",
                         "note": "not in the snapshot: GitHub creates it unprotected on first use"})
    if os.path.isfile(os.path.join(base, "rulesets.json")):
        dd, lines = load("rulesets.json")
        tags = 0
        for r in dd if isinstance(dd, list) else []:
            tags += r.get("target") == "tag"
            rows.append({"file": rel("rulesets.json"), "line": line_of(lines, r'"id"\s*:\s*%s\b' % re.escape(str(r.get("id")))) or 1,
                         "code": "RULESET", "name": str(r.get("name")), "target": str(r.get("target")), "enforcement": str(r.get("enforcement"))})
        if isinstance(dd, list) and not tags:
            rows.append({"file": rel("rulesets.json"), "line": 1, "code": "RULESET", "target": "tag", "name": "NONE",
                         "note": "no tag ruleset: any writer can push or move a release tag"})
    if not read:
        return None, False, "settings-dir %s: no rules-branches-*.json or required-status-checks.json" % d
    return {c for c in ctx if c}, mq, None


def c_required(wfs, rows, contexts, mq):
    emitted = {}
    for wf in wfs:
        for jid in wf.jobs:
            for n in wf.check_names(jid):
                emitted.setdefault(n, []).append((wf, jid))
    req_jobs = set()
    for c in sorted(contexts):
        hits = emitted.get(c, [])
        if not hits:
            row(rows, None, 0, "REQUIRED-UNMATCHED", context=c)
            continue
        if len(hits) > 1:
            row(rows, hits[0][0], hits[0][0].jl(hits[0][1]), "DUP-NAME", context=c,
                jobs=",".join("%s:%s" % (w.rel, j) for w, j in hits))
        for wf, jid in hits:
            req_jobs.add((wf.rel, jid))
            row(rows, wf, wf.jl(jid), "REQUIRED", context=c, job=jid)
    for wf in wfs:
        mine = [j for (r, j) in req_jobs if r == wf.rel]
        if not mine:
            continue
        for ev in ("pull_request", "push", "merge_group"):
            t = wf.on.get(ev)
            if isinstance(t, dict) and any(k in t for k in ("paths", "paths-ignore", "branches", "branches-ignore")) and ev == "pull_request":
                row(rows, wf, wf.ix.top_line("on") or 1, "REQUIRED-PATH-FILTERED", event=ev, jobs=",".join(sorted(mine)),
                    filters=",".join(k for k in ("paths", "paths-ignore", "branches", "branches-ignore") if k in t))
        if mq and "merge_group" not in wf.on:
            row(rows, wf, wf.ix.top_line("on") or 1, "NO-MERGE-GROUP", jobs=",".join(sorted(mine)))
        for jid in mine:
            j, cond = wf.jobs[jid], str(wf.jobs[jid].get("if", ""))
            span = wf.ix.jobs.get(jid, (1, None))
            if cond and not STATUS_FN.search(cond):
                row(rows, wf, wf.ix.key_line("if", *span) or wf.jl(jid), "REQUIRED-IF-SKIP", job=jid, **{"if": cond.strip()})
            loose = [a for a in wf.ancestors(jid) if (wf.rel, a) not in req_jobs]
            if loose and not re.search(r"always\(\)|!\s*cancelled\(\)", cond):
                row(rows, wf, wf.jl(jid), "REQUIRED-NEEDS-SKIP", job=jid, unrequired_needs=",".join(sorted(loose)))
            if len(needs_of(j)) >= 2 and re.search(r"always\(\)|!\s*cancelled\(\)", cond):
                body = cond + run_text(j)
                if "needs." not in body or (re.search(r"!=\s*['\"]failure['\"]", body) and "cancelled" not in body):
                    row(rows, wf, wf.jl(jid), "AGGREGATOR-WEAK", job=jid)


def c_deploy_ancestors(wfs, rows, req):
    for wf in wfs:
        dep = {j for j in wf.jobs if wf.deploys(j) or wf.publishes(j)}
        for jid in wf.jobs:
            of = sorted(d for d in dep if jid in wf.ancestors(d))
            r = "unknown" if req is None else ("yes" if (wf.rel, jid) in req else "no")
            via = wf.deploy_via(jid)
            row(rows, wf, wf.jl(jid), "JOB", job=jid, deploys="yes" if via and via != "publish-verb" else "no",
                publishes="yes" if wf.publishes(jid) or via == "publish-verb" else "no", env=env_name(wf.jobs[jid]) or "-",
                **{"deploy-via": via or "-", "ancestor-of": ",".join(of) or "-", "required": r})


def c_serial_chains(wf, rows):
    """pipeline-cache-scan §4 speed candidates (facts, not findings): maximal chains of >= 3 jobs in which each job
    needs exactly its parent and takes nothing from it — no download-artifact, no needs.<parent>.* read — and is not
    a deploy, publish, environment, reusable-workflow or status-function job (those needs are gates, not data)."""
    def parent(c):
        j = wf.jobs[c]
        ns = needs_of(j)
        if len(ns) != 1 or ns[0] not in wf.jobs or "uses" in j or env_name(j) or wf.deploys(c) or wf.publishes(c):
            return None
        body = json.dumps(j)
        if STATUS_FN.search(str(j.get("if", ""))) or "download-artifact" in body or "needs.%s." % ns[0] in body or "needs[" in body:
            return None
        return ns[0]
    up = {c: p for c, p in ((c, parent(c)) for c in wf.jobs) if p}
    seen = set()
    for leaf in sorted(set(up) - set(up.values())):
        path, guard = [leaf], 0
        while path[-1] in up and guard < 100:
            path.append(up[path[-1]])
            guard += 1
        path.reverse()
        if len(path) >= 3 and tuple(path) not in seen:
            seen.add(tuple(path))
            lo, hi = wf.ix.jobs.get(path[1], (1, None))
            row(rows, wf, wf.ix.key_line("needs", lo, hi) or wf.jl(path[1]), "SERIAL-CHAIN", jobs=">".join(path), handoff="none")


# ---------------------------------------------------------------- job-of / shell-of
def locate(wfs, spec, root):
    f, _, ln = spec.rpartition(":")
    target = os.path.normpath(os.path.join(root, f)) if not os.path.isabs(f) else f
    for wf in wfs:
        if os.path.normpath(wf.path) == target or wf.rel == os.path.normpath(f):
            return wf, int(ln)
    return None, int(ln or 0)


def job_of(wfs, spec, root, rows):
    wf, ln = locate(wfs, spec, root)
    jid = wf.ix.job_at(ln) if wf else None
    rows.append({"file": wf.rel if wf else spec.rpartition(":")[0], "line": ln, "code": "JOB-OF", "job": jid or "-",
                 "workflow": str(wf.d.get("name", "-")) if wf else "-"})


def shell_of(wfs, spec, root, rows):
    wf, ln = locate(wfs, spec, root)
    jid = wf.ix.job_at(ln) if wf else None
    if not jid:
        rows.append({"file": spec.rpartition(":")[0], "line": ln, "code": "SHELL", "job": "-", "shell": "-", "pipefail": "-", "source": "-"})
        return
    j, sp = wf.jobs.get(jid, {}), wf.ix.steps(jid)
    k = next((i for i, (s, e) in enumerate(sp) if s <= ln <= e), None)
    steps = j.get("steps") or []
    st = steps[k] if k is not None and k < len(steps) and isinstance(steps[k], dict) else {}
    jdef = ((j.get("defaults") or {}).get("run") or {}).get("shell")
    wdef = ((wf.d.get("defaults") or {}).get("run") or {}).get("shell")
    sh, src = (st.get("shell"), "step") if st.get("shell") else (jdef, "job") if jdef else (wdef, "workflow") if wdef else (None, "default")
    windows = "windows" in str(j.get("runs-on", "")).lower()
    if sh is None:
        eff, pf = ("pwsh", "n/a") if windows else ("bash -e {0}", "no")
    elif str(sh) == "bash":
        eff, pf = "bash --noprofile --norc -eo pipefail {0}", "yes"
    elif str(sh) == "sh":
        eff, pf = "sh -e {0}", "no"
    else:
        eff, pf = str(sh), "yes" if "pipefail" in str(sh) else "no"
    rows.append({"file": wf.rel, "line": ln, "code": "SHELL", "job": jid, "step": (k + 1) if k is not None else "-",
                 "shell": eff, "pipefail": pf, "source": src, "row": "ci-platform-semantics.md S1/S2"})


# ---------------------------------------------------------------- diff guard
def step_keys(steps):
    out, seen = {}, {}
    for i, s in enumerate(steps or []):
        if not isinstance(s, dict):
            continue
        base = s.get("id") or s.get("name") or s.get("uses") or ("run:" + str(s.get("run", "")).strip().split("\n")[0])
        n = seen.get(base, 0)
        seen[base] = n + 1
        out["%s#%d" % (base, n)] = s
    return out


def guard_pair(rel, old, new, allow_jobs, allow_wf, rows, new_ix=None):
    old, new = old if isinstance(old, dict) else {}, new if isinstance(new, dict) else {}
    line = lambda key, lo=1, hi=None: (new_ix.key_line(key, lo, hi) if new_ix else 0)
    for k in GUARD_WF_KEYS:
        a, b = old.get(k), new.get(k)
        if k == "on":
            a, b = triggers(a), triggers(b)
        if a != b:
            code = "GUARD-ALLOWED" if (rel, k) in allow_wf else "GUARD-CHANGED"
            rows.append({"file": rel, "line": (new_ix.top_line(k) if new_ix else 0), "code": code, "scope": "workflow",
                         "key": k, "before": json.dumps(a, sort_keys=True), "after": json.dumps(b, sort_keys=True)})
    oj, nj = old.get("jobs") or {}, new.get("jobs") or {}
    for jid in sorted(set(oj) | set(nj), key=str):
        ok = (rel, str(jid)) in allow_jobs
        span = new_ix.jobs.get(str(jid), (1, None)) if new_ix else (1, None)
        if jid not in nj or jid not in oj:
            code = "GUARD-ALLOWED" if ok else ("GUARD-JOB-REMOVED" if jid not in nj else "GUARD-JOB-ADDED")
            rows.append({"file": rel, "line": span[0] if jid in nj else 0, "code": code, "scope": "job=%s" % jid})
            continue
        a, b = oj[jid] or {}, nj[jid] or {}
        for k in GUARD_JOB_KEYS:
            if a.get(k) != b.get(k):
                rows.append({"file": rel, "line": line(k, *span) or span[0], "code": "GUARD-ALLOWED" if ok else "GUARD-CHANGED",
                             "scope": "job=%s" % jid, "key": k, "before": json.dumps(a.get(k), sort_keys=True),
                             "after": json.dumps(b.get(k), sort_keys=True)})
        sa, sb = step_keys(a.get("steps")), step_keys(b.get("steps"))
        for sk in sorted(set(sa) | set(sb)):
            x, y = (sa.get(sk) or {}).get("if"), (sb.get(sk) or {}).get("if")
            if x != y:
                rows.append({"file": rel, "line": span[0], "code": "GUARD-ALLOWED" if ok else "GUARD-CHANGED",
                             "scope": "job=%s step=%s" % (jid, sk), "key": "if", "before": json.dumps(x), "after": json.dumps(y)})


def diff_guard(root, files, ref, allow_jobs, allow_wf, rows):
    """Two files, or every workflow at ROOT against <ref>. Returns NOT-RUN messages."""
    notrun = []
    if len(files) == 2:
        res = load_many(files)
        for p in files:
            if res[p][1]:
                notrun.append("%s: %s" % (p, res[p][1]))
        if not notrun:
            rel = os.path.basename(files[1])
            same = lambda r: rel if r in (files[1], rel) else r
            guard_pair(rel, res[files[0]][0], res[files[1]][0], {(same(r), j) for r, j in allow_jobs},
                       {(same(w), k) for w, k in allow_wf}, rows, Index(files[1]))
        return notrun
    tmp = tempfile.mkdtemp(prefix="ci-graph-guard-")
    try:
        cur = workflow_files(root)
        r = subprocess.run(["git", "-C", root, "ls-tree", "-r", "--name-only", ref, "--", ".github/workflows"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return ["git ls-tree %s: %s" % (ref, r.stderr.strip()[:120])]
        olds = [p for p in r.stdout.split() if re.search(r"\.ya?ml$", p)]
        pairs = {}
        for rel in sorted(set(olds) | {os.path.relpath(p, root) for p in cur}):
            op = None
            if rel in olds:
                op = os.path.join(tmp, rel.replace("/", "__"))
                blob = subprocess.run(["git", "-C", root, "show", "%s:%s" % (ref, rel)], capture_output=True)
                open(op, "wb").write(blob.stdout)
            np_ = os.path.join(root, rel) if os.path.isfile(os.path.join(root, rel)) else None
            pairs[rel] = (op, np_)
        res = load_many([p for pr in pairs.values() for p in pr if p])
        for rel, (op, np_) in pairs.items():
            errs = [res[p][1] for p in (op, np_) if p and res[p][1]]
            if errs:
                notrun.append("%s: %s" % (rel, errs[0]))
                continue
            guard_pair(rel, res[op][0] if op else {}, res[np_][0] if np_ else {}, allow_jobs, allow_wf, rows,
                       Index(np_) if np_ else None)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return notrun


# ---------------------------------------------------------------- driver
def workflow_files(root):
    d = os.path.join(root, ".github", "workflows")
    return sorted(os.path.join(d, f) for f in os.listdir(d) if re.search(r"\.ya?ml$", f)) if os.path.isdir(d) else []


def fmt(r):
    kv = " ".join("%s=%s" % (k, (json.dumps(v) if isinstance(v, str) and (" " in v or v == "") else v))
                  for k, v in r.items() if k not in ("file", "line", "code"))
    return "%s:%s: %s %s" % (r["file"], r["line"], r["code"], kv)


def run(argv, out=sys.stdout):
    opts = {"check": [], "allow_job": set(), "allow_wf": set(), "pos": []}
    for a in argv:
        if a == "--all":
            opts["check"] = list(CHECKS)
        elif a.startswith("--check="):
            v = a.split("=", 1)[1]
            opts["check"] = list(CHECKS) if v == "all" else [c for c in v.split(",") if c]
            bad = [c for c in opts["check"] if c not in CHECKS]
            if bad:
                print("ci-graph: unknown check %s (known: %s)" % (",".join(bad), ",".join(CHECKS)), file=sys.stderr)
                return 2
        elif a in ("--allow-job", "--allow-workflow"):
            print("ci-graph: %s takes its value with '=' (%s=FILE:%s)" % (a, a, "JOB" if a == "--allow-job" else "KEY"), file=sys.stderr)
            return 2
        elif a.startswith("--allow-job="):
            f, _, j = a.split("=", 1)[1].rpartition(":")
            if not f or not j:
                print("ci-graph: --allow-job needs FILE:JOB (got %r)" % a, file=sys.stderr)
                return 2
            opts["allow_job"].add((os.path.normpath(f), j))
        elif a.startswith("--allow-workflow="):
            f, _, k = a.split("=", 1)[1].rpartition(":")
            if not f or k not in GUARD_WF_KEYS:
                print("ci-graph: --allow-workflow needs FILE:KEY with KEY one of %s (got %r); a bare file "
                      "would let every guarded key through" % ("/".join(GUARD_WF_KEYS), a), file=sys.stderr)
                return 2
            opts["allow_wf"].add((os.path.normpath(f), k))
        elif a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k.replace("-", "_")] = v
        elif a.startswith("--"):
            opts[a[2:].replace("-", "_")] = True
        else:
            opts["pos"].append(a)
    if loader() is None:
        print("NOT-RUN (no YAML loader): install PyYAML (pip3 install pyyaml), or put ruby or uv on PATH", file=out)
        return 2
    rows, notrun = [], []
    if "diff_guard" in opts:
        dg = opts["diff_guard"]
        files = opts["pos"] if dg is True else []
        root = "." if dg is True else (opts["pos"][0] if opts["pos"] else ".")
        if dg is True and len(files) != 2:
            print("ci-graph: --diff-guard needs OLD NEW files, or --diff-guard=<git-ref>", file=sys.stderr)
            return 2
        notrun = diff_guard(root, files, None if dg is True else dg, opts["allow_job"], opts["allow_wf"], rows)
    else:
        pos = opts["pos"] or ["."]
        if len(pos) == 1 and os.path.isdir(pos[0]):
            root, files = pos[0], workflow_files(pos[0])
        else:
            root, files = ".", [p for p in pos if os.path.isfile(p)]
        if not files:
            print("NOT-RUN (no workflow found under %s/.github/workflows)" % root, file=out)
            return 2
        res, wfs = load_many(files), []
        for p in files:
            rel = os.path.relpath(p, root)
            d, err = res[p]
            if err:
                notrun.append("%s: %s" % (rel, err))
            elif d is not None:
                wfs.append(Workflow(p, d, rel))
        modes = [k for k in ("required", "contexts", "settings_dir", "deploy_ancestors", "job_of", "shell_of", "serial_chains") if k in opts]
        checks = opts["check"] or ([] if modes else list(CHECKS))
        env_groups = {}
        for wf in wfs:
            for c in checks:
                if c == "deploy-concurrency":
                    c_deploy_concurrency(wf, rows, env_groups)
                elif c == "matrix":
                    c_matrix(wf, rows, root)
                else:
                    {"pin-priv": c_pin_priv, "deploy-gate": c_deploy_gate, "timeout": c_timeout, "cache-keys": c_cache_keys}[c](wf, rows)
        for env, gs in env_groups.items():
            if len({g for _, g in gs}) > 1:
                row(rows, None, 0, "ENV-SPLIT-GROUPS", env=env, groups=";".join("%s=%s" % x for x in sorted(gs)))
        req = None
        if "contexts" in opts or "required" in opts or "settings_dir" in opts:
            if "contexts" in opts:
                ctx, mq = {c.strip() for c in str(opts["contexts"]).split(",") if c.strip()}, bool(opts.get("merge_queue"))
            elif "settings_dir" in opts:
                ctx, mq, err = settings_dir(root, str(opts["settings_dir"]), opts.get("branch"), wfs, rows)
                if err:
                    notrun.append("UNREADABLE(%s)" % err)
            else:
                ctx, mq, err = fetch_required(root, opts.get("repo"), opts.get("branch"))
                if err:
                    notrun.append("UNREADABLE(%s)" % err)
            if ctx is not None:
                c_required(wfs, rows, ctx, mq)
                req = {(r["file"], r["job"]) for r in rows if r["code"] == "REQUIRED"}
        if "deploy_ancestors" in opts:
            c_deploy_ancestors(wfs, rows, req)
        if "serial_chains" in opts:
            for wf in wfs:
                c_serial_chains(wf, rows)
        if "job_of" in opts:
            job_of(wfs, opts["job_of"], root, rows)
        if "shell_of" in opts:
            shell_of(wfs, opts["shell_of"], root, rows)
    if opts.get("json"):
        print(json.dumps({"loader": loader(), "rows": rows, "not_run": notrun}, indent=1), file=out)
    else:
        for r in rows:
            print(fmt(r), file=out)
        for n in notrun:
            print("NOT-RUN %s" % n, file=out)
    if notrun:
        return 2
    return 1 if any(r["code"] in FINDING for r in rows) else 0


# ---------------------------------------------------------------- self-test
PATTERN = """name: CI
on:
  push: { branches: [main] }
  pull_request:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
      - uses: pnpm/action-setup@v6
      - run: pnpm install --frozen-lockfile
      - run: pnpm run test -- --coverage

  build-scan-publish:
    needs: quality
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v7
      - uses: docker/setup-buildx-action@v4
      - id: build
        uses: docker/build-push-action@v7
        with:
          load: true
          tags: ci-local/app:${{ github.sha }}
      - uses: aquasecurity/trivy-action@v0.36.0
        with:
          image-ref: ci-local/app:${{ github.sha }}
          exit-code: 1
      - if: github.event_name == 'push'
        uses: docker/login-action@v4
      - id: publish
        if: github.event_name == 'push'
        uses: docker/build-push-action@v7
        with:
          push: true

  deploy-staging:
    needs: build-scan-publish
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment: staging
    steps:
      - run: echo "Deploying"

  smoke-test:
    needs: deploy-staging
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - run: curl -f https://staging.example.com/health

  deploy-prod:
    needs: smoke-test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment:
      name: production
    steps:
      - run: echo "Deploying to prod"
"""

FIXTURE_C = """name: ci
on:
  pull_request:
    paths: ['src/**']
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    continue-on-error: true
    strategy:
      matrix:
        node: [20, 22]
        exclude:
          - node: 22
    steps:
      - uses: actions/checkout@v5
      - run: npm test -- --passWithNoTests || true
      - run: |
          set +e
          npx jest | tee out.txt
      - run: pytest | tee report.txt
        shell: bash
  lint:
    runs-on: ubuntu-latest
    if: github.actor != 'dependabot[bot]'
    steps:
      - run: npm run lint
  build:
    runs-on: ubuntu-latest
    needs: [tset]
    steps:
      - run: docker build -t app:${{ github.sha }} .
  deploy:
    runs-on: ubuntu-latest
    needs: test
    if: always()
    environment: production
    concurrency:
      group: deploy-prod
      cancel-in-progress: true
    steps:
      - uses: actions/checkout@v5
      - run: docker build -t app:prod . && docker push app:prod
"""

MISC = """on: { push: { branches: [main] } }
permissions: { contents: write, packages: write }
jobs:
  caller:
    uses: org/shared/.github/workflows/deploy.yml@main
    secrets: inherit
  scan:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - id: c
        uses: actions/cache@0400d5f644dc74513175e3cd8d07132dd4860809
        with:
          path: node_modules
          key: deps-${{ runner.os }}
          restore-keys: deps-
      - if: steps.c.outputs.cache-hit != ''
        run: echo skip
      - run: trivy image app:1 --exit-code 1 | tee trivy.txt
  deploy:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    if: always()
    environment: production
    steps:
      - run: kubectl apply -k deploy/k8s/overlays/prod && kubectl rollout status deploy/api
"""

DEPLOY_ACTION = """on: { push: { branches: [main] } }
permissions: { contents: read }
jobs:
  image:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - run: npm test
      - uses: docker/build-push-action@v7
        with:
          outputs: type=image,name=ghcr.io/o/app,push=true
  local-only:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: docker/build-push-action@v7
        with:
          outputs: type=docker
  webapp:
    needs: image
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: azure/webapps-deploy@v3
        with: { app-name: app }
  composite:
    needs: image
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: ./.github/actions/deploy
  remote:
    needs: image
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: some/remote-shell@v1
        with:
          script: helm upgrade --install api ./chart --wait --timeout 5m
  status-only:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: chrnorm/deployment-action@v2
  pulumi-preview:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: pulumi/actions@v6
        with: { command: preview }
  pulumi-up:
    needs: image
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: pulumi/actions@v6
        with: { command: up }
  worker:
    needs: image
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: cloudflare/wrangler-action@v3
"""

KUBE_FLAGS = """on: { push: { branches: [main] } }
permissions: { contents: read }
jobs:
  stage:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    environment: staging
    concurrency: { group: deploy-staging, cancel-in-progress: false }
    steps:
      - run: |
          kubectl --kubeconfig "$RUNNER_TEMP/kc" -n shop apply -k deploy/overlays/staging
          kubectl --kubeconfig "$RUNNER_TEMP/kc" -n shop rollout status deploy/api
  bounded:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    environment: staging
    concurrency: { group: deploy-staging-b, cancel-in-progress: false }
    steps:
      - run: kubectl --context=staging -n shop set image deploy/api api=x@sha256:abc && kubectl -n shop rollout status deploy/api --timeout=5m
  read-only:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - run: kubectl --kubeconfig "$RUNNER_TEMP/kc" -n shop get deploy/apply-config -o yaml | tee live.yaml
  publish-sdk:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - run: npm test
      - run: npm publish --provenance
  push-image:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - run: npm test
      - run: docker push ghcr.io/o/app:${{ github.sha }}
  push-and-roll:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - run: npm test
      - run: docker push ghcr.io/o/app:1 && kubectl -n shop set image deploy/api api=ghcr.io/o/app:1
"""

GUARD_OLD = """on: { pull_request: {} }
concurrency: { group: ci, cancel-in-progress: true }
jobs:
  a:
    runs-on: ubuntu-latest
    steps: [{ run: echo a }]
  b:
    runs-on: ubuntu-latest
    steps: [{ run: echo b }]
"""
GUARD_NEW = """on: { pull_request: {}, push: {} }
concurrency: { group: ci, cancel-in-progress: true }
jobs:
  a:
    runs-on: ubuntu-latest
    if: false
    steps: [{ run: echo a }]
  b:
    runs-on: ubuntu-latest
    concurrency: { group: deploy-b }
    steps: [{ run: echo b, if: always() }]
"""


def self_test():
    if loader() is None:
        print("NOT-RUN (no YAML loader): self-test needs PyYAML, ruby or uv")
        return 2
    tmp, fails, n = tempfile.mkdtemp(prefix="ci-graph-st-"), [], 0

    def repo(name, files):
        r = os.path.join(tmp, name)
        os.makedirs(os.path.join(r, ".github", "workflows"))
        for f, body in files.items():
            open(os.path.join(r, f), "w").write(body)
        return r

    def go(args):
        buf = _Buf()
        with contextlib.redirect_stderr(io.StringIO()):
            rc = run(args + ["--json"], out=buf)
        return rc, json.loads(buf.s) if buf.s.strip().startswith("{") else {"rows": [], "not_run": [buf.s]}

    def ok(cond, msg):
        nonlocal n
        n += 1
        if not cond:
            fails.append(msg)

    try:
        pat = repo("pattern", {".github/workflows/ci.yml": PATTERN})
        rc, o = go([pat, "--check=pin-priv"])
        pp = [r for r in o["rows"] if r["code"] == "PIN×PRIV"]
        ok(rc == 1 and len(pp) == 6, "pattern: 6 PIN×PRIV rows (got %d, rc %d)" % (len(pp), rc))
        ok({r["job"] for r in pp} == {"build-scan-publish"} and all(r["perms"] == "id-token,packages" for r in pp),
           "pattern: PIN×PRIV all in build-scan-publish with perms id-token,packages")
        ok(sum(1 for r in pp if r.get("party") == "first-party") == 1, "pattern: checkout marked first-party")
        ok(any(r["uses"] == "aquasecurity/trivy-action@v0.36.0" and r["line"] == 39 for r in pp), "pattern: trivy-action row on line 39")
        bp = sorted(r["line"] for r in pp if r["uses"] == "docker/build-push-action@v7")
        ok(bp == [35, 47], "pattern: the two build-push-action rows on lines 35 and 47 (got %s)" % bp)
        rc, o = go([pat, "--check=deploy-concurrency"])
        dc = [r for r in o["rows"] if r["code"] == "DEPLOY-CANCEL"]
        ok(rc == 1 and len(o["rows"]) == 2 and len(dc) == 2, "pattern: exactly 2 DEPLOY-CANCEL rows (got %s)" % [r["code"] for r in o["rows"]])
        ok({r["job"] for r in dc} == {"deploy-staging", "deploy-prod"} and all(r["scope"] == "workflow" and r["line"] == 11 for r in dc),
           "pattern: DEPLOY-CANCEL scope=workflow at line 11 for deploy-staging and deploy-prod")
        rc, o = go([pat, "--check=deploy-gate,timeout,matrix,cache-keys"])
        ok(rc == 0 and not o["rows"], "pattern: gated, timed, no matrix or cache rows (got %s)" % [r["code"] for r in o["rows"]])
        rc, o = go([pat, "--job-of=.github/workflows/ci.yml:40", "--shell-of=.github/workflows/ci.yml:66"])
        jo = [r for r in o["rows"] if r["code"] == "JOB-OF"]
        sh = [r for r in o["rows"] if r["code"] == "SHELL"]
        ok(jo and jo[0]["job"] == "build-scan-publish", "job-of: line 40 is in build-scan-publish")
        ok(sh and sh[0]["job"] == "smoke-test" and sh[0]["pipefail"] == "no" and sh[0]["source"] == "default",
           "shell-of: smoke-test step runs bash -e without pipefail")

        fc = repo("fixture-c", {".github/workflows/ci.yml": FIXTURE_C})
        rc, o = go([fc, "--all"])
        codes = [(r["code"], r.get("job")) for r in o["rows"]]
        ok(("DEPLOY-CANCEL", "deploy") in codes and any(r["code"] == "DEPLOY-CANCEL" and r["scope"] == "job" and r["group"] == "deploy-prod"
                                                    and r["line"] == 43 for r in o["rows"]), "fixture C: job-level DEPLOY-CANCEL group=deploy-prod line 43")
        ok(sorted(j for c, j in codes if c == "NO-TIMEOUT") == ["build", "deploy", "lint", "test"], "fixture C: 4 NO-TIMEOUT")
        ok(("DEPLOY-ALWAYS", "deploy") in codes, "fixture C: DEPLOY-ALWAYS on deploy")
        ok(any(r["code"] == "MATRIX-EXCLUDES-RUNTIME" and str(r["value"]) == "22" for r in o["rows"]), "fixture C: node 22 excluded from the matrix")
        ok(any(r["code"] == "PIN×PRIV" and r["job"] == "deploy" and r["perms"] == "environment" for r in o["rows"]),
           "fixture C: environment makes deploy privileged")
        rc, o = go([fc, "--contexts=test (20),lint,missing-check", "--merge-queue", "--deploy-ancestors"])
        cc = {r["code"]: r for r in o["rows"]}
        ok("REQUIRED-PATH-FILTERED" in cc and "NO-MERGE-GROUP" in cc and "REQUIRED-UNMATCHED" in cc
           and cc["REQUIRED-UNMATCHED"]["context"] == "missing-check", "required: path filter, merge_group and unmatched context")
        ok(any(r["code"] == "REQUIRED-IF-SKIP" and r["job"] == "lint" for r in o["rows"]), "required: lint skipped by if: reports success")
        ok(any(r["code"] == "JOB" and r["job"] == "test" and r["ancestor-of"] == "deploy" and r["required"] == "yes" for r in o["rows"]),
           "deploy-ancestors: test is required and an ancestor of deploy")
        sd = os.path.join(fc, "gh-api")
        os.makedirs(sd)
        json.dump([{"type": "required_status_checks", "parameters": {"required_status_checks": [{"context": c} for c in ("test (20)", "lint", "missing-check")]}},
                   {"type": "merge_queue", "parameters": {}}], open(os.path.join(sd, "rules-branches-main.json"), "w"), indent=1)
        json.dump({"environments": [{"name": "production", "protection_rules": [], "deployment_branch_policy": None, "can_admins_bypass": True}]},
                  open(os.path.join(sd, "environments.json"), "w"), indent=1)
        json.dump([{"id": 1, "name": "main", "target": "branch", "enforcement": "active"}], open(os.path.join(sd, "rulesets.json"), "w"), indent=1)
        rc, o2 = go([fc, "--settings-dir=gh-api", "--deploy-ancestors"])
        pick = lambda rs: sorted((r["code"], r.get("job", r.get("context", ""))) for r in rs if r["code"] != "JOB")
        ok(pick(o2["rows"]) and [x for x in pick(o2["rows"]) if x[0] not in ("ENVIRONMENT", "RULESET")] == pick(o["rows"]),
           "settings-dir: the rules snapshot gives the same required rows as --contexts=… --merge-queue")
        ok(any(r["code"] == "ENVIRONMENT" and r["env"] == "production" and r["branch-policy"] == "NONE" and r["file"] == os.path.join("gh-api", "environments.json")
               and r["line"] > 1 for r in o2["rows"]) and any(r["code"] == "RULESET" and r.get("name") == "NONE" and r["target"] == "tag" for r in o2["rows"]),
           "settings-dir: ENVIRONMENT branch-policy=NONE on the policy line; no tag ruleset is a RULESET name=NONE row")
        rc, o2 = go([fc, "--settings-dir=no-such-dir"])
        ok(rc == 2 and any("UNREADABLE" in n for n in o2["not_run"]), "settings-dir: a missing dir is UNREADABLE (exit 2), never clean")

        mi = repo("misc", {".github/workflows/m.yml": MISC})
        rc, o = go([mi, "--all"])
        codes = [(r["code"], r.get("job")) for r in o["rows"]]
        ok(("NO-TIMEOUT", "caller") not in codes, "uses: caller job is not a NO-TIMEOUT row")
        ok(("PIN×PRIV", "caller") in codes, "reusable caller with secrets: inherit and a branch ref is PIN×PRIV")
        ok(any(c == "PIN×PRIV" and j == "scan" for c, j in codes) is False, "SHA-pinned cache action is not PIN×PRIV")
        ok(any(r["code"] == "PIN×PRIV" and "contents" in r["perms"] for r in o["rows"]), "flow-map permissions read as write")
        for code in ("CACHE-KEY-NO-HASH", "CACHE-NODE-MODULES", "CACHE-PREFIX-SKIP-INSTALL", "DEPLOY-UNGATED", "DEPLOY-NOGROUP", "WAIT-NO-TIMEOUT"):
            ok(any(c == code for c, _ in codes), "misc: %s row" % code)

        rem = repo("remap", {".github/workflows/r.yml": "on:\n  push: {}\njobs: {}\n"})
        d = load_many([os.path.join(rem, ".github/workflows/r.yml")])[os.path.join(rem, ".github/workflows/r.yml")][0]
        ok(isinstance(d, dict) and "on" in d and True not in d and "true" not in d and list(triggers(d["on"])) == ["push"],
           "on: key remapped from YAML 1.1 true")

        g = os.path.join(tmp, "guard")
        os.makedirs(g)
        open(os.path.join(g, "old.yml"), "w").write(GUARD_OLD)
        open(os.path.join(g, "new.yml"), "w").write(GUARD_NEW)
        rc, o = go(["--diff-guard", os.path.join(g, "old.yml"), os.path.join(g, "new.yml"), "--allow-job=new.yml:a"])
        ch = {(r["code"], r["scope"], r.get("key")) for r in o["rows"]}
        ok(rc == 1 and ("GUARD-CHANGED", "workflow", "on") in ch, "diff-guard: on: change flagged")
        ok(("GUARD-ALLOWED", "job=a", "if") in ch, "diff-guard: if: change inside the allowed job passes")
        ok(("GUARD-CHANGED", "job=b", "concurrency") in ch, "diff-guard: concurrency added to another job flagged")
        ok(any(c == "GUARD-CHANGED" and s.startswith("job=b step=") and k == "if" for c, s, k in ch), "diff-guard: step if: change flagged")
        rc, o = go(["--diff-guard", os.path.join(g, "old.yml"), os.path.join(g, "old.yml")])
        ok(rc == 0 and not o["rows"], "diff-guard: identical files are clean")
        # --allow-workflow is key-scoped: it lets ONE workflow-level key through, never a job's keys
        rc, o = go(["--diff-guard", os.path.join(g, "old.yml"), os.path.join(g, "new.yml"), "--allow-job=new.yml:a",
                    "--allow-workflow=new.yml:on"])
        ch = {(r["code"], r["scope"], r.get("key")) for r in o["rows"]}
        ok(("GUARD-ALLOWED", "workflow", "on") in ch, "allow-workflow=FILE:on lets the on: change through")
        ok(rc == 1 and ("GUARD-CHANGED", "job=b", "concurrency") in ch
           and any(c == "GUARD-CHANGED" and s.startswith("job=b step=") for c, s, _ in ch),
           "allow-workflow=FILE:on still rejects job b's concurrency and step if: (the file-wide allow is gone)")
        rc, o = go(["--diff-guard", os.path.join(g, "old.yml"), os.path.join(g, "new.yml"), "--allow-job=new.yml:a",
                    "--allow-workflow=new.yml:concurrency"])
        ok(rc == 1 and ("GUARD-CHANGED", "workflow", "on") in {(r["code"], r["scope"], r.get("key")) for r in o["rows"]},
           "allow-workflow=FILE:concurrency does not let an on: change through")
        for bad_args, why in ((["--allow-workflow=new.yml"], "a bare file"), (["--allow-workflow=new.yml:jobs"], "an unguarded key"),
                              (["--allow-job", "new.yml:a"], "a space-separated --allow-job"),
                              (["--allow-workflow", "new.yml:on"], "a space-separated --allow-workflow")):
            rc, o = go(["--diff-guard", os.path.join(g, "old.yml"), os.path.join(g, "new.yml")] + bad_args)
            ok(rc == 2 and not o["rows"], "diff-guard: %s is refused (exit 2), never a silent allow" % why)
        rc, o = go(["--diff-guard", "HEAD~1"])
        ok(rc == 2, "diff-guard: a ref after a space (not --diff-guard=REF) is refused (exit 2)")

        da = repo("deploy-action", {".github/workflows/d.yml": DEPLOY_ACTION})
        rc, o = go([da, "--deploy-ancestors", "--check=deploy-concurrency"])
        jr = {r["job"]: r for r in o["rows"] if r["code"] == "JOB"}
        ok(jr.get("image", {}).get("publishes") == "yes", "build-push-action with outputs push=true and no push: input publishes")
        ok(jr.get("local-only", {}).get("publishes") == "no", "build-push-action with outputs type=docker does not publish")
        ok(jr.get("webapp", {}).get("deploys") == "yes" and jr["webapp"].get("deploy-via") == "action:azure/webapps-deploy"
           and jr["webapp"].get("env") == "-", "a deploy action with no environment: deploys (deploy-via=action, env=-)")
        ok(jr.get("composite", {}).get("deploys") == "yes", "a local ./.github/actions/deploy composite deploys")
        ok(jr.get("remote", {}).get("deploy-via") == "action-input:some/remote-shell", "a deploy verb in an action's script: input deploys")
        ok(jr.get("status-only", {}).get("deploys") == "no", "a deployment-status action is not a deploy")
        ok(jr.get("pulumi-preview", {}).get("deploys") == "no" and jr.get("pulumi-up", {}).get("deploys") == "yes",
           "pulumi/actions deploys on command: up, not on preview")
        ok(jr.get("worker", {}).get("deploys") == "yes", "wrangler-action with no command: deploys (its default)")
        ok(jr.get("image", {}).get("ancestor-of") == "composite,pulumi-up,remote,webapp,worker",
           "image is an ancestor of every action deploy (got %s)" % jr.get("image", {}).get("ancestor-of"))
        ng = sorted(r["job"] for r in o["rows"] if r["code"] == "DEPLOY-NOGROUP")
        ok(ng == ["composite", "pulumi-up", "remote", "webapp", "worker"], "action deploys with no group are DEPLOY-NOGROUP (got %s)" % ng)
        rc, o = go([fc, "--deploy-ancestors"])
        ok(any(r["code"] == "JOB" and r["job"] == "deploy" and r["env"] == "production" and r["deploy-via"] == "environment"
               for r in o["rows"]), "JOB rows print the environment name (fixture C deploy env=production)")

        kf = repo("kube-flags", {".github/workflows/k.yml": KUBE_FLAGS})
        rc, o = go([kf, "--all", "--deploy-ancestors"])
        jr = {r["job"]: r for r in o["rows"] if r["code"] == "JOB"}
        wt = [r["job"] for r in o["rows"] if r["code"] == "WAIT-NO-TIMEOUT"]
        ok(all(MUT.search(c) for c in ('kubectl --kubeconfig "$K" -n shop apply -k .', "kubectl --context=prod -n shop set image deploy/a a=x",
                                       "kubectl -n shop rollout restart deploy/a")) and not MUT.search("kubectl -n shop get cm/apply-config"),
           "kubectl with global flags before the verb (--kubeconfig, --context, -n) is a deploy verb; a get is not")
        ok(wt == ["stage"], "kubectl --kubeconfig … rollout status with no --timeout is WAIT-NO-TIMEOUT; a bounded one is not (got %s)" % wt)
        ok(jr.get("read-only", {}).get("deploys") == "no", "kubectl … get deploy/apply-config is not a deploy verb")
        ng = sorted(r["job"] for r in o["rows"] if r["code"] in ("DEPLOY-NOGROUP", "GROUP-NOT-ENV"))
        ok(ng == ["push-and-roll"], "publish-only jobs (npm publish, docker push) get no DEPLOY-NOGROUP; a push + rollout does (got %s)" % ng)
        ok(jr.get("publish-sdk", {}).get("deploys") == "no" and jr["publish-sdk"].get("publishes") == "yes"
           and jr["publish-sdk"].get("deploy-via") == "publish-verb" and jr.get("push-image", {}).get("publishes") == "yes"
           and jr.get("push-and-roll", {}).get("deploys") == "yes",
           "JOB rows: a publish-only verb job is publishes=yes deploys=no (deploy-via=publish-verb); push + set image deploys")

        chain = ("on: { pull_request: {} }\njobs:\n"
                 "  lint: { runs-on: x, steps: [{ run: npm run lint }] }\n"
                 "  types:\n    needs: lint\n    runs-on: x\n    steps: [{ run: npm run typecheck }]\n"
                 "  unit:\n    needs: types\n    runs-on: x\n    steps: [{ run: npm test }]\n"
                 "  build: { runs-on: x, steps: [{ run: npm run build }, { uses: actions/upload-artifact@v4 }] }\n"
                 "  e2e:\n    needs: build\n    runs-on: x\n    steps: [{ uses: actions/download-artifact@v4 }]\n"
                 "  report:\n    needs: e2e\n    runs-on: x\n    steps: [{ run: echo done }]\n")
        sc = repo("serial", {".github/workflows/c.yml": chain})
        rc, o = go([sc, "--serial-chains"])
        ch = [(r["jobs"], r["line"]) for r in o["rows"] if r["code"] == "SERIAL-CHAIN"]
        ok(rc == 0 and ch == [("lint>types>unit", 5)], "serial-chains: lint>types>unit at types' needs: line; an artifact hand-off breaks build>e2e>report (got %s)" % ch)

        bad = repo("bad", {".github/workflows/x.yml": "on: [push\njobs: {\n"})
        rc, o = go([bad, "--all"])
        ok(rc == 2 and o["not_run"], "parse error is NOT-RUN (exit 2), never clean")
        rc, o = go([os.path.join(tmp, "nothing-here")])
        ok(rc == 2, "no workflow found is NOT-RUN (exit 2)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        print("FAIL  " + f)
    print("ci-graph self-test (%s): %d/%d passed" % (loader(), n - len(fails), n))
    return 1 if fails else 0


class _Buf:
    def __init__(self):
        self.s = ""

    def write(self, x):
        self.s += x


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)
    sys.exit(self_test() if "--self-test" in a else run(a or [".", "--all"]))
