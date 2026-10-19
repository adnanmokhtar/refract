#!/usr/bin/env python3
"""review-dismissals.py — the review-dismissals sink's CLI: record a human dismissal, backfill the
verifier's refutations, and PROPOSE calibration (spec § 5.8). It never edits a detector, a precedent or
a gate; a human confirms every proposal through /learn-from-task's confirm-list.

  dismiss <run_id> <reviews file>#F-n --reason=accepted-risk|false-positive --by=<who> --note=<why>
          One human dismissal. test-lock.sh asks the human before this runs (and refuses it with
          permission prompts off): a builder that dismisses the findings against it is the reward hack.
  ingest  Backfill every ai/runs/*/verdict-refute.json's refuted candidates (persist-verdict.sh already
          does this as each verdict lands; ingest is idempotent).
  propose [--write] [--json] [--min-count=3] [--min-runs=2] [--max-rate=0.10] [--min-raised=20]
          Promotion: a class dismissed >= min-count times with the SAME reason, over >= min-runs runs
          -> a precedent candidate (the case is settled; stop re-arguing it per finding).
          Demotion: a detector section (or a class, when findings carry no `detector`) whose
          dismissal rate (refuted + false-positive over raised) is above max-rate with >= min-raised
          findings raised -> a severity / scope / gate-mode demotion candidate. Defaults are the
          shadow-mode bar of spec § 5.8 (Tricorder): >= 20 runs, false-block rate <= 10 %.
          --write regenerates ai/dynamic/calibration-proposals.md (only when its content changed).
  --self-test

THE SINK — ai/dynamic/review-dismissals.jsonl, append-only, committed, one JSON object per line:
  schema "refract/dismissal/v1" · date YYYY-MM-DD · ts · run_id · source (<reviews file>#F-n) ·
  lens · class (<lens>/<class>, the finding's `kind`) · detector (<pack>/<skill>§<n> or null) ·
  severity · file · line · fingerprint (16 hex: sha256 of class + path + the flagged line's text) ·
  reason (refuted | accepted-risk | false-positive) · gate (refuted: the gate that failed) ·
  note (why) · by (the verifier's agent type, or the human) · recorded_by (persist-verdict.sh |
  review-dismissals.py). Writers: persist-verdict.sh (refuted) and `dismiss` (human reasons).
  Edit/Write to it is denied by test-lock.sh. A (run, fingerprint, reason) is never written twice.

  accepted-risk is NOT a precision failure (the finding was true; the risk was taken), so it feeds
  promotion but never demotion.

Exit codes: 0 ok · 1 usage / unresolved reference · 2 self-test failure. Stdlib only.
"""
import json
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import refract_records as rr  # noqa: E402

PROPOSALS = os.path.join("ai", "dynamic", "calibration-proposals.md")
HUMAN_REASONS = ("accepted-risk", "false-positive")
PRECISION_FAIL = ("refuted", "false-positive")


def repo_root(opts):
    return rr.toplevel(opts.get("repo", ".")) or os.path.abspath(opts.get("repo", "."))


def cmd_dismiss(repo, pos, opts):
    if len(pos) != 2:
        print("usage: dismiss <run_id> <reviews file>#F-n --reason=… --by=… --note=…", file=sys.stderr)
        return 1
    run_id, ref = pos
    reason, by, note = opts.get("reason"), (opts.get("by") or "").strip(), (opts.get("note") or "").strip()
    errs = []
    if not rr.RUN_ID.match(run_id):
        errs.append("run_id %r is not a Refract run id" % run_id)
    if reason not in HUMAN_REASONS:
        errs.append("--reason must be accepted-risk or false-positive (refuted comes only from the verifier's "
                    "verdict, through persist-verdict.sh)")
    if not by:
        errs.append("--by names the human who dismisses it")
    if len(note) < 10:
        errs.append("--note says why, in a sentence a reader can check (>= 10 chars)")
    rev, f = rr.review_finding(repo, run_id, ref)
    if f is None:
        errs.append("%s does not resolve to a persisted review finding (ai/runs/%s/reviews/<file>#F-n)" % (ref, run_id))
    if errs:
        for e in errs:
            print("review-dismissals: " + e, file=sys.stderr)
        return 1
    rec = rr.dismissal(repo, run_id, ref, f, reason, "human:" + by, note, "review-dismissals.py",
                       lens=(rev or {}).get("lens"))
    n = rr.append_dismissals(repo, [rec])
    print("review-dismissals: %s %s (%s, fingerprint %s)" % ("recorded" if n else "already recorded", ref,
                                                            reason, rec["fingerprint"]))
    return 0


