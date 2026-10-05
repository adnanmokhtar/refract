#!/usr/bin/env python3
"""behavior-diff.py — does HEAD still behave the way the stored baseline says it did?

Usage:  behavior-diff.py [--gate=G14|G4] [--repo=<dir>] [--base=<ref>] [--manifest=<file>]
                         [--kinds=quick|all|<kind>,…] [--entries=<id>,…] [--all-entries]
                         [--touched=<path>,…] [--runs=<run-id>,…] [--ci] [--recapture-base]
                         [--require-coverage] [--against-committed] [--json]
        behavior-diff.py --self-test
        (capture is driven by baseline-capture.sh, which calls the `capture` / `register` modes below)
Exit:   0  PASS or N-A      1  FAIL      3  UNVERIFIED (an entry could not run)      2  usage error

WHY. "Behaviour preserved" is a claim every refactor, optimisation and upgrade makes, and until now
nothing checked it except the tests that happened to exist. A baseline turns the claim into a
comparison: the behaviour was recorded BEFORE the edit (run phase P5, or the rolling registry on
main), and this script re-runs the same command at HEAD and compares — with the tolerance taxonomy of
packs/migration/skills/parity-test-generate (exact · structural · numeric_tolerance ·
order_insensitive · ignore), so one golden-master format serves a port and a refactor alike.

G14 (behaviour). The entries of .claude/baselines/<base sha>/manifest.json (a P5 capture), else of the
committed registry .claude/baselines/main/manifest.json, whose scope_paths meet the touched files.
  --local (default) quick kinds: characterization, api-contract, schema, golden-flow.
  --ci              every kind except performance (G4 owns it); visual and accessibility included.
  The base side is the stored artifact when it was captured at the merge-base; otherwise (or with
  --recapture-base) it is re-captured in a `git worktree` at the base sha with the entry's
  harness_paths overlaid from HEAD — so a harness written in this change still measures the old code.
  --against-committed compares with the artifact committed at --base whatever sha captured it — the
  refract-baselines-main job's question "does main still reproduce its committed baseline?".
  FAIL when: a difference no acceptance criterion declares (`changes_baseline` in
  ai/runs/<run>/acceptance.json; proposal §7 rule 2) · an expired quarantine · a T2/T3 run in the change
  whose modified source files no entry covers (`touched scope never captured`).
G4 (performance). The performance entries in scope; base (worktree) and head measured INTERLEAVED
  by perf-compare.py at twice the THR-PERF-REGRESSION run floor (REFRACT_PERF_RUNS overrides) against
  its threshold. REGRESSION → FAIL; a refused
  comparison (too few runs, too noisy, suspected) → UNVERIFIED, never PASS.

QUARANTINE (rule 3). An entry captured with differing outputs across 3 identical runs carries
`nondeterministic {owner, expiry, reason}`: its diffs are reported and not enforced until the expiry,
then FAIL. Nothing here re-baselines anything — a stored artifact changes only through
baseline-capture.sh, and test-integrity.py fails that rewrite when no criterion declares it.

HONEST LIMITS. A baseline compares what its command observes: an uncharacterized path is unguarded
(the coverage check names the modified files no entry covers, at T2+ only). compare=exit entries
delegate the comparison to the engine (oasdiff, Playwright) and see only its exit code. A diff is
"explained" by a criterion that NAMES the entry; whether the new output is the RIGHT one is the
criterion's own test's job (G1), not this script's.
"""
import datetime
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True                    # no __pycache__ in .claude/scripts (gate-check.py § WHY)
sys.path.insert(0, HERE)
try:
    import refract_records as rr
except ImportError:
    rr = None

KINDS = ("characterization", "api-contract", "visual", "performance", "accessibility", "schema", "ai-eval", "golden-flow")
QUICK = ("characterization", "api-contract", "schema", "golden-flow")
TIMEOUT = int(os.environ.get("REFRACT_BASELINE_TIMEOUT", "600"))
NOT_SOURCE = re.compile(r"(^|/)(tests?|__tests__|spec|specs|e2e|docs?|ai|\.claude|\.github|\.gitlab|node_modules|vendor)/"
                        r"|\.(md|txt|rst|lock|snap|png|jpg|svg)$|(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|go\.sum|Cargo\.lock)$"
                        r"|\.(test|spec)\.[a-z]+$|_test\.[a-z]+$|(^|/)test_[^/]+\.py$")


# ── git and files ─────────────────────────────────────────────────────────────────────────────
def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, "-c", "core.quotepath=false"] + list(args), capture_output=True,
                       text=True, errors="replace", stdin=subprocess.DEVNULL)
    return r.stdout if r.returncode == 0 else None


def resolve_base(repo, want):
    cands = [want] if want else []
    if os.environ.get("GITHUB_BASE_REF"):
        cands.append("origin/" + os.environ["GITHUB_BASE_REF"])
    cands += [os.environ.get("CI_MERGE_REQUEST_DIFF_BASE_SHA", ""), "origin/HEAD", "origin/main", "origin/master", "main", "master"]
    for c in filter(None, cands):
        mb = git(repo, "merge-base", "HEAD", c)
        if mb and mb.strip():
            return mb.strip()
    head = git(repo, "rev-parse", "--verify", "-q", "HEAD")
    return head.strip() if head else None


def touched_paths(repo, base, ci):
    rng = [base] + (["HEAD"] if ci else [])
    out = (git(repo, "diff", "--name-only", *rng) or "").splitlines()
    if not ci:
        out += (git(repo, "ls-files", "-o", "--exclude-standard") or "").splitlines()
    return sorted({p for p in out if p})


