#!/usr/bin/env python3
"""history.py — Refract's quality as a time series: append one measured run to
benchmarks/results/history.jsonl and regenerate the tables in benchmarks/RESULTS.md from it.

Stdlib only. No network.

  python3 benchmarks/history.py append --from-score-json=<score.py --json output> [--findings=<file>] [--notes=…]
  python3 benchmarks/history.py append --fixture=vuln-fullstack --command=/security-audit \\
      --detected=12 --seeded=14 [--decoys=6 --decoys-flagged=1] --model=<exact id> \\
      [--model-version=…] [--date=YYYY-MM-DD] [--runs=1] [--findings=<file>] [--notes=…]
  python3 benchmarks/history.py append-eval --from-eval-json=<aggregate-result.json> --pack=<pack> --model=<id> [--judge-model=<id>]
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


def eval_row(doc, pack, model, judge, today, sha):
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
            "claude_version": doc.get("claudeVersion"), "notes": ""}


def pct(x):
    return "—" if x is None else "%d%%" % round(x * 100)


def tables(rows):
    det = [r for r in rows if r.get("kind") == "detection"]
    ev = [r for r in rows if r.get("kind") == "plugin-eval"]
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
    E = ["| date | pack | model | judge | sha | cases passed | score | Δ vs no-plugin | cost | notes |",
         "|------|------|-------|-------|-----|--------------|-------|-----------------|------|-------|"]
    for r in sorted(ev, key=lambda r: (r["date"], r["pack"])):
        E.append("| %s | %s | %s | %s | %s | %s/%s | %s | %s | %s | %s |" % (
            r["date"], r["pack"], r["model"], r.get("judge_model") or "—", (r.get("git_sha") or "—")[:12],
            r.get("cases_passed"), r.get("cases"), "—" if r.get("score") is None else "%.2f" % r["score"],
            "—" if r.get("mean_delta") is None else "%+.2f" % r["mean_delta"],
            "—" if r.get("cost_usd") is None else "$%.2f" % r["cost_usd"], r.get("notes") or "—"))
    if not ev:
        E.append("| — | — | — | — | — | — | — | — | — | *no eval run recorded* |")
    return "\n".join(T), "\n".join(E)


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
    det, ev = tables(rows)
    old = open(results, encoding="utf-8").read()
    new = replace_block(old, "banner", EMPTY_BANNER if not rows else ROWS_BANNER)
    new = replace_block(new, "detection", det)
    new = replace_block(new, "eval", ev)
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
                     "<!-- history:eval:begin -->\nx\n<!-- history:eval:end -->\n")
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
            render(res, hist)
            body = open(res).read()
            if "| vuln-fullstack | /security-audit | claude-test-model | t | abc123 | 1 | 12/14 | 86% | 90% | 83% (1/6 flagged) | 3 |" not in body:
                fails.append("detection-row-rendered")
            if "| security | m | j | s | 2/3 | 0.90 | +0.40 | $1.50 |" not in body:
                fails.append("eval-row-rendered")
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
        append(eval_row(doc, opts["pack"], opts.get("model"), opts.get("judge-model"), today,
                        opts.get("sha") or git_sha()))
        return render()
    if cmd == "render":
        return render(check="check" in opts)
    die("unknown command %r (append | append-eval | render | --self-test)" % cmd)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