def cmd_ingest(repo):
    runs = os.path.join(repo, "ai", "runs")
    total = 0
    for rid in sorted(os.listdir(runs)) if os.path.isdir(runs) else []:
        p = os.path.join(runs, rid, "verdict-refute.json")
        if not os.path.isfile(p):
            continue
        try:
            v = json.load(open(p, encoding="utf-8"))
        except ValueError:
            print("review-dismissals: %s does not parse — skipped" % p, file=sys.stderr)
            continue
        if v.get("mode") == "refute" and v.get("run_id"):
            total += rr.append_dismissals(repo, rr.refuted_dismissals(repo, v))
    print("review-dismissals: ingest appended %d record(s)" % total)
    return 0


def raised_findings(repo):
    """Every persisted review finding: (key, run_id, fingerprint) with key = detector or class."""
    out = []
    runs = os.path.join(repo, "ai", "runs")
    for rid in sorted(os.listdir(runs)) if os.path.isdir(runs) else []:
        rdir = os.path.join(runs, rid, "reviews")
        for name in sorted(os.listdir(rdir)) if os.path.isdir(rdir) else []:
            if not name.endswith(".json"):
                continue
            try:
                rec = json.load(open(os.path.join(rdir, name), encoding="utf-8"))
            except ValueError:
                continue
            for f in rec.get("findings", []):
                kind = f.get("kind") or "unclassified/unclassified"
                out.append((f.get("detector") or kind, rid, rr.fingerprint(repo, kind, f.get("file"), f.get("line"))))
    return out


def proposals(repo, min_count=3, min_runs=2, max_rate=0.10, min_raised=20):
    ds = rr.read_dismissals(repo)
    promo, seen = {}, set()
    for d in ds:
        if d.get("class", "").startswith("unclassified/"):
            continue
        k = (d["class"], d["reason"])
        u = (d["run_id"], d["fingerprint"], d["reason"])
        if u in seen:
            continue
        seen.add(u)
        e = promo.setdefault(k, {"class": k[0], "reason": k[1], "count": 0, "runs": set(), "notes": [], "sources": []})
        e["count"] += 1
        e["runs"].add(d["run_id"])
        if d.get("note") and d["note"] not in e["notes"]:
            e["notes"].append(d["note"])
        e["sources"].append("%s:%s" % (d["run_id"], d.get("source")))
    promote = [dict(e, runs=sorted(e["runs"])) for k, e in sorted(promo.items())
               if e["count"] >= min_count and len(e["runs"]) >= min_runs]
    raised, dismissed = {}, {}
    for key, rid, fp in raised_findings(repo):
        raised.setdefault(key, set()).add((rid, fp))
    for d in ds:
        if d.get("reason") in PRECISION_FAIL:
            key = d.get("detector") or d.get("class")
            dismissed.setdefault(key, set()).add((d["run_id"], d["fingerprint"]))
            raised.setdefault(key, set()).add((d["run_id"], d["fingerprint"]))  # a refuted candidate was raised
    demote = []
    for key in sorted(raised):
        n, m = len(raised[key]), len(dismissed.get(key, ()))
        if n >= min_raised and m / float(n) > max_rate:
            demote.append({"key": key, "raised": n, "dismissed": m, "rate": round(m / float(n), 4),
                           "is_detector": "§" in key})
    return {"schema": "refract/calibration-proposals/v1", "dismissals": len(ds),
            "runs": len({d["run_id"] for d in ds}),
            "thresholds": {"min_count": min_count, "min_runs": min_runs, "max_rate": max_rate, "min_raised": min_raised},
            "promote": promote, "demote": demote}


def render(p):
    t = p["thresholds"]
    L = ["# Calibration proposals",
         "",
         "GENERATED by `.claude/scripts/review-dismissals.py propose --write` from "
         "`ai/dynamic/review-dismissals.jsonl` — do not edit; regenerate. Nothing here is applied: a human",
         "confirms each line through `/learn-from-task`'s confirm-list, and the promotion it makes carries an audit",
         "line (`.claude/templates/snippets/learning-sink.md` § Confirm-list and the promotion audit line).",
         "",
         "Source: %d dismissal(s) across %d run(s). Promote: one class dismissed >= %d times with the same reason "
         "over >= %d runs. Demote: dismissal rate (refuted + false-positive) > %d%% with >= %d raised (spec § 5.8)."
         % (p["dismissals"], p["runs"], t["min_count"], t["min_runs"], round(t["max_rate"] * 100), t["min_raised"]),
         "", "## Promotion candidates (precedent)", ""]
    if not p["promote"]:
        L.append("None at these thresholds.")
    for e in p["promote"]:
        L.append("- [ ] `%s` dismissed %d× as **%s** across %d runs → precedent candidate. Why, in the dismissers' "
                 "words: %s. Evidence: %s"
                 % (e["class"], e["count"], e["reason"], len(e["runs"]),
                    " · ".join('"%s"' % n for n in e["notes"][:3]) or "(no note)", ", ".join(e["sources"][:5])))
    L += ["", "## Demotion candidates (detector or class)", ""]
    if not p["demote"]:
        L.append("None at these thresholds.")
    for e in p["demote"]:
        L.append("- [ ] `%s` — %d of %d raised were refuted or false-positive (%d%%) → demote: severity IMPORTANT→NIT, "
                 "narrow the %s's scope, or move its gate to `mode: warn`/`shadow` in .claude/gates.yaml"
                 % (e["key"], e["dismissed"], e["raised"], round(e["rate"] * 100),
                    "detector section" if e["is_detector"] else "class"))
    return "\n".join(L) + "\n"