def modified_existing(repo, base, ci):
    """Paths that existed at base and changed (M, R, D) — the code whose old behaviour a baseline must pin."""
    rng = [base] + (["HEAD"] if ci else [])
    res = []
    for line in (git(repo, "diff", "--name-status", "-M", *rng) or "").splitlines():
        parts = line.split("\t")
        if parts and parts[0][:1] in ("M", "R", "D") and len(parts) >= 2:
            res.append(parts[1])
    return sorted(set(res))


def glob_match(path, pattern):
    """fnmatch where ** crosses directories and a trailing / means 'everything under'."""
    if pattern.endswith("/"):
        pattern += "**"
    rx = re.escape(pattern).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*").replace(r"\?", "[^/]")
    return re.fullmatch(rx, path) is not None


def in_scope(entry, paths):
    return [p for p in paths if any(glob_match(p, g) for g in entry.get("scope_paths", []))]


def load_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def validate_manifest(repo, m):
    if rr is None:
        return []
    try:
        return rr.validate(m, rr.load_schema("baseline-manifest", repo))
    except FileNotFoundError as e:
        return [str(e)]


def find_manifest(repo, base, explicit=None):
    """-> (path, manifest, error). The P5 capture at the base sha wins over the rolling registry."""
    bdir = os.path.join(repo, ".claude", "baselines")
    cands = [explicit] if explicit else []
    if base and os.path.isdir(bdir):
        cands += [os.path.join(bdir, d, "manifest.json") for d in sorted(os.listdir(bdir), key=len, reverse=True)
                  if d != "main" and len(d) >= 7 and base.startswith(d)]
    cands.append(os.path.join(bdir, "main", "manifest.json"))
    for c in cands:
        if c and os.path.isfile(c):
            m = load_json(c)
            return (c, None, "%s does not parse" % os.path.relpath(c, repo)) if m is None else (c, m, None)
    return None, None, None


def extract_at(repo, sha, rel, dest):
    """Copy the committed artifact `rel` as it was at `sha` into dest (a file or a directory). -> path or None.
    The stored side of a comparison is read from the BASE commit, never the working tree: a change that
    rewrites the golden files would otherwise compare HEAD with itself."""
    names = [n for n in (git(repo, "ls-tree", "-r", "--name-only", sha, "--", rel) or "").splitlines() if n]
    if not names:
        return None
    for n in names:
        out = subprocess.run(["git", "-C", repo, "show", "%s:%s" % (sha, n)], capture_output=True, stdin=subprocess.DEVNULL).stdout
        target = dest if names == [rel] else os.path.join(dest, os.path.relpath(n, rel))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        open(target, "wb").write(out)
    return dest


# ── acceptance declarations ───────────────────────────────────────────────────────────────────
def runs_in_change(paths):
    ids = set()
    for p in paths:
        m = re.match(r"^ai/runs/([^/]+)/", p) or re.match(r"^\.claude/locks/([^/]+)\.json$", p)
        if m:
            ids.add(m.group(1))
    return sorted(ids)


def declarations(repo, run_ids):
    """-> [(run_id, AC id, pattern)] from each run's acceptance.json."""
    out = []
    for r in run_ids:
        a = load_json(os.path.join(repo, "ai", "runs", r, "acceptance.json")) or {}
        for c in a.get("criteria", []) or []:
            for pat in c.get("changes_baseline", []) or []:
                out.append((r, c.get("id"), pat))
    return out


def explained_by(decls, entry_id, case=None):
    keys = [entry_id] + (["%s/%s" % (entry_id, case)] if case else [])
    for r, ac, pat in decls:
        if any(fnmatch.fnmatchcase(k, pat) for k in keys):
            return "%s (%s)" % (ac, r)
    return None


def run_tiers(repo, run_ids):
    return {r: (load_json(os.path.join(repo, "ai", "runs", r, "run.json")) or {}).get("tier") for r in run_ids}


# ── tolerant comparison (parity-test-generate's taxonomy) ─────────────────────────────────────
def path_rx(p):
    p = p.strip()
    if not p.startswith("$"):
        p = "$." + p
    rx = re.escape(p).replace(r"\[\*\]", r"\[\d+\]").replace(r"\*", r"[^.\[]*")
    return re.compile("^" + rx + "$")


class Tol:
    def __init__(self, t):
        t = t or {}
        self.ignore = [path_rx(x) for x in t.get("ignore", [])]
        self.structural = [path_rx(x) for x in t.get("structural", [])]
        self.unordered = [path_rx(x) for x in t.get("order_insensitive", [])]
        self.numeric = [(path_rx(k), float(v)) for k, v in (t.get("numeric_tolerance") or {}).items()]

    @staticmethod
    def hit(rxs, at):
        return any(r.match(at) for r in rxs)


def canon(v):
    return json.dumps(v, sort_keys=True, separators=(",", ":"))


