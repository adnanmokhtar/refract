#!/usr/bin/env python3
"""history.py — Refract's quality as a time series: append one measured run to
benchmarks/results/history.jsonl and regenerate the tables in benchmarks/RESULTS.md from it.

Stdlib only. No network.

  python3 benchmarks/history.py append --from-score-json=<score.py --json output> [--findings=<file>] [--notes=…]
  python3 benchmarks/history.py append --fixture=vuln-fullstack --command=/security-audit \\
      --detected=12 --seeded=14 [--decoys=6 --decoys-flagged=1] --model=<exact id> \\
      [--model-version=…] [--date=YYYY-MM-DD] [--runs=1] [--findings=<file>] [--notes=…]
  python3 benchmarks/history.py append-eval --from-eval-json=<aggregate-result.json | lanes doc> --pack=<pack> --model=<id> [--judge-model=<id>] [--variant=bash]
  python3 benchmarks/history.py combine-lanes --pack=<pack> --ask=<json> [--stays=<json>] [--cmd=<json>] --out=<lanes doc> [--variant=bash]
  python3 benchmarks/history.py limit-check --eval-json=<json> [--log=<file>]   # exit 3: a run hit a usage/rate limit
  python3 benchmarks/history.py render [--check]      # rewrite RESULTS.md's generated blocks (--check: exit 1 if stale)
  python3 benchmarks/history.py --self-test

ROW SCHEMA (refract/bench-run/v1) — one JSON object per line, append-only, never edited:
  schema        "refract/bench-run/v1"
  kind          "detection" (a fixture scored by score.py) | "plugin-eval" (a `claude plugin eval` suite)
  date          YYYY-MM-DD the run was made (not the day it was appended)
  git_sha       the Refract commit measured (`git rev-parse HEAD`, "+dirty" when the tree had changes)
  model         exact model id of the agent under test (required: a row without one is refused)
  model_version build / snapshot / release date, or "unrecorded"
  runs          how many runs the row summarises (1 = an anecdote; say so)
  notes         free text; a findings file path when one exists
  detection rows: fixture · command · seeded · detected · recall (detected/seeded, 4 dp) ·
                  decoys · decoys_flagged · decoy_precision ((decoys − flagged)/decoys, 4 dp; null
                  when the fixture has no decoys) · severity_weighted (score.py's, as given) · unmatched (NOT a false-positive count) · findings_file
  plugin-eval rows: pack · judge_model · cases · cases_passed · score (aggregates.overallScore) ·
                  mean_delta (aggregates.meanDelta, with − without; null when one arm ran) ·
                  cost_usd · claude_version. A partial result (`partial: true`) or a run whose paid
                  graders were skipped is refused — the docs say to keep those out of a trend.
  plugin-eval rows from a LANES doc (refract/pack-lanes/v1, written by combine-lanes for
  scripts/run-pack-evals.sh: the hard case and stays-out run with and without the pack, the command
  lane run once with --ablation none) add — every one null when that lane did not run:
                  ask_case      the hard case (audit-<fixture>-slice, or spec-<fixture>-slice)
                  ask_with · ask_without · ask_delta   that case's mean score with the pack, without
                                it, and with − without (the plain ask: does the pack fire on its own?)
                  cmd_case · cmd_score    cmd-<fixture>-slice: the same slice and graders behind
                                /refract-<pack>:<audit command>, mean score
                  cmd_delta     cmd_score − ask_without (the command against the bare model on the
                                same ask; the pack earns its place only with cmd_delta > 0)
                  skill_fired   share of the hard case's WITH runs whose pack-fired indicator passed
                  stays_score   stays-out-of-unrelated-asks, mean score with the pack
                  runs          runs per case (the --runs the lanes used)
                  errored_runs  runs that ended on an error (a usage / rate-limit error refuses the row)
  In a lanes row, cases · cases_passed · score · mean_delta cover the two-arm cases (hard + stays-out).
  variant       absent (or null): the cases' own read-only tools (Read, Glob, Grep, Skill — no shell).
                "bash": scripts/run-pack-evals.sh --bash — Bash granted to BOTH arms of every lane, under the
                run's OS sandbox, so the pack's pre-flight rg and skills/<x>/scripts/ can run. A bash row is
                compared with the latest no-Bash row of the same pack and model, never averaged with it;
                RESULTS.md renders the two side by side in their own table.
  shell         lanes rows only, read from each run's kept trace (null when no trace was readable):
                  pack_runs       runs with the pack loaded and asked about the slice (ask WITH + cmd)
                  script_runs     of those, runs where a Bash call executed a bundled
                                  skills/<x>/scripts/<file>.{py,sh,awk,jq,ts,js} through an interpreter
                                  (reading the script or its data files does not count, nor does a call
                                  whose result is a missing-file / sandbox-denied error)
                  preflight_runs  of those, runs where the pack's skill or command was loaded and an `rg`
                                  ran through Bash (the skills' pre-flight greps)
                  bash_runs_with · bash_runs_without   runs per arm (ask lane; cmd counts as with)
                                  that executed any Bash command

Nothing here estimates. A field that was not measured is null, never a guess. RESULTS.md's tables
are GENERATED between `<!-- history:… -->` markers; edit history.jsonl through this script, never
the table.

Exit codes: 0 ok · 1 usage / refused row / stale (--check) · 2 self-test failure.
"""
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HISTORY = os.path.join(HERE, "results", "history.jsonl")
RESULTS = os.path.join(HERE, "RESULTS.md")
SCHEMA = "refract/bench-run/v1"
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
EMPTY_BANNER = """> ## NO RUN HAS BEEN RECORDED YET.
>
> The table below is empty. Every cell in it is empty. Nothing in this repository — no
> README, no marketing line, no issue comment — may cite a detection rate, a percentage,
> or a comparison against any other tool, because none has been measured.
>
> This file exists so that when a number does appear here, it arrives with the model, the
> version, the date and the raw findings attached. A number without those is not a result."""
ROWS_BANNER = """> Every row below is GENERATED from `benchmarks/results/history.jsonl` by
> `python3 benchmarks/history.py render`, and carries the model, its version, the date and the
> Refract commit it measured. Cite a number only with its row; a row without those is not a result."""