def cmd_propose(repo, opts):
    try:
        p = proposals(repo, int(opts.get("min-count", 3)), int(opts.get("min-runs", 2)),
                      float(opts.get("max-rate", 0.10)), int(opts.get("min-raised", 20)))
    except ValueError as e:
        print("review-dismissals: bad threshold: %s" % e, file=sys.stderr)
        return 1
    if "json" in opts:
        print(json.dumps(p, indent=2, ensure_ascii=False))
    else:
        sys.stdout.write(render(p))
    if "write" in opts:
        out = os.path.join(repo, PROPOSALS)
        text = render(p)
        old = open(out, encoding="utf-8").read() if os.path.isfile(out) else None
        if old != text:                     # a write that changes nothing would still move the mtime
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with open(out, "w", encoding="utf-8") as fh:
                fh.write(text)
        print("review-dismissals: %s %s" % ("unchanged" if old == text else "wrote", PROPOSALS), file=sys.stderr)
    return 0


def self_test():
    import contextlib
    import io
    sink = io.StringIO()
    with contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
        fails = _self_test()
    for f in fails:
        print("FAIL  review-dismissals self-test: " + f, file=sys.stderr)
    print("review-dismissals self-test: %s (%d failure(s))" % ("PASS" if not fails else "FAIL", len(fails)))
    return 2 if fails else 0