def tdiff(a, b, tol, at="$", out=None):
    """Differences between two JSON values under the tolerance: [(path, base, head)]."""
    out = [] if out is None else out
    if Tol.hit(tol.ignore, at):
        return out
    if Tol.hit(tol.structural, at):
        if type(a) is not type(b) and not (isinstance(a, (int, float)) and isinstance(b, (int, float))):
            out.append((at, type(a).__name__, type(b).__name__))
        elif isinstance(a, dict) and set(a) != set(b):
            out.append((at, sorted(a), sorted(b)))
        return out
    for rx, eps in tol.numeric:
        if rx.match(at) and isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
            if abs(a - b) > eps:
                out.append((at, a, b))
            return out
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            sub = "%s.%s" % (at, k)
            if Tol.hit(tol.ignore, sub):
                continue
            if k not in a or k not in b:
                out.append((sub, a.get(k, "<absent>"), b.get(k, "<absent>")))
            else:
                tdiff(a[k], b[k], tol, sub, out)
        return out
    if isinstance(a, list) and isinstance(b, list):
        if Tol.hit(tol.unordered, at):
            if sorted(map(canon, a)) != sorted(map(canon, b)):
                out.append((at, a, b))
            return out
        if len(a) != len(b):
            out.append((at + ".length", len(a), len(b)))
        for i, (x, y) in enumerate(zip(a, b)):
            tdiff(x, y, tol, "%s[%d]" % (at, i), out)
        return out
    if a != b or type(a) is not type(b) and not (isinstance(a, (int, float)) and isinstance(b, (int, float))):
        out.append((at, a, b))
    return out


def read_artifact(path):
    """-> ('json', value) or ('text', normalised text) or ('bytes', sha)."""
    try:
        raw = open(path, "rb").read()
    except OSError:
        return None
    try:
        txt = raw.decode("utf-8")
    except UnicodeDecodeError:
        import hashlib
        return ("bytes", hashlib.sha256(raw).hexdigest())
    try:
        return ("json", json.loads(txt))
    except ValueError:
        return ("text", "\n".join(l.rstrip() for l in txt.strip().splitlines()))


def compare_files(bp, hp, tol):
    a, b = read_artifact(bp), read_artifact(hp)
    if a is None or b is None:
        return [("$", "<missing>" if a is None else "present", "<missing>" if b is None else "present")]
    if a[0] == b[0] == "json":
        return tdiff(a[1], b[1], tol)
    return [] if a == b else [("$", short(a[1]), short(b[1]))]


def short(v, n=160):
    s = v if isinstance(v, str) else canon(v)
    return s if len(s) <= n else s[:n] + "…"


def list_files(d):
    res = {}
    for root, _, files in os.walk(d):
        for f in files:
            full = os.path.join(root, f)
            res[os.path.relpath(full, d)] = full
    return res


def compare_artifacts(base, head, tol):
    """base/head: a file or a directory. -> [{'case', 'path', 'base', 'head'}]"""
    cases = []
    if os.path.isdir(base) or os.path.isdir(head):
        bf, hf = list_files(base) if os.path.isdir(base) else {}, list_files(head) if os.path.isdir(head) else {}
        for name in sorted(set(bf) | set(hf)):
            case = os.path.splitext(name)[0]
            if name not in hf:
                cases.append({"case": case, "path": "$", "base": "present", "head": "<case produced no output>"})
            elif name in bf:
                cases += [{"case": case, "path": p, "base": short(x), "head": short(y)} for p, x, y in compare_files(bf[name], hf[name], tol)]
            # a case only HEAD produced is a new input, not a changed behaviour
        return cases
    return [{"case": None, "path": p, "base": short(x), "head": short(y)} for p, x, y in compare_files(base, head, tol)]


# ── running an entry ──────────────────────────────────────────────────────────────────────────
def run_cmd(cmd, cwd, out_dir=None, timeout=TIMEOUT):
    env = dict(os.environ)
    if out_dir:
        env["REFRACT_BASELINE_OUT"] = out_dir
    try:
        r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, errors="replace", env=env,
                           executable="/bin/bash", timeout=timeout, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.TimeoutExpired) as e:
        return None, str(e)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def produce(entry, cwd, scratch):
    """Run the entry's command in cwd; -> (artifact path or None, rc, output)."""
    if entry["compare"] == "exit":
        rc, out = run_cmd(entry["command"], cwd)
        return None, rc, out
    target = os.path.join(scratch, entry["id"])
    os.makedirs(target, exist_ok=True)
    rc, out = run_cmd(entry["command"], cwd, target)
    files = list_files(target)
    if entry["compare"] == "file" and len(files) == 1:
        return list(files.values())[0], rc, out
    return target, rc, out


class Worktree:
    """A detached worktree at `sha` with the HEAD-side harness overlaid; removed on exit."""
    def __init__(self, repo, sha, harness):
        self.repo, self.sha, self.harness, self.dir = repo, sha, harness, None

    def __enter__(self):
        self.dir = tempfile.mkdtemp(prefix="refract-base-")
        os.rmdir(self.dir)
        r = subprocess.run(["git", "-C", self.repo, "worktree", "add", "--detach", "-q", self.dir, self.sha],
                           capture_output=True, text=True, stdin=subprocess.DEVNULL)
        if r.returncode != 0:
            raise RuntimeError("git worktree add %s failed: %s" % (self.sha[:12], r.stderr.strip()[:200]))
        for pat in self.harness:
            for src in sorted(expand(self.repo, pat)):
                rel = os.path.relpath(src, self.repo)
                dst = os.path.join(self.dir, rel)
                if os.path.isdir(src):
                    shutil.rmtree(dst, ignore_errors=True)
                    shutil.copytree(src, dst)
                else:
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    shutil.copy2(src, dst)
        return self.dir

    def __exit__(self, *a):
        subprocess.run(["git", "-C", self.repo, "worktree", "remove", "--force", self.dir], capture_output=True, stdin=subprocess.DEVNULL)
        shutil.rmtree(self.dir, ignore_errors=True)
        subprocess.run(["git", "-C", self.repo, "worktree", "prune"], capture_output=True, stdin=subprocess.DEVNULL)