def die(msg):
    print("history: " + msg, file=sys.stderr)
    sys.exit(1)


def git_sha(repo=None):
    repo = repo or os.path.dirname(HERE)
    try:
        sha = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(["git", "-C", repo, "status", "--porcelain"], capture_output=True, text=True).stdout.strip()
    except OSError:
        return None
    return (sha + ("+dirty" if dirty else "")) if sha else None


def last_json(path):
    """score.py --json prints its report first and the JSON last; take the last top-level object."""
    text = open(path, encoding="utf-8").read()
    i = text.rfind("\n{")
    for start in ([0] if text.lstrip().startswith("{") else []) + ([i + 1] if i >= 0 else []):
        try:
            return json.loads(text[start:])
        except ValueError:
            continue
    die("%s holds no parseable JSON object" % path)


def ratio(a, b):
    return round(a / float(b), 4) if b else None


def validate(row):
    errs = []
    if row.get("schema") != SCHEMA:
        errs.append("schema must be %s" % SCHEMA)
    if not row.get("model"):
        errs.append("model is required — a row without the model id is not reproducible")
    if not DATE.match(str(row.get("date") or "")):
        errs.append("date must be YYYY-MM-DD")
    if row.get("kind") == "detection":
        for k in ("fixture", "seeded", "detected"):
            if row.get(k) in (None, ""):
                errs.append("detection row needs %s" % k)
        if isinstance(row.get("detected"), int) and isinstance(row.get("seeded"), int) and row["detected"] > row["seeded"]:
            errs.append("detected > seeded")
    elif row.get("kind") == "plugin-eval":
        for k in ("pack", "score", "cases"):
            if row.get(k) in (None, ""):
                errs.append("plugin-eval row needs %s" % k)
    else:
        errs.append("kind must be detection or plugin-eval")
    if row.get("variant") not in (None, "bash"):
        errs.append("variant must be absent or \"bash\"")
    return errs


def read_rows(path=HISTORY):
    rows = []
    if os.path.isfile(path):
        for n, l in enumerate(open(path, encoding="utf-8"), 1):
            if not l.strip():
                continue
            try:
                rows.append(json.loads(l))
            except ValueError:
                die("%s:%d does not parse" % (path, n))
    return rows


def append(row, path=HISTORY):
    errs = validate(row)
    if errs:
        die("row refused: " + "; ".join(errs))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    print("history: appended %s row (%s) to %s" % (row["kind"], row.get("fixture") or row.get("pack"),
                                                     os.path.relpath(path, os.path.dirname(HERE))))


def detection_row(o, today):
    seeded, detected = o.get("seeded"), o.get("detected")
    decoys, flagged = o.get("decoys"), o.get("decoys_flagged")
    return {"schema": SCHEMA, "kind": "detection", "date": o.get("date") or today, "fixture": o.get("fixture"),
            "command": o.get("command") or "all", "model": o.get("model"),
            "model_version": o.get("model_version") or "unrecorded", "git_sha": o.get("git_sha"),
            "runs": int(o.get("runs") or 1), "seeded": seeded, "detected": detected, "recall": ratio(detected, seeded),
            "severity_weighted": o.get("severity_weighted"), "decoys": decoys, "decoys_flagged": flagged,
            "decoy_precision": ratio(decoys - flagged, decoys) if decoys and flagged is not None else None,
            "unmatched": o.get("unmatched"), "findings_file": o.get("findings_file"), "notes": o.get("notes") or ""}


def eval_row(doc, pack, model, judge, today, sha, variant=None):
    if doc.get("partial"):
        die("partial eval result (%s) refused — keep it out of the trend" % doc.get("partialReason"))
    for c in doc.get("cases", []):
        for r in (c.get("arms") or {}).get("with", []) or []:
            if r.get("skippedPaidGraders"):
                die("case %s skipped paid graders — its score is not comparable; refused" % c.get("name"))
    ag = doc.get("aggregates") or {}
    return {"schema": SCHEMA, "kind": "plugin-eval", "date": today, "pack": pack, "model": model,
            "model_version": "unrecorded", "judge_model": judge, "git_sha": sha,
            "runs": None, "cases": ag.get("casesTotal"), "cases_passed": ag.get("casesPassed"),
            "score": ag.get("overallScore"), "mean_delta": ag.get("meanDelta"), "cost_usd": doc.get("costUsd"),
            "claude_version": doc.get("claudeVersion"), "notes": "", **({"variant": variant} if variant else {})}