def _self_test():
    fails = []

    def check(cond, name):
        if not cond:
            fails.append(name)

    tmp = tempfile.mkdtemp(prefix="review-dismissals-")
    try:
        rid_a, rid_b = "20261019-orders-list-a1b2", "20261019-orders-page-c3d4"
        os.makedirs(os.path.join(tmp, "src"))
        with open(os.path.join(tmp, "src", "orders.ts"), "w") as fh:
            fh.write("const rows = await db.order.findMany();\nfor (const r of rows) { await db.item.find(r.id); }\n")
        for rid in (rid_a, rid_b):
            d = os.path.join(tmp, "ai", "runs", rid, "reviews")
            os.makedirs(d)
            fs = [{"id": "F-%d" % i, "severity": "IMPORTANT", "kind": "performance/n-plus-one", "file": "src/orders.ts",
                   "line": 2, "claim": "When the list loads, src/orders.ts:2 issues one query per row",
                   "detector": "database/n-plus-one-scan§2"} for i in range(1, 12)]
            json.dump({"schema": "refract/findings/v1", "run_id": rid, "lens": "performance", "findings": fs},
                      open(os.path.join(d, "perf-performance.json"), "w"))
            v = {"schema": "refract/verdict/v1", "run_id": rid, "mode": "refute", "verdict": "PASS", "summary": "x",
                 "signer": {"agent_type": "verifier"},
                 "findings": [{"id": "reviews/perf-performance.json#F-1", "bucket": "refuted", "severity": "IMPORTANT",
                               "claim": "When the list loads, one query per row", "gate": "§3 reachability",
                               "reason": "the loop runs over a constant 3-row list"}]}
            json.dump(v, open(os.path.join(tmp, "ai", "runs", rid, "verdict-refute.json"), "w"))
        opts = {"repo": tmp}
        check(cmd_ingest(tmp) == 0 and len(rr.read_dismissals(tmp)) == 2, "ingest-appends-one-refuted-per-run")
        cmd_ingest(tmp)
        check(len(rr.read_dismissals(tmp)) == 2, "ingest-is-idempotent")
        r0 = rr.read_dismissals(tmp)[0]
        check(r0["class"] == "performance/n-plus-one" and r0["detector"] == "database/n-plus-one-scan§2"
              and r0["reason"] == "refuted" and r0["gate"] == "§3 reachability" and len(r0["fingerprint"]) == 16,
              "refuted-record-carries-class-detector-gate-fingerprint")
        check(cmd_dismiss(tmp, [rid_a, "reviews/perf-performance.json#F-2"],
                          dict(opts, reason="false-positive", by="owner", note="constant-size lookup table")) == 0,
              "human-dismiss-recorded")
        check(cmd_dismiss(tmp, [rid_a, "reviews/perf-performance.json#F-99"],
                          dict(opts, reason="false-positive", by="owner", note="constant-size lookup table")) == 1,
              "unresolved-reference-refused")
        check(cmd_dismiss(tmp, [rid_a, "reviews/perf-performance.json#F-3"],
                          dict(opts, reason="refuted", by="owner", note="constant-size lookup table")) == 1,
              "human-cannot-claim-refuted")
        check(cmd_dismiss(tmp, [rid_a, "reviews/perf-performance.json#F-3"],
                          dict(opts, reason="accepted-risk", by="", note="x")) == 1, "who-and-why-required")
        # Same fingerprint (same line) in run a, reason false-positive: one more record, then a dup is refused.
        n_before = len(rr.read_dismissals(tmp))
        cmd_dismiss(tmp, [rid_a, "reviews/perf-performance.json#F-2"],
                    dict(opts, reason="false-positive", by="owner", note="constant-size lookup table"))
        check(len(rr.read_dismissals(tmp)) == n_before, "duplicate-dismissal-not-written-twice")
        p = proposals(tmp)
        check(p["promote"] == [] and p["demote"] == [], "below-thresholds-proposes-nothing")
        p = proposals(tmp, min_count=2, min_runs=2, max_rate=0.10, min_raised=1)
        check(len(p["promote"]) == 1 and p["promote"][0]["class"] == "performance/n-plus-one"
              and p["promote"][0]["reason"] == "refuted" and p["promote"][0]["count"] == 2, "promotion-at-threshold")
        check(len(p["demote"]) == 1 and p["demote"][0]["key"] == "database/n-plus-one-scan§2"
              and p["demote"][0]["is_detector"], "demotion-keys-on-detector-section")
        # accepted-risk feeds promotion, never demotion (the finding was true; the risk was taken).
        with open(os.path.join(tmp, "src", "orders.ts"), "a") as fh:
            fh.write("export const cache = new Map();\n")
        rev_b = os.path.join(tmp, "ai", "runs", rid_b, "reviews", "perf-performance.json")
        rb = json.load(open(rev_b))
        rb["findings"].append({"id": "F-50", "severity": "IMPORTANT", "kind": "performance/unbounded-cache",
                               "file": "src/orders.ts", "line": 3, "detector": "performance/cache-scan§4",
                               "claim": "When traffic grows, src/orders.ts:3 grows the map without bound"})
        json.dump(rb, open(rev_b, "w"))
        cmd_dismiss(tmp, [rid_b, "reviews/perf-performance.json#F-50"],
                    dict(opts, reason="accepted-risk", by="owner", note="bounded by the 40-SKU catalogue"))
        p2 = proposals(tmp, min_count=1, min_runs=1, max_rate=0.0, min_raised=1)
        check(any(e["reason"] == "accepted-risk" for e in p2["promote"]) and
              all(e["key"] != "performance/cache-scan§4" for e in p2["demote"]), "accepted-risk-promotes-never-demotes")
        md = render(p)
        check("database/n-plus-one-scan§2" in md and "precedent candidate" in md and "[ ]" in md, "render-lists-both")
        out = os.path.join(tmp, PROPOSALS)
        cmd_propose(tmp, {"write": "", "min-count": "2", "min-raised": "1"})
        m1 = os.stat(out).st_mtime_ns
        os.utime(out, ns=(m1 - 10 ** 9, m1 - 10 ** 9))
        cmd_propose(tmp, {"write": "", "min-count": "2", "min-raised": "1"})
        check(os.stat(out).st_mtime_ns == m1 - 10 ** 9, "unchanged-proposals-not-rewritten")
        check(os.stat(os.path.join(tmp, rr.DISMISSALS)).st_size > 0 and
              all(json.loads(l)["schema"] == "refract/dismissal/v1"
                  for l in open(os.path.join(tmp, rr.DISMISSALS))), "sink-is-jsonl-of-v1-records")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return fails


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if not argv:
        print(__doc__.split("\n\n")[0], file=sys.stderr)
        return 1
    cmd, rest = argv[0], argv[1:]
    opts = {}
    for a in rest:
        if a.startswith("--"):
            k, _, v = a[2:].partition("=")
            opts[k] = v
    pos = [a for a in rest if not a.startswith("--")]
    repo = repo_root(opts)
    if cmd == "dismiss":
        return cmd_dismiss(repo, pos, opts)
    if cmd == "ingest":
        return cmd_ingest(repo)
    if cmd == "propose":
        return cmd_propose(repo, opts)
    print("review-dismissals: unknown command %r (dismiss | ingest | propose | --self-test)" % cmd, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