def expand(repo, pat):
    full = os.path.join(repo, pat)
    if os.path.exists(full):
        return [full]
    import glob as _g
    return _g.glob(full, recursive=True)


def quarantine_state(entry, today):
    q = entry.get("nondeterministic")
    if not q:
        return None
    return "expired" if q.get("expiry", "") < today else "active"


# ── G14 ───────────────────────────────────────────────────────────────────────────────────────
def check_behaviour(repo, base, manifest_path, manifest, entries, decls, recapture, ci, committed=False):
    results, today = [], datetime.date.today().isoformat()
    for e in entries:
        res = {"id": e["id"], "kind": e["kind"], "engine": e["engine"], "compare": e["compare"], "cases": []}
        results.append(res)
        q = quarantine_state(e, today)
        if q == "expired":
            res.update(status="EXPIRED-QUARANTINE", reason="quarantined as nondeterministic until %s (owner %s) — the expiry passed; "
                       "fix the nondeterminism or a human renews it" % (e["nondeterministic"]["expiry"], e["nondeterministic"]["owner"]))
            continue
        scratch = tempfile.mkdtemp(prefix="refract-bd-")
        try:
            head_art, hrc, hout = produce(e, repo, os.path.join(scratch, "head"))
            local_capture = e["artifact_path"].startswith(".claude/baselines/") and not e["artifact_path"].startswith(".claude/baselines/main/")
            stored = os.path.join(repo, e["artifact_path"]) if local_capture else None
            same_sha = bool(base) and (committed or base.startswith(e.get("created_from_sha", "")[:12] or "-"))
            if not local_capture and not recapture and e["compare"] != "exit" and same_sha:
                stored = extract_at(repo, base, e["artifact_path"], os.path.join(scratch, "stored", os.path.basename(e["artifact_path"])))
            use_stored = not recapture and e["compare"] != "exit" and bool(stored) and os.path.exists(stored) and same_sha
            base_note = "stored capture @%s" % e.get("created_from_sha", "?")[:12]
            if e["compare"] == "exit":
                if not recapture:
                    res.update(status="SAME" if hrc == 0 else "DIFF", reason=None if hrc == 0 else
                               "`%s` exited %s against its committed baseline: %s" % (e["command"], hrc, hout.strip()[-200:]))
                    if hrc != 0:
                        res["cases"] = [{"case": None, "path": "exit", "base": 0, "head": hrc}]
                else:
                    with Worktree(repo, base, e.get("harness_paths", [])) as wt:
                        brc, bout = run_cmd(e["command"], wt)
                    if brc != 0:
                        res.update(status="ERROR", reason="the baseline is red at the base sha too (exit %s) — nothing to compare against" % brc)
                    else:
                        res.update(status="SAME" if hrc == 0 else "DIFF", reason=None if hrc == 0 else "green at base, exit %s at HEAD" % hrc)
                        if hrc != 0:
                            res["cases"] = [{"case": None, "path": "exit", "base": 0, "head": hrc}]
            else:
                if hrc is None or hrc != 0:
                    res.update(status="ERROR", reason="`%s` failed at HEAD (exit %s): %s" % (e["command"], hrc, hout.strip()[-200:]))
                    continue
                if use_stored:
                    base_art = stored
                else:
                    if not base:
                        res.update(status="ERROR", reason="no base sha to re-capture at")
                        continue
                    try:
                        with Worktree(repo, base, e.get("harness_paths", [])) as wt:
                            base_art, brc, bout = produce(e, wt, os.path.join(scratch, "base"))
                    except RuntimeError as ex:
                        if stored and os.path.exists(stored):
                            base_art, brc, base_note = stored, 0, "stored capture @%s (worktree failed: %s)" % (e.get("created_from_sha", "?")[:12], ex)
                        else:
                            res.update(status="ERROR", reason=str(ex))
                            continue
                    else:
                        base_note = "re-captured at base %s" % base[:12]
                    if brc != 0:
                        res.update(status="ERROR", reason="`%s` failed at the base sha (exit %s): %s" % (e["command"], brc, bout.strip()[-200:]))
                        continue
                res["cases"] = compare_artifacts(base_art, head_art, Tol(e.get("tolerance")))
                res["status"] = "DIFF" if res["cases"] else "SAME"
            res["base_side"] = base_note if e["compare"] != "exit" or recapture else "engine's committed baseline"
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
        if res.get("status") == "DIFF":
            for c in res["cases"]:
                c["explained_by"] = explained_by(decls, e["id"], c.get("case"))
            unexplained = [c for c in res["cases"] if not c["explained_by"]]
            if not unexplained:
                res["status"] = "EXPLAINED"
            elif q == "active":
                res["status"] = "QUARANTINED"
                res["reason"] = "differs, but quarantined as nondeterministic until %s (owner %s)" % (e["nondeterministic"]["expiry"], e["nondeterministic"]["owner"])
            else:
                res["reason"] = "%d difference(s) no acceptance criterion declares — e.g. %s %s: %s → %s" % (
                    len(unexplained), unexplained[0].get("case") or e["id"], unexplained[0]["path"], unexplained[0]["base"], unexplained[0]["head"])
    return results


# ── G4 ────────────────────────────────────────────────────────────────────────────────────────
def perf_floor(repo):
    for rel in (".claude/thresholds.local.json", ".claude/templates/governance/thresholds.json"):
        d = load_json(os.path.join(repo, rel))
        try:
            return max(5, int(d["thresholds"]["THR-PERF-REGRESSION"]["value"]["min_runs_per_side"]))
        except (TypeError, KeyError, ValueError):
            continue
    return 10