LANES = "refract/pack-lanes/v1"
LIMIT_RE = re.compile(r"(usage|rate)[ _-]?limit|limit (reached|exceeded)|\b429\b|quota|weekly limit|out of extra usage", re.I)


def _runs(doc, arm=None):
    for c in (doc or {}).get("cases", []) or []:
        for a, rs in ((c.get("arms") or {}).items()):
            if arm and a != arm:
                continue
            for r in rs or []:
                yield c, a, r


def _mean(xs):
    xs = [x for x in xs if x is not None]
    return round(sum(xs) / len(xs), 4) if xs else None


def limit_state(doc, log_text=""):
    """(hits, utilization) — hits: runs that ended on a usage / rate-limit error, a `rejected` rate_limit_event in a
    run's trace, or a limit warning in the CLI log; utilization: the highest window utilization the traces report."""
    hits, util = [], {}
    for c, a, r in _runs(doc):
        if r.get("error") and LIMIT_RE.search(str(r["error"])):
            hits.append("%s/%s: %s" % (c.get("name"), a, str(r["error"])[:160]))
        tp = r.get("tracePath")
        if tp and os.path.isfile(tp):
            for line in open(tp, encoding="utf-8", errors="replace"):
                if '"rate_limit_event"' not in line:
                    continue
                try:
                    info = json.loads(line).get("rate_limit_info") or {}
                except ValueError:
                    continue
                if info.get("status") == "rejected":
                    hits.append("%s/%s: rate_limit_event rejected (%s)" % (c.get("name"), a, info.get("rateLimitType")))
                for w, v in (info.get("unifiedWindows") or {}).items():
                    if isinstance(v, dict) and isinstance(v.get("utilization"), (int, float)):
                        util[w] = max(util.get(w, 0), v["utilization"])
    for line in (log_text or "").splitlines():
        if LIMIT_RE.search(line):
            hits.append("log: " + line.strip()[:160])
    return hits, util


SCRIPT_RE = re.compile(r"skills/[\w.-]+/scripts/[\w.-]+\.(?:py|sh|awk|jq|ts|js|mjs)\b")   # a bundled script, not its data
RUNS_RE = re.compile(r"(^|[\s;&|(`])(python3?|bash|sh|node|tsx|deno)\s|\b(awk|jq)\s[^;|&]*-f\s")    # …and something ran it
RG_RE = re.compile(r"(^|[\s;&|(`$])rg\s")
NOT_RUN_RE = re.compile(r"No such file or directory|can't open file|Operation not permitted|Permission denied|"
                        r"command not found|No such tool available", re.I)


def _text(c):
    if isinstance(c, list):
        return "\n".join(_text(b.get("text") if isinstance(b, dict) and "text" in b else
                               (b.get("content") if isinstance(b, dict) else b)) for b in c)
    return "" if c is None else str(c)


def pack_names(pack):
    """The skill and command names templates/packs/<pack>/ ships (what a Skill call may name, bare or prefixed)."""
    base = os.path.join(os.path.dirname(HERE), "templates", "packs", pack)
    names = set()
    if os.path.isdir(os.path.join(base, "skills")):
        names |= set(os.listdir(os.path.join(base, "skills")))
    if os.path.isdir(os.path.join(base, "commands")):
        names |= {f[:-3] for f in os.listdir(os.path.join(base, "commands")) if f.endswith(".md")}
    return names