def check_perf(repo, base, entries, decls=()):
    pc = os.path.join(HERE, "perf-compare.py")
    results = []
    for e in entries:
        res = {"id": e["id"], "kind": e["kind"], "engine": e["engine"], "compare": "perf", "cases": []}
        results.append(res)
        if not os.path.isfile(pc):
            res.update(status="ERROR", reason="perf-compare.py is not installed beside behavior-diff.py")
            continue
        try:
            with Worktree(repo, base, e.get("harness_paths", [])) as wt:
                metric = e.get("metric") or {}
                cmd = [sys.executable, pc, "--base-cmd=" + e["command"], "--head-cmd=" + e["command"], "--base-dir=" + wt,
                       "--head-dir=" + repo, "--repo=" + repo, "--json"] + (["--bench=" + metric["bench"]] if metric.get("bench") else []) \
                    + (["--higher-is-better"] if metric.get("lower_is_better") is False else [])
                # Twice the THR-PERF-REGRESSION floor unless told otherwise. The floor is where a verdict is
                # REFUSED, not where a real one is reliably reached: measured on regression-baseline with a
                # loaded machine, a true 20% slowdown came back REGRESSION 8 of 8 times at 20 runs per side
                # and only 5 of 8 at 10 (the other 3 refused — UNVERIFIED, never PASS).
                cmd.append("--runs=" + os.environ.get("REFRACT_PERF_RUNS", str(2 * perf_floor(repo))))
                r = subprocess.run(cmd, cwd=repo, capture_output=True, text=True, errors="replace", stdin=subprocess.DEVNULL)
        except RuntimeError as ex:
            res.update(status="ERROR", reason=str(ex))
            continue
        try:
            d = json.loads(r.stdout)
        except ValueError:
            res.update(status="ERROR", reason="perf-compare.py: %s" % (r.stderr.strip() or r.stdout.strip())[-300:])
            continue
        res["perf"] = {k: d.get(k) for k in ("verdict", "delta_pct", "ci_pct", "p_value", "noise_band_pct", "n_base", "n_head", "threshold_pct")}
        v = d.get("verdict")
        res["status"] = {"REGRESSION": "DIFF", "NO-CHANGE": "SAME", "WITHIN-THRESHOLD": "SAME", "IMPROVEMENT": "SAME"}.get(v, "REFUSED")
        res["reason"] = "%s — %s" % (v, d.get("why"))
        if v == "REGRESSION":
            res["cases"] = [{"case": None, "path": "delta_pct", "base": 0, "head": d.get("delta_pct"),
                             "explained_by": explained_by(decls, e["id"])}]
            if res["cases"][0]["explained_by"]:        # an accepted cost, declared before the lock (rule 2)
                res["status"] = "EXPLAINED"
                res["reason"] += " — declared by %s" % res["cases"][0]["explained_by"]
    return results


# ── capture (driven by baseline-capture.sh) ───────────────────────────────────────────────────
def thr_waiver_days(repo):
    for rel in (".claude/thresholds.local.json", ".claude/templates/governance/thresholds.json"):
        d = load_json(os.path.join(repo, rel))
        try:
            return int(d["thresholds"]["THR-WAIVER"]["value"]["expiry_days_max"])
        except (TypeError, KeyError, ValueError):
            continue
    return 30


def capture(repo, opts):
    """Re-produce every selected entry of the registry at the current checkout. --out=main rewrites the
    committed artifacts in place (a deliberate re-baseline); --out=sha (default) writes a local capture
    to .claude/baselines/<HEAD sha>/ — what run phase P5 does at the base sha before any edit."""
    head = (git(repo, "rev-parse", "HEAD") or "").strip()
    reg_path = os.path.join(repo, ".claude", "baselines", "main", "manifest.json")
    reg = load_json(reg_path)
    if not reg:
        print("baseline-capture: no registry at .claude/baselines/main/manifest.json — register an entry first", file=sys.stderr)
        return 2
    errs = validate_manifest(repo, reg)
    if errs:
        print("baseline-capture: the registry is invalid: %s" % "; ".join(errs[:3]), file=sys.stderr)
        return 2
    sel = select(reg["entries"], opts, repo, head)
    to_main = opts.get("out", "sha") == "main"
    rebaseline = opts.get("rebaseline") == "1"
    owner = opts.get("owner") or (git(repo, "config", "user.email") or "").strip() or "UNASSIGNED"
    repeat = int(opts.get("repeat", "3"))
    cap_dir = os.path.join(repo, ".claude", "baselines", head)
    out_entries, rc_all = [], 0
    gi = os.path.join(repo, ".claude", "baselines", ".gitignore")
    if not os.path.exists(gi):
        open(gi, "w").write("# local captures (.claude/baselines/<sha>/) are never committed; the registry main/ is\n*\n!.gitignore\n!main/\n!main/**\n")
    for e in sel:
        e = dict(e)
        scratch = tempfile.mkdtemp(prefix="refract-cap-")
        try:
            if e["compare"] == "exit":
                rc, out = run_cmd(e["command"], repo)
                status = "captured (green)" if rc == 0 else "RED"
                if rc != 0:
                    rc_all = 1
            elif e["compare"] == "perf":
                import importlib.util
                spec = importlib.util.spec_from_file_location("perf_compare", os.path.join(HERE, "perf-compare.py"))
                pcm = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(pcm)
                vals, n = [], int(opts.get("runs", "10"))
                for _ in range(n):
                    rc, out = run_cmd(e["command"], repo)
                    if rc != 0:
                        break
                    vals += pcm.parse_values(out, (e.get("metric") or {}).get("bench"), per_run=True)[:1]
                dest = os.path.join(repo, e["artifact_path"]) if to_main else os.path.join(cap_dir, e["id"], "samples.json")
                if to_main and os.path.exists(dest) and not rebaseline:
                    print("  %-28s %-16s kept: %s exists — --rebaseline rewrites it" % (e["id"], e["kind"], e["artifact_path"]))
                    out_entries.append(e)
                    continue
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                json.dump({"samples": vals, "sha": head, "note": "informational: G4 re-measures base and head interleaved"}, open(dest, "w"), indent=1)
                if not to_main:
                    e["artifact_path"] = os.path.relpath(dest, repo)
                status = "captured %d sample(s)" % len(vals) if len(vals) == n else "RED"
                rc_all = rc_all or (0 if len(vals) == n else 1)
            else:
                runs = []
                for i in range(max(1, repeat)):
                    art, rc, out = produce(e, repo, os.path.join(scratch, "r%d" % i))
                    if rc != 0:
                        runs = None
                        print("  %s: `%s` exited %s: %s" % (e["id"], e["command"], rc, out.strip()[-300:]), file=sys.stderr)
                        break
                    runs.append(art)
                if runs is None:
                    status, rc_all = "RED", 1
                else:
                    differing = sorted({c.get("case") or e["id"] for r in runs[1:] for c in compare_artifacts(runs[0], r, Tol(e.get("tolerance")))})
                    if differing and not e.get("nondeterministic"):
                        exp = (datetime.date.today() + datetime.timedelta(days=thr_waiver_days(repo))).isoformat()
                        e["nondeterministic"] = {"owner": owner, "expiry": exp,
                                                 "reason": "differed across %d identical runs at %s: %s" % (len(runs), head[:12], ", ".join(differing[:5]))}
                    dest = os.path.join(repo, e["artifact_path"]) if to_main else os.path.join(cap_dir, e["id"], os.path.basename(e["artifact_path"].rstrip("/")))
                    if to_main and os.path.exists(dest) and not rebaseline:
                        # Never overwrite a stored expectation implicitly: register's first capture creates it,
                        # a re-record is an explicit --rebaseline (and test-integrity wants an AC for it).
                        same = not compare_artifacts(dest, runs[0], Tol(e.get("tolerance")))
                        print("  %-28s %-16s kept: %s exists and %s — --rebaseline rewrites it" % (
                            e["id"], e["kind"], e["artifact_path"], "reproduces" if same else "DIFFERS from this checkout"))
                        rc_all = rc_all or (0 if same else 1)
                        out_entries.append(e)
                        continue
                    if os.path.isdir(runs[0]):
                        shutil.rmtree(dest, ignore_errors=True)
                        shutil.copytree(runs[0], dest)
                    else:
                        os.makedirs(os.path.dirname(dest), exist_ok=True)
                        shutil.copy2(runs[0], dest)
                    if not to_main:
                        e["artifact_path"] = os.path.relpath(dest, repo)
                    status = "captured ×%d%s" % (len(runs), " — NONDETERMINISTIC, quarantined until %s (owner %s)" % (
                        e["nondeterministic"]["expiry"], e["nondeterministic"]["owner"]) if differing else "")
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
        if status != "RED":
            e["created_from_sha"] = head
        print("  %-28s %-16s %s" % (e["id"], e["kind"], status))
        out_entries.append(e)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if to_main:
        by_id = {e["id"]: e for e in out_entries}
        reg["entries"] = [by_id.get(e["id"], e) for e in reg["entries"]]
        reg["created"] = stamp
        write_manifest(reg_path, reg)
        print("baseline-capture: %d entr%s re-baselined in the registry @%s" % (len(out_entries), "y" if len(out_entries) == 1 else "ies", head[:12]))
    else:
        os.makedirs(cap_dir, exist_ok=True)
        write_manifest(os.path.join(cap_dir, "manifest.json"), {"schema": "refract/baseline-manifest/v1", "sha": head, "created": stamp, "entries": out_entries})
        print("baseline-capture: %d entr%s captured → .claude/baselines/%s/manifest.json" % (len(out_entries), "y" if len(out_entries) == 1 else "ies", head[:12]))
    return rc_all


def select(entries, opts, repo, head):
    kinds = opts.get("kinds", "all")
    want = set(QUICK) if kinds == "quick" else {k for k in KINDS if k not in ("visual", "performance", "accessibility")} if kinds == "cheap" else \
        {"visual", "performance", "accessibility"} if kinds == "nightly" else set(KINDS) if kinds == "all" else set(kinds.split(","))
    ids = set(opts["entries"].split(",")) if opts.get("entries") else None
    sel = [e for e in entries if e["kind"] in want and (ids is None or e["id"] in ids)]
    if opts.get("paths"):
        paths = [p for p in opts["paths"].split(",") if p]
        sel = [e for e in sel if in_scope(e, paths)]
    return sel


def write_manifest(path, m):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(m, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, path)