def trace_shell(path, pack, loaded=False, names=None):
    """One run's trace -> {"bash", "script", "preflight", "loaded"} (booleans), or None when unreadable.
    loaded: the pack's skill or command ran — a Skill call naming refract-<pack>:<x> or one of the pack's
    skill / command names (the pack-fired graders accept both), or the command lane."""
    if not path or not os.path.isfile(path):
        return None
    tag, uses, results = "refract-%s:" % pack, {}, {}
    names = pack_names(pack) if names is None else names
    try:
        for line in open(path, encoding="utf-8", errors="replace"):
            try:
                o = json.loads(line)
            except ValueError:
                continue
            content = (o.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for b in content:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "tool_use":
                    uses[b.get("id")] = (b.get("name"), b.get("input") or {})
                    sk = str((b.get("input") or {}).get("skill", ""))
                    if b.get("name") == "Skill" and (sk.startswith(tag) or sk.split(":")[-1] in names):
                        loaded = True
                elif b.get("type") == "tool_result":
                    results[b.get("tool_use_id")] = _text(b.get("content"))
    except OSError:
        return None
    out = {"bash": False, "script": False, "preflight": False, "loaded": loaded}
    for i, (name, inp) in uses.items():
        if name != "Bash" or i not in results:
            continue
        cmd, res = str(inp.get("command", "")), results[i]
        if "No such tool available" in res:
            continue
        out["bash"] = True
        ran = not NOT_RUN_RE.search(res[:400])
        if SCRIPT_RE.search(cmd) and RUNS_RE.search(cmd) and ran:
            out["script"] = True
        if RG_RE.search(cmd) and "command not found" not in res:
            out["preflight"] = out["preflight"] or loaded
    return out


def shell_summary(lanes, pack):
    """The `shell` block of a lanes summary (see the docstring); None when no run's trace was readable."""
    s = {"pack_runs": 0, "script_runs": 0, "preflight_runs": 0, "bash_runs_with": 0, "bash_runs_without": 0}
    seen, names = False, pack_names(pack)
    for ln in ("ask", "cmd"):
        for c, a, r in _runs(lanes.get(ln)):
            if not re.match(r"(audit|spec|cmd)-", c.get("name", "")):
                continue
            t = trace_shell(r.get("tracePath"), pack, loaded=(ln == "cmd"), names=names)
            if t is None:
                continue
            seen = True
            s["bash_runs_%s" % ("without" if a == "without" else "with")] += t["bash"]
            if a == "with":
                s["pack_runs"] += 1
                s["script_runs"] += t["script"]
                s["preflight_runs"] += t["preflight"]
    return s if seen else None


def lanes_summary(lanes, pack=None):
    """The ask / command-lane figures of a lanes doc (see the docstring)."""
    ask, stays, cmd = lanes.get("ask"), lanes.get("stays"), lanes.get("cmd")
    s = {"ask_case": None, "ask_with": None, "ask_without": None, "ask_delta": None, "cmd_case": None,
         "cmd_score": None, "cmd_delta": None, "skill_fired": None, "stays_score": None, "runs": None}
    for c in (ask or {}).get("cases", []):
        if re.match(r"(audit|spec)-", c.get("name", "")):
            ag = c.get("aggregates") or {}
            s.update(ask_case=c["name"], ask_with=ag.get("score"), ask_without=ag.get("scoreWithout"),
                     ask_delta=ag.get("delta"), runs=c.get("runsPerCase"))
            fired = [any(g.get("name") == "pack-fired" and g.get("passed") for g in r.get("graders") or [])
                     for r in (c.get("arms") or {}).get("with", []) or []]
            s["skill_fired"] = round(sum(fired) / float(len(fired)), 4) if fired else None
    for c in (stays or {}).get("cases", []):
        s["stays_score"] = (c.get("aggregates") or {}).get("score")
    for c in (cmd or {}).get("cases", []):
        if c.get("name", "").startswith("cmd-"):
            s.update(cmd_case=c["name"], cmd_score=(c.get("aggregates") or {}).get("score"))
    if s["cmd_score"] is not None and s["ask_without"] is not None:
        s["cmd_delta"] = round(s["cmd_score"] - s["ask_without"], 4)
    s["shell"] = shell_summary(lanes, pack) if pack else None
    return s


def combine(pack, docs, variant=None):
    """{lane: aggregate-result doc} -> a lanes doc (refract/pack-lanes/v1) with its summary."""
    lanes = {k: v for k, v in docs.items() if v is not None}
    out = {"schema": LANES, "pack": pack, "variant": variant, "lanes": lanes, "summary": lanes_summary(lanes, pack),
           "costUsd": round(sum(d.get("costUsd") or 0 for d in lanes.values()), 6),
           "claudeVersion": next((d.get("claudeVersion") for d in lanes.values() if d.get("claudeVersion")), None),
           "partial": any(d.get("partial") for d in lanes.values()),
           "partialReason": "; ".join("%s: %s" % (k, d.get("partialReason")) for k, d in lanes.items() if d.get("partial"))}
    return out


def lanes_row(doc, pack, model, judge, today, sha, variant=None):
    if doc.get("partial"):
        die("partial lane result (%s) refused — keep it out of the trend" % doc.get("partialReason"))
    lanes = doc.get("lanes") or {}
    if "ask" not in lanes:
        die("a lanes doc without the ask lane (the hard case, with and without the pack) is refused")
    errored = 0
    for k, d in lanes.items():
        hits, _ = limit_state(d)
        if hits:
            die("lane %s: a run ended on a usage / rate-limit error (%s) — refused" % (k, hits[0]))
        for c, a, r in _runs(d):
            if r.get("skippedPaidGraders"):
                die("lane %s case %s skipped paid graders — its score is not comparable; refused" % (k, c.get("name")))
            errored += 1 if r.get("error") else 0
    two = [c for k in ("ask", "stays") for c in (lanes.get(k) or {}).get("cases", [])]
    s = lanes_summary(lanes, pack)
    if s["shell"] is None:               # the traces are gone: keep what combine-lanes read while they existed
        s["shell"] = (doc.get("summary") or {}).get("shell")
    row = {"schema": SCHEMA, "kind": "plugin-eval", "date": today, "pack": pack, "model": model,
           "model_version": "unrecorded", "judge_model": judge, "git_sha": sha,
           "cases": len(two), "cases_passed": sum(1 for c in two if (c.get("aggregates") or {}).get("passRate") == 1),
           "score": _mean((c.get("aggregates") or {}).get("score") for c in two),
           "mean_delta": _mean((c.get("aggregates") or {}).get("delta") for c in two),
           "cost_usd": doc.get("costUsd"), "claude_version": doc.get("claudeVersion"), "errored_runs": errored,
           "notes": ""}
    row.update(s)
    variant = variant or doc.get("variant")
    if variant:
        row["variant"] = variant
    return row


def pct(x):
    return "—" if x is None else "%d%%" % round(x * 100)


def tables(rows):
    det = [r for r in rows if r.get("kind") == "detection"]
    ev = [r for r in rows if r.get("kind") == "plugin-eval" and not r.get("variant")]
    bash = [r for r in rows if r.get("kind") == "plugin-eval" and r.get("variant") == "bash"]
    T = ["| date | fixture | command | model | model version | sha | runs | detected | recall | severity-wtd | decoy precision | unmatched | notes |",
         "|------|---------|---------|-------|---------------|-----|------|----------|--------|--------------|-----------------|-----------|-------|"]
    for r in sorted(det, key=lambda r: (r["date"], r["fixture"])):
        T.append("| %s | %s | %s | %s | %s | %s | %s | %s/%s | %s | %s | %s | %s | %s |" % (
            r["date"], r["fixture"], r.get("command") or "all", r["model"], r.get("model_version") or "unrecorded",
            (r.get("git_sha") or "—")[:12], r.get("runs") or 1, r["detected"], r["seeded"], pct(r.get("recall")), pct(r.get("severity_weighted")),
            "—" if r.get("decoy_precision") is None else "%s (%s/%s flagged)" % (pct(r["decoy_precision"]), r.get("decoys_flagged"), r.get("decoys")),
            "—" if r.get("unmatched") is None else r["unmatched"],
            (r.get("notes") or "—") + ("; findings: %s" % r["findings_file"] if r.get("findings_file") else "")))
    if not det:
        T.append("| — | — | — | — | — | — | — | — | — | — | — | — | *no run recorded* |")
    E = ["| date | pack | model | judge | sha | cases passed | score | Δ vs no-plugin | ask with / without | ask Δ "
         "| cmd score | cmd Δ | skill fired | cost | notes |",
         "|------|------|-------|-------|-----|--------------|-------|-----------------|--------------------|-------"
         "|-----------|-------|-------------|------|-------|"]

    def f2(x, sign=False):
        return "—" if x is None else ("%+.2f" % x if sign else "%.2f" % x)
    for r in sorted(ev, key=lambda r: (r["date"], r["pack"])):
        E.append("| %s | %s | %s | %s | %s | %s/%s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["date"], r["pack"], r["model"], r.get("judge_model") or "—", (r.get("git_sha") or "—")[:12],
            r.get("cases_passed"), r.get("cases"), f2(r.get("score")), f2(r.get("mean_delta"), True),
            "—" if r.get("ask_with") is None else "%s / %s" % (f2(r["ask_with"]), f2(r.get("ask_without"))),
            f2(r.get("ask_delta"), True), f2(r.get("cmd_score")), f2(r.get("cmd_delta"), True), pct(r.get("skill_fired")),
            "—" if r.get("cost_usd") is None else "$%.2f" % r["cost_usd"], r.get("notes") or "—"))
    if not ev:
        E.append("| — | — | — | — | — | — | — | — | — | — | — | — | — | — | *no eval run recorded* |")
    B = ["| date | pack | model | judge | sha | ask with / without | ask Δ | cmd score | cmd Δ | no-Bash cmd Δ "
         "| skill fired | pack scripts ran | pre-flight rg | Bash used with / without | cost |",
         "|------|------|-------|-------|-----|--------------------|-------|-----------|-------|---------------"
         "|-------------|------------------|---------------|--------------------------|------|"]

    def no_bash(r):                      # the latest no-Bash lanes row of the same pack and model
        prev = [x for x in ev if x["pack"] == r["pack"] and x["model"] == r["model"] and x.get("cmd_delta") is not None
                and x["date"] <= r["date"]]
        return max(prev, key=lambda x: x["date"])["cmd_delta"] if prev else None

    def frac(sh, k, of):
        return "—" if not sh else "%s/%s" % (sh.get(k), sh.get(of))
    for r in sorted(bash, key=lambda r: (r["date"], r["pack"])):
        sh = r.get("shell") or {}
        B.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["date"], r["pack"], r["model"], r.get("judge_model") or "—", (r.get("git_sha") or "—")[:12],
            "—" if r.get("ask_with") is None else "%s / %s" % (f2(r["ask_with"]), f2(r.get("ask_without"))),
            f2(r.get("ask_delta"), True), f2(r.get("cmd_score")), f2(r.get("cmd_delta"), True), f2(no_bash(r), True),
            pct(r.get("skill_fired")), frac(sh, "script_runs", "pack_runs"), frac(sh, "preflight_runs", "pack_runs"),
            "—" if not sh else "%s / %s" % (sh.get("bash_runs_with"), sh.get("bash_runs_without")),
            "—" if r.get("cost_usd") is None else "$%.2f" % r["cost_usd"]))
    if not bash:
        B.append("| — | — | — | — | — | — | — | — | — | — | — | — | — | — | *no Bash run recorded* |")
    return "\n".join(T), "\n".join(E), "\n".join(B)