def register(repo, opts):
    """Add or replace one entry in the committed registry (the engines' 'Baseline registration')."""
    need = ("id", "kind", "engine", "command", "scope", "artifact", "compare")
    miss = [k for k in need if not opts.get(k)]
    if miss:
        print("baseline-capture register: missing --%s" % " --".join(miss), file=sys.stderr)
        return 2
    reg_path = os.path.join(repo, ".claude", "baselines", "main", "manifest.json")
    reg = load_json(reg_path) or {"schema": "refract/baseline-manifest/v1", "sha": "main", "entries": []}
    tol = None
    if opts.get("tolerance"):
        if opts["tolerance"].endswith((".yaml", ".yml")):
            print("baseline-capture register: tolerance must be JSON (tolerance.json) — a YAML file is not parsed here "
                  "(the standard library has no YAML, and a hand-rolled subset fails silently)", file=sys.stderr)
            return 2
        tol = load_json(os.path.join(repo, opts["tolerance"]))
        if tol is None:
            print("baseline-capture register: %s does not parse as JSON" % opts["tolerance"], file=sys.stderr)
            return 2
    e = {"id": opts["id"], "kind": opts["kind"], "engine": opts["engine"], "command": opts["command"],
         "scope_paths": [s for s in opts["scope"].split(",") if s], "created_from_sha": (git(repo, "rev-parse", "HEAD") or "0000000").strip(),
         "artifact_path": opts["artifact"].rstrip("/"), "tolerance": tol, "compare": opts["compare"],
         "cadence": opts.get("cadence") or ("nightly" if opts["kind"] in ("visual", "performance", "accessibility") else "pr")}
    if opts.get("harness"):
        e["harness_paths"] = [s for s in opts["harness"].split(",") if s]
    if opts["compare"] == "perf":
        e["metric"] = {k: v for k, v in (("unit", opts.get("unit")), ("bench", opts.get("bench"))) if v}
        e["metric"]["lower_is_better"] = opts.get("higher-is-better") != "1"
    old = next((x for x in reg["entries"] if x["id"] == e["id"]), None)
    if old and old.get("nondeterministic"):
        e["nondeterministic"] = old["nondeterministic"]        # a quarantine is never cleared by re-registering
    reg["entries"] = [x for x in reg["entries"] if x["id"] != e["id"]] + [e]
    errs = validate_manifest(repo, reg)
    if errs:
        print("baseline-capture register: the entry does not fit the schema: %s" % "; ".join(errs[:4]), file=sys.stderr)
        return 2
    write_manifest(reg_path, reg)
    print("baseline-capture: %s entry `%s` (%s, %s) in .claude/baselines/main/manifest.json" % ("replaced" if old else "registered", e["id"], e["kind"], e["engine"]))
    return 0


# ── main ──────────────────────────────────────────────────────────────────────────────────────
def gate(repo, opts, flags):
    ci = "--ci" in flags
    g = opts.get("gate", "G14")
    base = resolve_base(repo, opts.get("base"))
    touched = [p for p in opts["touched"].split(",") if p] if opts.get("touched") is not None else (touched_paths(repo, base, ci) if base else [])
    run_ids = [r for r in opts["runs"].split(",") if r] if opts.get("runs") else runs_in_change(touched)
    tiers = run_tiers(repo, run_ids)
    require = "--require-coverage" in flags or any(t in ("T2", "T3", "standard", "heavy") for t in tiers.values())
    mpath, man, err = find_manifest(repo, base, opts.get("manifest"))
    out = {"gate": g, "base": base, "manifest": os.path.relpath(mpath, repo) if mpath else None, "runs": run_ids,
           "touched": len(touched), "entries": [], "uncaptured": [], "verdict": "N-A", "reason": None}
    if err:
        out.update(verdict="UNVERIFIED", reason=err)
        return out
    if man is not None:
        errs = validate_manifest(repo, man)
        if errs:
            out.update(verdict="UNVERIFIED", reason="%s is invalid: %s" % (out["manifest"], "; ".join(errs[:3])))
            return out
    entries = man.get("entries", []) if man else []
    if g == "G4":
        sel = [e for e in entries if e["kind"] == "performance"]
    else:
        kinds = opts.get("kinds") or ("all" if ci else "quick")
        want = set(QUICK) if kinds == "quick" else set(KINDS) if kinds == "all" else set(kinds.split(","))
        sel = [e for e in entries if e["kind"] in want and e["kind"] != "performance"]
    if opts.get("entries"):
        sel = [e for e in sel if e["id"] in set(opts["entries"].split(","))]
    if "--all-entries" not in flags:
        sel = [e for e in sel if in_scope(e, touched)]
    if g == "G14" and require and base:
        covered = entries
        out["uncaptured"] = [p for p in modified_existing(repo, base, ci)
                             if not NOT_SOURCE.search(p) and not any(in_scope(e, [p]) for e in covered)]
    if not sel:
        if out["uncaptured"]:
            out.update(verdict="FAIL", reason="touched scope never captured: %d modified source file(s) no baseline entry covers "
                       "(a T2/T3 run in this change) — capture them at P5 with the characterize skill" % len(out["uncaptured"]))
        else:
            out["reason"] = ("no %s baseline registered (.claude/baselines/)" % ("performance" if g == "G4" else "behavioural")) if not man \
                else "no %s entry in the touched scope" % ("performance" if g == "G4" else "baseline")
        return out
    if not base:
        out.update(verdict="UNVERIFIED", reason="no base commit to compare against")
        return out
    decls = declarations(repo, run_ids)
    res = check_perf(repo, base, sel, decls) if g == "G4" else \
        check_behaviour(repo, base, mpath, man, sel, decls, "--recapture-base" in flags, ci, "--against-committed" in flags)
    out["entries"] = res
    bad = [r for r in res if r["status"] in ("DIFF", "EXPIRED-QUARANTINE")]
    unv = [r for r in res if r["status"] in ("ERROR", "REFUSED")]
    if bad or out["uncaptured"]:
        out["verdict"] = "FAIL"
        out["reason"] = "; ".join(["%s: %s" % (r["id"], r.get("reason")) for r in bad[:2]] +
                                  (["%d modified source file(s) no entry covers" % len(out["uncaptured"])] if out["uncaptured"] else []))
    elif unv:
        out.update(verdict="UNVERIFIED", reason="; ".join("%s: %s" % (r["id"], r.get("reason")) for r in unv[:2]))
    else:
        n = {s: sum(1 for r in res if r["status"] == s) for s in ("SAME", "EXPLAINED", "QUARANTINED")}
        if g == "G4":
            out.update(verdict="PASS", reason="; ".join("%s: %s" % (r["id"], r.get("reason")) for r in res)[:400])
            return out
        out.update(verdict="PASS", reason="%d entr%s re-run at HEAD: %d same, %d explained by an AC, %d quarantined"
                   % (len(res), "y" if len(res) == 1 else "ies", n["SAME"], n["EXPLAINED"], n["QUARANTINED"]))
    return out


def self_test():
    fails = []
    ok = lambda c, n: None if c else fails.append(n)
    t = Tol({"ignore": ["$.debug", "$.items[*].trace"], "structural": ["$.created_at"], "numeric_tolerance": {"$.total": 0.01},
             "order_insensitive": ["$.tags"]})
    a = {"id": 1, "total": 10.00, "created_at": "2026-01-01", "tags": ["a", "b"], "debug": 1, "items": [{"sku": "x", "trace": 1}]}
    b = {"id": 1, "total": 10.004, "created_at": "2026-02-02", "tags": ["b", "a"], "debug": 2, "items": [{"sku": "x", "trace": 9}]}
    ok(tdiff(a, b, t) == [], "tolerance taxonomy absorbs ignore / structural / numeric / order")
    b2 = dict(b, total=10.5)
    ok([d[0] for d in tdiff(a, b2, t)] == ["$.total"], "numeric tolerance exceeded is a diff")
    b3 = dict(b, items=[{"sku": "y", "trace": 1}])
    ok([d[0] for d in tdiff(a, b3, t)] == ["$.items[0].sku"], "an exact nested field is a diff")
    ok(tdiff({"a": 1}, {"a": 1, "b": 2}, Tol(None))[0][0] == "$.b", "a new field is a diff")
    ok(glob_match("src/orders/service.py", "src/**") and glob_match("src/a.py", "src/**/*.py") and not glob_match("lib/a.py", "src/**"), "globs")
    d = [("r", "AC-007", "pricing-quote/*-discount-*")]
    ok(explained_by(d, "pricing-quote", "020-edge-discount-cap") == "AC-007 (r)" and explained_by(d, "pricing-quote", "001-happy") is None, "AC declarations")
    for f in fails:
        print("FAIL  behavior-diff self-test: %s" % f)
    print("behavior-diff self-test: %d failure(s)" % len(fails))
    return 1 if fails else 0


def main(argv):
    mode = argv[0] if argv and argv[0] in ("capture", "register") else None
    args = argv[1:] if mode else argv
    opts = dict(a[2:].split("=", 1) for a in args if a.startswith("--") and "=" in a)
    flags = {a for a in args if a.startswith("--") and "=" not in a}
    if "--self-test" in flags:
        return self_test()
    known = {"rebaseline", "gate", "repo", "base", "manifest", "kinds", "entries", "touched", "runs", "out", "owner", "repeat", "paths",
             "id", "kind", "engine", "command", "scope", "artifact", "compare", "harness", "tolerance", "cadence", "unit",
             "bench", "higher-is-better", "runs"}
    if (set(opts) - known) or (flags - {"--json", "--ci", "--recapture-base", "--require-coverage", "--all-entries", "--against-committed"}) \
            or any(not a.startswith("--") for a in args) or opts.get("gate", "G14") not in ("G14", "G4"):
        print(__doc__.split("\n\n")[0].split("\n", 1)[1], file=sys.stderr)
        return 2
    repo = git(os.path.abspath(opts.get("repo", ".")), "rev-parse", "--show-toplevel")
    if not repo:
        print("behavior-diff: not inside a git work tree", file=sys.stderr)
        return 2
    repo = repo.strip()
    if mode == "capture":
        return capture(repo, opts)
    if mode == "register":
        return register(repo, opts)
    out = gate(repo, opts, flags)
    if "--json" in flags:
        print(json.dumps(out, indent=2))
    else:
        print("behavior-diff %s — %s%s · manifest %s · base %s" % (out["gate"], out["verdict"], (": " + out["reason"]) if out["reason"] else "",
                                                                   out["manifest"] or "none", (out["base"] or "none")[:12]))
        for r in out["entries"]:
            print("  %-26s %-16s %-18s %s" % (r["id"], r["kind"], r["status"], (r.get("reason") or r.get("base_side") or "")[:150]))
            for c in r["cases"][:6]:
                print("       %s %s: %s → %s%s" % (c.get("case") or "", c["path"], c["base"], c["head"],
                                                  "  (declared by %s)" % c["explained_by"] if c.get("explained_by") else ""))
        for p in out["uncaptured"][:10]:
            print("  uncaptured: %s" % p)
    return {"PASS": 0, "N-A": 0, "FAIL": 1, "UNVERIFIED": 3}[out["verdict"]]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