def replace_block(text, name, body):
    pat = re.compile(r"(<!-- history:%s:begin -->\n).*?(\n<!-- history:%s:end -->)" % (name, name), re.S)
    if not pat.search(text):
        die("RESULTS.md has no <!-- history:%s:begin/end --> block" % name)
    return pat.sub(lambda m: m.group(1) + body + m.group(2), text, count=1)


def render(results=RESULTS, history=HISTORY, check=False):
    rows = read_rows(history)
    for i, r in enumerate(rows, 1):
        errs = validate(r)
        if errs:
            die("%s row %d invalid: %s" % (history, i, "; ".join(errs)))
    det, ev, bash = tables(rows)
    old = open(results, encoding="utf-8").read()
    new = replace_block(old, "banner", EMPTY_BANNER if not rows else ROWS_BANNER)
    new = replace_block(new, "detection", det)
    new = replace_block(new, "eval", ev)
    new = replace_block(new, "eval-bash", bash)
    if check:
        if new != old:
            print("history: RESULTS.md is stale against history.jsonl — run python3 benchmarks/history.py render",
                  file=sys.stderr)
            return 1
        print("history: RESULTS.md matches history.jsonl (%d row(s))" % len(rows))
        return 0
    if new != old:                       # an unchanged render must not move the mtime
        with open(results, "w", encoding="utf-8") as fh:
            fh.write(new)
    print("history: %s RESULTS.md from %d row(s)" % ("rendered" if new != old else "unchanged", len(rows)))
    return 0


def parse(argv):
    opts, pos = {}, []
    for a in argv:
        if a.startswith("--"):
            k, _, v = a[2:].partition("=")
            opts[k] = v
        else:
            pos.append(a)
    return opts, pos


def self_test():
    import contextlib
    import io
    fails = []
    tmp = tempfile.mkdtemp(prefix="history-")
    try:
        res, hist = os.path.join(tmp, "RESULTS.md"), os.path.join(tmp, "results", "history.jsonl")
        with open(res, "w") as fh:
            fh.write("# R\n<!-- history:banner:begin -->\nx\n<!-- history:banner:end -->\n\n"
                     "<!-- history:detection:begin -->\nx\n<!-- history:detection:end -->\n"
                     "<!-- history:eval:begin -->\nx\n<!-- history:eval:end -->\n"
                     "<!-- history:eval-bash:begin -->\nx\n<!-- history:eval-bash:end -->\n")
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            render(res, hist)
            body = open(res).read()
            if "NO RUN HAS BEEN RECORDED YET" not in body or "*no run recorded*" not in body:
                fails.append("empty-history-keeps-the-no-run-banner")
            score = {"date": "2026-10-19", "fixture": "vuln-fullstack", "command": "/security-audit",
                     "model": "claude-test-model", "model_version": "t", "seeded": 14, "detected": 12,
                     "decoys": 6, "decoys_flagged": 1, "unmatched": 3, "severity_weighted": 0.9}
            r = detection_row(score, "2026-10-19")
            r["git_sha"] = "abc123"
            if r["recall"] != 0.8571 or r["decoy_precision"] != 0.8333:
                fails.append("recall-and-decoy-precision-computed")
            append(r, hist)
            try:
                append(dict(r, model=""), hist)
                fails.append("row-without-model-refused")
            except SystemExit:
                pass
            try:
                eval_row({"partial": True, "partialReason": "cost_ceiling"}, "security", "m", "j", "2026-10-19", "s")
                fails.append("partial-eval-refused")
            except SystemExit:
                pass
            e = eval_row({"aggregates": {"overallScore": 0.9, "meanDelta": 0.4, "casesPassed": 2, "casesTotal": 3},
                          "costUsd": 1.5, "claudeVersion": "2.1.300", "cases": []}, "security", "m", "j", "2026-10-19", "s")
            append(e, hist)

            def case(name, score, without=None, fired=(), err=None):
                arms = {"with": [{"score": score, "error": err, "graders": [{"name": "pack-fired", "passed": f}]}
                                 for f in (fired or [False])]}
                ag = {"score": score, "passRate": 1 if score == 1 else 0}
                if without is not None:
                    arms["without"] = [{"score": without, "error": None, "graders": []}]
                    ag.update(scoreWithout=without, delta=round(score - without, 4))
                return {"name": name, "runsPerCase": 2, "aggregates": ag, "arms": arms}
            ask = {"costUsd": 1.0, "claudeVersion": "2.1.300", "cases": [case("audit-fx-slice", 0.6, 0.5, (True, False))]}
            stays = {"costUsd": 0.1, "cases": [case("stays-out-of-unrelated-asks", 1, 1)]}
            cmdd = {"costUsd": 0.5, "cases": [case("cmd-fx-slice", 0.8)]}
            lanes = combine("finops", {"ask": ask, "stays": stays, "cmd": cmdd})
            lr = lanes_row(lanes, "finops", "m", "j", "2026-10-19", "s")
            want = {"ask_with": 0.6, "ask_without": 0.5, "ask_delta": 0.1, "cmd_score": 0.8, "cmd_delta": 0.3,
                    "skill_fired": 0.5, "stays_score": 1, "cases": 2, "cases_passed": 1, "cost_usd": 1.6}
            got = {k: lr.get(k) for k in want}
            if got != want:
                fails.append("lanes-row-fields (got %s)" % got)
            append(lr, hist)

            def trace(name, *calls):   # calls: (tool, input, result text)
                tp = os.path.join(tmp, name + ".jsonl")
                with open(tp, "w") as fh:
                    for n, (tool, inp, res) in enumerate(calls):
                        fh.write(json.dumps({"type": "assistant", "message": {"content": [
                            {"type": "tool_use", "id": "t%d" % n, "name": tool, "input": inp}]}}) + "\n")
                        fh.write(json.dumps({"type": "user", "message": {"content": [
                            {"type": "tool_result", "tool_use_id": "t%d" % n, "content": res}]}}) + "\n")
                return tp
            ran = trace("ran", ("Skill", {"skill": "refract-finops:cost-scan"}, "loaded"),
                        ("Bash", {"command": "python3 /tmp/s/skills/cost-scan/scripts/cost-sites.py ."}, "12 rows"),
                        ("Bash", {"command": "rg -n 'x' ."}, "a.ts:1:x"))
            denied = trace("denied", ("Bash", {"command": "python3 /h/skills/cost-scan/scripts/cost-sites.py ."},
                                      "python3: can't open file '/h/skills/cost-scan/scripts/cost-sites.py'"))
            bare = trace("bare", ("Bash", {"command": "rg -n 'x' ."}, "a.ts:1:x"),
                         ("Bash", {"command": "head -5 /s/skills/cost-scan/scripts/rates.tsv; cat /s/skills/cost-scan/scripts/c.py"}, "x"))
            if trace_shell(bare, "finops")["script"]:
                fails.append("trace-shell-does-not-count-reading-a-script-or-its-data")
            if trace_shell(ran, "finops") != {"bash": True, "script": True, "preflight": True, "loaded": True}:
                fails.append("trace-shell-sees-a-script-and-a-preflight-rg (got %s)" % trace_shell(ran, "finops"))
            bare_name = trace("bare-name", ("Skill", {"skill": "cost-scan"}, "loaded"), ("Bash", {"command": "rg -n x ."}, "a:1"))
            if not trace_shell(bare_name, "finops", names={"cost-scan"})["preflight"]:
                fails.append("trace-shell-reads-an-unprefixed-pack-skill-as-loaded")
            if trace_shell(denied, "finops")["script"] or trace_shell(bare, "finops")["preflight"]:
                fails.append("trace-shell-skips-a-denied-script-and-an-rg-without-the-pack")
            bask = dict(ask, cases=[dict(ask["cases"][0], arms={
                "with": [dict(r0, tracePath=ran) for r0 in ask["cases"][0]["arms"]["with"]][:1] +
                        [dict(ask["cases"][0]["arms"]["with"][1], tracePath=denied)],
                "without": [dict(ask["cases"][0]["arms"]["without"][0], tracePath=bare)]})])
            bl = combine("finops", {"ask": bask, "stays": stays, "cmd": cmdd}, "bash")
            br = lanes_row(bl, "finops", "m", "j", "2026-10-20", "s")
            if br.get("variant") != "bash" or br.get("shell") != {"pack_runs": 2, "script_runs": 1, "preflight_runs": 1,
                                                                   "bash_runs_with": 2, "bash_runs_without": 1}:
                fails.append("bash-lanes-row-variant-and-shell (got %s %s)" % (br.get("variant"), br.get("shell")))
            append(br, hist)
            try:
                append(dict(br, variant="zsh"), hist)
                fails.append("unknown-variant-refused")
            except SystemExit:
                pass
            try:
                lanes_row(combine("finops", {"ask": dict(ask, partial=True, partialReason="cost_ceiling")}),
                          "finops", "m", "j", "2026-10-19", "s")
                fails.append("partial-lane-refused")
            except SystemExit:
                pass
            limited = {"cases": [case("audit-fx-slice", 0, 0, err="API Error: usage limit reached")]}
            if not limit_state(limited)[0] or limit_state(ask)[0]:
                fails.append("limit-state-finds-a-usage-limit-error-and-only-that")
            if not limit_state({}, "Warning: rate limit reached for this run")[0]:
                fails.append("limit-state-reads-the-cli-warning")
            try:
                lanes_row(combine("finops", {"ask": limited}), "finops", "m", "j", "2026-10-19", "s")
                fails.append("usage-limit-lane-refused")
            except SystemExit:
                pass
            render(res, hist)
            body = open(res).read()
            if "| finops | m | j | s | 1/2 | 0.80 | +0.05 | 0.60 / 0.50 | +0.10 | 0.80 | +0.30 | 50% | $1.60 |" not in body:
                fails.append("lanes-row-rendered")
            if "| vuln-fullstack | /security-audit | claude-test-model | t | abc123 | 1 | 12/14 | 86% | 90% | 83% (1/6 flagged) | 3 |" not in body:
                fails.append("detection-row-rendered")
            if "| security | m | j | s | 2/3 | 0.90 | +0.40 | — | — | — | — | — | $1.50 |" not in body:
                fails.append("eval-row-rendered")
            if "| 2026-10-20 | finops | m | j | s | 0.60 / 0.50 | +0.10 | 0.80 | +0.30 | +0.30 | 50% | 1/2 | 1/2 | 2 / 1 | $1.60 |" \
                    not in body:
                fails.append("bash-row-rendered-beside-the-no-bash-cmd-delta")
            if body.count("| finops | m | j | s |") != 2:   # the no-Bash table holds the no-Bash row only
                fails.append("bash-row-kept-out-of-the-no-bash-table")
            if "NO RUN HAS BEEN RECORDED YET" in body:
                fails.append("banner-flips-once-rows-exist")
            m = os.stat(res).st_mtime_ns
            os.utime(res, ns=(m - 10 ** 9, m - 10 ** 9))
            render(res, hist)
            if os.stat(res).st_mtime_ns != m - 10 ** 9:
                fails.append("unchanged-render-does-not-rewrite")
            if render(res, hist, check=True) != 0:
                fails.append("check-passes-when-fresh")
            with open(hist, "a") as fh:
                fh.write(json.dumps(dict(r, fixture="node-api")) + "\n")
            if render(res, hist, check=True) != 1:
                fails.append("check-fails-when-stale")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        print("FAIL  history self-test: " + f, file=sys.stderr)
    print("history self-test: %s (%d failure(s))" % ("PASS" if not fails else "FAIL", len(fails)))
    return 2 if fails else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if not argv:
        print(__doc__.split("\n\n")[0])
        return 1
    cmd, (opts, _) = argv[0], parse(argv[1:])
    today = opts.get("date") or datetime.date.today().isoformat()
    if cmd == "append":
        if opts.get("from-score-json"):
            o = last_json(opts["from-score-json"])
        else:
            o = {k: opts.get(k) for k in ("fixture", "command", "model")}
            o["model_version"] = opts.get("model-version")
            for k in ("seeded", "detected", "decoys", "decoys-flagged", "unmatched"):
                if opts.get(k) not in (None, ""):
                    o[k.replace("-", "_")] = int(opts[k])
        for k in ("model", "date"):
            if opts.get(k):
                o[k] = opts[k]
        if opts.get("model-version"):
            o["model_version"] = opts["model-version"]
        o["runs"] = opts.get("runs") or 1
        o["findings_file"] = opts.get("findings")
        o["notes"] = opts.get("notes") or o.get("notes")
        o["git_sha"] = opts.get("sha") or git_sha()
        append(detection_row(o, today))
        return render()
    if cmd == "append-eval":
        if not opts.get("from-eval-json") or not opts.get("pack"):
            die("append-eval needs --from-eval-json=<aggregate-result.json> and --pack=<pack>")
        doc = json.load(open(opts["from-eval-json"], encoding="utf-8"))
        if opts.get("variant") not in (None, "", "bash"):
            die("--variant must be bash (or omitted)")
        build = lanes_row if doc.get("schema") == LANES else eval_row
        append(build(doc, opts["pack"], opts.get("model"), opts.get("judge-model"), today, opts.get("sha") or git_sha(),
                     opts.get("variant") or None))
        return render()
    if cmd == "combine-lanes":
        if not opts.get("pack") or not opts.get("ask") or not opts.get("out"):
            die("combine-lanes needs --pack, --ask=<json> and --out=<file>")
        docs = {}
        for k in ("ask", "stays", "cmd"):
            f = opts.get(k)
            docs[k] = json.load(open(f, encoding="utf-8")) if f and os.path.isfile(f) and os.path.getsize(f) else None
        if docs["ask"] is None:
            die("combine-lanes: no ask result at %s" % opts["ask"])
        out = combine(opts["pack"], docs, opts.get("variant") or None)
        with open(opts["out"], "w", encoding="utf-8") as fh:
            json.dump(out, fh, indent=1)
        print(json.dumps(dict(out["summary"], cost_usd=out["costUsd"], partial=out["partial"],
                              partial_reason=out["partialReason"] or None), sort_keys=True))
        return 0
    if cmd == "limit-check":
        f, log = opts.get("eval-json"), opts.get("log")
        doc = json.load(open(f, encoding="utf-8")) if f and os.path.isfile(f) and os.path.getsize(f) else {}
        text = open(log, encoding="utf-8", errors="replace").read() if log and os.path.isfile(log) else ""
        hits, util = limit_state(doc, text)
        print("utilization %s" % (" ".join("%s=%.2f" % kv for kv in sorted(util.items())) or "unreported"))
        for h in hits:
            print("LIMIT " + h)
        return 3 if hits else 0
    if cmd == "render":
        return render(check="check" in opts)
    die("unknown command %r (append | append-eval | combine-lanes | limit-check | render | --self-test)" % cmd)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
