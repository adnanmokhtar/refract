#!/usr/bin/env python3
"""perf-compare.py — is HEAD slower than its base, by more than the threshold, beyond the noise?

Usage:  perf-compare.py --base-cmd=<cmd> --head-cmd=<cmd> [--base-dir=<dir>] [--head-dir=<dir>]
                        [--runs=<n>] [--warmup=<n>] [--wall] [--bench=<name>] [--save=<file>]
        perf-compare.py --pairs=<file>                       (a run this script saved with --save)
        perf-compare.py --base=<file> --head=<file> --not-interleaved-ok
        common: [--threshold=<pct>] [--min-runs=<n>] [--higher-is-better] [--repo=<dir>] [--json]
        perf-compare.py --self-test
Exit:   0  NO-CHANGE · WITHIN-THRESHOLD · IMPROVEMENT
        1  REGRESSION — a slowdown past the threshold that the noise cannot explain
        3  refused: SUSPECTED-REGRESSION · INSUFFICIENT-RUNS · TOO-NOISY · NOT-INTERLEAVED · NO-DATA
           (never read as a pass, never as a block)
        2  usage error

WHY. A timing gate that trusts one run per side is a coin flip, and one that re-runs until it turns
significant is a coin flip with extra steps. The rules this script enforces are the ones in
templates/snippets/proof-oracles.md § Performance, and the numbers live in THR-PERF-REGRESSION
(.claude/templates/governance/thresholds.json; a project value in .claude/thresholds.local.json wins):

  * runs per side >= min_runs_per_side (10), never fewer than 5 whatever the override says. Go's
    `go test -bench -count=3` cannot reach significance: an exact two-sided Mann-Whitney at 3 vs 3
    cannot go below p = 0.10. Below the floor this script REFUSES rather than guessing.
  * base and head INTERLEAVED on the same machine (ABBA pairs, so a drifting machine biases neither
    side). Two sample files recorded separately are refused unless --not-interleaved-ok says the
    caller knows what it is giving up.
  * the 95% confidence interval of the shift must EXCLUDE ZERO (Mann-Whitney / Hodges-Lehmann,
    distribution-free: timing data is skewed, a t-test's normality is not a given).
  * the effect must exceed the threshold (max_regression_pct, 10%) AND the measured noise band (the
    base side's robust coefficient of variation). A significant 3% slowdown is WITHIN-THRESHOLD; a
    measurement whose interval is too wide to have seen a threshold-sized regression is TOO-NOISY,
    never NO-CHANGE.
  * a FAIL needs the WHOLE interval past the threshold, not only past zero. Measured by the self-test:
    "excludes zero and the point estimate is past 10%" blocked 3 of 400 identical-distribution pairs at
    a CV of 8% (n = 10); "the lower bound is past 10%" blocked 0. A significant slowdown whose interval
    straddles the threshold is SUSPECTED-REGRESSION — refused, so the gate says UNVERIFIED, not PASS.

VERDICT RULE (lower is better unless --higher-is-better):
  shift  = Hodges-Lehmann estimate of head - base (median of all pairwise differences)
  pct    = 100 * shift / median(base);  [lo, hi] = its 95% CI in percent
  REGRESSION        lo > threshold, pct > noise band
  SUSPECTED-REGR.   lo > 0, pct > threshold, lo <= threshold                       (refused)
  WITHIN-THRESHOLD  lo > 0, pct <= threshold
  IMPROVEMENT       hi < 0
  TOO-NOISY         CI includes zero but its upper end reaches past the threshold (a threshold-sized
                    regression would have been invisible), or the significant effect is inside the noise band
  NO-CHANGE         CI includes zero and stays inside +/- threshold

INPUT. Each run's output (or a samples file) is read as: JSON — a list of numbers, {"samples": [...]},
hyperfine --export-json (results[].times), pytest-benchmark --benchmark-json (benchmarks[].stats.data,
else stats.median), JMH -rf json (primaryMetric.rawData, else score), vitest bench --outputJson
(files[].groups[].benchmarks[].median); text — `go test -bench` lines (ns/op), else every number, one
per line, with the LAST number on the output taken when a run prints one measurement. --bench=<name>
picks one benchmark out of several. --wall times the command itself instead of reading its output.
"""
import json
import math
import os
import random
import re
import statistics
import subprocess
import sys
import tempfile
import time

HARD_FLOOR = 5
DEFAULTS = {"max_regression_pct": 10.0, "min_runs_per_side": 10}
REFUSED = ("INSUFFICIENT-RUNS", "TOO-NOISY", "NOT-INTERLEAVED", "NO-DATA", "SUSPECTED-REGRESSION")
GO_LINE = re.compile(r"^(Benchmark\S+?)(?:-\d+)?\s+\d+\s+([0-9.]+(?:e[+-]?\d+)?)\s+ns/op", re.M)
NUM = re.compile(r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?")


# ── thresholds ────────────────────────────────────────────────────────────────────────────────
def thresholds(repo):
    val = dict(DEFAULTS)
    for rel in (os.path.join(".claude", "templates", "governance", "thresholds.json"), os.path.join(".claude", "thresholds.local.json")):
        p = os.path.join(repo, rel)
        try:
            v = json.load(open(p, encoding="utf-8"))["thresholds"]["THR-PERF-REGRESSION"]["value"]
            val.update({k: float(v[k]) for k in DEFAULTS if k in v})
        except (OSError, ValueError, KeyError, TypeError):
            continue
    return val


# ── parsing ───────────────────────────────────────────────────────────────────────────────────
def _pick(items, bench, name_key):
    if bench:
        items = [i for i in items if bench in str(i.get(name_key, ""))]
    return items[:1] if len(items) > 1 and not bench else items


def parse_values(text, bench=None, per_run=False):
    """-> list of floats read from one run's output or one samples file. per_run=True: a single run's
    output, so a JSON report with many raw samples is reduced to its own summary (one value)."""
    text = (text or "").strip()
    if not text:
        return []
    try:
        d = json.loads(text)
    except ValueError:
        d = None
    if d is not None:
        if isinstance(d, (int, float)) and not isinstance(d, bool):
            return [float(d)]
        if isinstance(d, list) and all(isinstance(x, (int, float)) and not isinstance(x, bool) for x in d):
            return [float(x) for x in d]
        if isinstance(d, dict) and isinstance(d.get("samples"), list):
            return [float(x) for x in d["samples"]]
        if isinstance(d, dict) and isinstance(d.get("results"), list):             # hyperfine
            vals = []
            for r in _pick(d["results"], bench, "command"):
                ts = r.get("times") or ([r["median"]] if "median" in r else [])
                vals += [statistics.median(ts)] if per_run and ts else [float(t) for t in ts]
            return vals
        if isinstance(d, dict) and isinstance(d.get("benchmarks"), list):          # pytest-benchmark
            vals = []
            for b in _pick(d["benchmarks"], bench, "name"):
                st = b.get("stats") or {}
                vals += [float(st["median"])] if per_run or not st.get("data") else [float(x) for x in st["data"]]
            return vals
        if isinstance(d, list) and d and isinstance(d[0], dict) and "primaryMetric" in d[0]:  # JMH
            vals = []
            for b in _pick(d, bench, "benchmark"):
                pm = b["primaryMetric"]
                raw = [x for fork in pm.get("rawData") or [] for x in fork]
                vals += [float(pm["score"])] if per_run or not raw else [float(x) for x in raw]
            return vals
        if isinstance(d, dict) and isinstance(d.get("files"), list):               # vitest bench
            bs = [b for f in d["files"] for g in f.get("groups", []) for b in g.get("benchmarks", [])]
            return [float(b.get("median", b.get("mean"))) for b in _pick(bs, bench, "name") if b.get("median", b.get("mean")) is not None]
        return []
    go = [(m.group(1), float(m.group(2))) for m in GO_LINE.finditer(text)]
    if go:
        sel = [v for n, v in go if not bench or bench in n] or ([] if bench else [go[0][1]])
        return [statistics.median(sel)] if per_run and sel else sel
    if per_run:
        nums = NUM.findall(text)
        return [float(nums[-1])] if nums else []
    return [float(n) for line in text.splitlines() for n in NUM.findall(line)[-1:]]


# ── statistics ────────────────────────────────────────────────────────────────────────────────
_DIST = {}


def u_distribution(m, n):
    """Exact null distribution of the Mann-Whitney U statistic (no ties): counts[u] for u in 0..m*n."""
    key = (min(m, n), max(m, n))
    if key in _DIST:
        return _DIST[key]
    a, b = key
    # f[j] = counts for (i, j) as i grows; recurrence f(i,j)[u] = f(i-1,j)[u-j] + f(i,j-1)[u]
    prev = [[1] for _ in range(b + 1)]                    # i = 0: one arrangement, U = 0
    for i in range(1, a + 1):
        cur = [[1]]                                       # j = 0: U = 0
        for j in range(1, b + 1):
            size = i * j + 1
            row = [0] * size
            for u, c in enumerate(prev[j]):
                row[u + j] += c
            for u, c in enumerate(cur[j - 1]):
                row[u] += c
            cur.append(row)
        prev = cur
    _DIST[key] = prev[b]
    return prev[b]


def norm_cdf(z):
    return 0.5 * (1 + math.erf(z / math.sqrt(2)))


def mann_whitney(base, head):
    """-> (U of head over base, two-sided p, method)."""
    m, n = len(base), len(head)
    u = sum((h > b) + 0.5 * (h == b) for b in base for h in head)
    pooled = sorted(base + head)
    ties = len(pooled) != len(set(pooled))
    if m <= 30 and n <= 30 and not ties:
        dist = u_distribution(m, n)
        tot = float(sum(dist))
        k = int(round(u))
        lo, hi = sum(dist[:k + 1]) / tot, sum(dist[k:]) / tot
        return u, min(1.0, 2 * min(lo, hi)), "exact"
    counts = {}
    for x in pooled:
        counts[x] = counts.get(x, 0) + 1
    N = m + n
    tie = sum(t ** 3 - t for t in counts.values())
    var = m * n / 12.0 * ((N + 1) - tie / float(N * (N - 1)))
    if var <= 0:
        return u, 1.0, "normal"
    z = (abs(u - m * n / 2.0) - 0.5) / math.sqrt(var)
    return u, min(1.0, 2 * (1 - norm_cdf(max(z, 0.0)))), "normal"


def hl_interval(base, head, alpha=0.05):
    """Hodges-Lehmann shift (head - base) and its distribution-free (1-alpha) CI; (shift, lo, hi).
    lo/hi are None when the sample sizes cannot bound the interval at this alpha (3 vs 3 cannot)."""
    m, n = len(base), len(head)
    d = sorted(h - b for b in base for h in head)
    shift = statistics.median(d)
    if m <= 30 and n <= 30:
        dist = u_distribution(m, n)
        tot = float(sum(dist))
        c, acc = 0, 0.0
        while c < len(dist) and acc + dist[c] / tot <= alpha / 2:   # largest c with P(U <= c-1) <= alpha/2
            acc += dist[c] / tot
            c += 1
    else:
        z = 1.959963984540054
        c = int(math.floor(m * n / 2.0 - z * math.sqrt(m * n * (m + n + 1) / 12.0)))
    if c < 1:
        return shift, None, None
    return shift, d[c - 1], d[m * n - c]


def robust_cv(xs):
    med = statistics.median(xs)
    if med == 0:
        return float("inf")
    mad = statistics.median(abs(x - med) for x in xs)
    return 100.0 * 1.4826 * mad / abs(med)


def compare(base, head, threshold=10.0, min_runs=10, lower_is_better=True, interleaved=True):
    """-> dict with verdict, numbers and the sentence that justifies the verdict."""
    floor = max(HARD_FLOOR, int(min_runs))
    out = {"n_base": len(base), "n_head": len(head), "threshold_pct": threshold, "min_runs": floor,
           "interleaved": interleaved, "lower_is_better": lower_is_better}
    if not base or not head:
        out.update(verdict="NO-DATA", why="no measurement was read from %s" % ("the base side" if not base else "the head side"))
        return out
    if not interleaved:
        out.update(verdict="NOT-INTERLEAVED", why="base and head were measured separately; the noise rules need them "
                   "interleaved on one machine (--base-cmd/--head-cmd), or --not-interleaved-ok to accept the risk")
        return out
    if min(len(base), len(head)) < floor:
        k = min(len(base), len(head))
        why = "%d run(s) on the smaller side; at least %d per side are needed" % (k, floor)
        if k <= 3:
            why += " — an exact two-sided Mann-Whitney at 3 vs 3 cannot go below p = 0.10 (why go test -bench -count=3 never reaches significance)"
        out.update(verdict="INSUFFICIENT-RUNS", why=why)
        return out
    mb = statistics.median(base)
    u, p, method = mann_whitney(base, head)
    shift, lo, hi = hl_interval(base, head)
    sign = 1.0 if lower_is_better else -1.0           # worse = positive
    pct = 100.0 * sign * shift / abs(mb) if mb else 0.0
    if lo is None:
        out.update(verdict="INSUFFICIENT-RUNS", why="the sample sizes cannot bound a 95% interval")
        return out
    clo, chi = sorted((100.0 * sign * lo / abs(mb), 100.0 * sign * hi / abs(mb)))
    noise = robust_cv(base)
    out.update({"median_base": mb, "median_head": statistics.median(head), "shift": shift, "delta_pct": round(pct, 3),
                "ci_pct": [round(clo, 3), round(chi, 3)], "p_value": round(p, 6), "test": "mann-whitney (%s)" % method,
                "noise_band_pct": round(noise, 3)})
    if clo > 0:
        if pct <= threshold:
            v, why = "WITHIN-THRESHOLD", "slower by %.1f%% (95%% CI %.1f..%.1f%%), inside the %.0f%% threshold" % (pct, clo, chi, threshold)
        elif pct <= noise:
            v, why = "TOO-NOISY", "slower by %.1f%% but the base side's own noise band is %.1f%%" % (pct, noise)
        elif clo > threshold:
            v, why = "REGRESSION", "slower by %.1f%% (95%% CI %.1f..%.1f%%, p=%.4f) — the whole interval is past the %.0f%% threshold, and past the %.1f%% noise band" % (pct, clo, chi, p, threshold, noise)
        else:
            v, why = "SUSPECTED-REGRESSION", "slower by %.1f%% (95%% CI %.1f..%.1f%%) — significant, but the interval reaches below the %.0f%% threshold, so it does not prove a regression past it; add runs (never re-run until it turns)" % (pct, clo, chi, threshold)
    elif chi < 0:
        v, why = "IMPROVEMENT", "faster by %.1f%% (95%% CI %.1f..%.1f%%)" % (-pct, clo, chi)
    elif chi > threshold:
        v, why = "TOO-NOISY", "no significant change, but the 95%% CI (%.1f..%.1f%%) reaches past the %.0f%% threshold — a threshold-sized regression would not have been seen; add runs or a quieter machine" % (clo, chi, threshold)
    else:
        v, why = "NO-CHANGE", "no change the noise cannot explain (95%% CI %.1f..%.1f%% includes zero, inside +/-%.0f%%)" % (clo, chi, threshold)
    out.update(verdict=v, why=why)
    return out


# ── running ───────────────────────────────────────────────────────────────────────────────────
def run_once(cmd, cwd, wall, bench, timeout):
    t0 = time.perf_counter()
    r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, errors="replace",
                       executable="/bin/bash", timeout=timeout, stdin=subprocess.DEVNULL)
    dt = time.perf_counter() - t0
    if r.returncode != 0:
        raise RuntimeError("`%s` exited %d in %s: %s" % (cmd, r.returncode, cwd, (r.stderr or r.stdout).strip()[-300:]))
    if wall:
        return dt
    vals = parse_values(r.stdout, bench, per_run=True)
    if not vals:
        raise RuntimeError("`%s` printed no measurement (pass --wall to time the command itself)" % cmd)
    return vals[0]


def interleaved(base_cmd, head_cmd, base_dir, head_dir, runs, warmup, wall, bench, timeout):
    for _ in range(warmup):
        run_once(base_cmd, base_dir, wall, bench, timeout)
        run_once(head_cmd, head_dir, wall, bench, timeout)
    base, head, order = [], [], []
    for i in range(runs):
        pair = (("base", base_cmd, base_dir), ("head", head_cmd, head_dir))
        for side, cmd, d in (pair if i % 2 == 0 else pair[::-1]):      # ABBA: drift biases neither side
            (base if side == "base" else head).append(run_once(cmd, d, wall, bench, timeout))
            order.append(side)
    return base, head, order


# ── self-test ─────────────────────────────────────────────────────────────────────────────────
def self_test():
    fails = []
    ok = lambda cond, name: None if cond else fails.append(name)
    d = u_distribution(3, 3)
    ok(sum(d) == 20 and abs(2.0 * d[0] / 20 - 0.10) < 1e-9, "exact U distribution 3x3: min two-sided p is 0.10")
    ok(sum(u_distribution(5, 7)) == math.comb(12, 5), "exact U distribution 5x7 sums to C(12,5)")
    ok(compare([1.0, 1.1, 0.9], [2.0, 2.1, 1.9])["verdict"] == "INSUFFICIENT-RUNS", "3 vs 3 is refused")
    ok("p = 0.10" in compare([1.0, 1.1, 0.9], [2.0, 2.1, 1.9])["why"], "the refusal names the 3 vs 3 floor")
    ok(compare([1.0] * 10, [1.2] * 10, interleaved=False)["verdict"] == "NOT-INTERLEAVED", "separate sample files are refused")
    rng = random.Random(20261005)
    for cv in (0.03, 0.08):                       # 0 false blocks over identical distributions
        false_blocks = 0
        for _ in range(400):
            b = [rng.lognormvariate(0, cv) for _ in range(10)]
            h = [rng.lognormvariate(0, cv) for _ in range(10)]
            false_blocks += compare(b, h)["verdict"] == "REGRESSION"
        ok(false_blocks == 0, "identical distributions (cv %.0f%%): %d false REGRESSION of 400" % (cv * 100, false_blocks))
    caught = 0
    for _ in range(100):                          # a 20% regression is caught
        b = [rng.lognormvariate(0, 0.03) for _ in range(10)]
        h = [1.2 * rng.lognormvariate(0, 0.03) for _ in range(10)]
        caught += compare(b, h)["verdict"] == "REGRESSION"
    ok(caught == 100, "20%% regression at cv 3%%: caught %d of 100" % caught)
    hi = compare([1.0 + 0.001 * i for i in range(10)], [0.8 + 0.001 * i for i in range(10)], lower_is_better=False)
    ok(hi["verdict"] == "REGRESSION", "higher-is-better: a 20% drop in throughput is a regression")
    ok(compare([1.0 + 0.01 * i for i in range(10)], [1.03 + 0.01 * i for i in range(10)])["verdict"] in ("WITHIN-THRESHOLD", "NO-CHANGE"), "a 3% shift is inside the threshold")
    noisy = [rng.lognormvariate(0, 0.5) for _ in range(10)]
    ok(compare(noisy, [rng.lognormvariate(0, 0.5) for _ in range(10)])["verdict"] in ("TOO-NOISY",), "a 50% cv measurement is TOO-NOISY, never NO-CHANGE")
    ok(parse_values("BenchmarkQuote-8   	 1000	      1234 ns/op\nBenchmarkOther-8 10 99 ns/op\n", "Quote") == [1234.0], "go test -bench line")
    ok(parse_values(json.dumps({"results": [{"command": "a", "times": [0.1, 0.2, 0.3]}]}), per_run=True) == [0.2], "hyperfine json, one run")
    ok(parse_values(json.dumps({"benchmarks": [{"name": "test_q", "stats": {"median": 0.5, "data": [0.4, 0.5, 0.6]}}]})) == [0.4, 0.5, 0.6], "pytest-benchmark raw data")
    ok(parse_values("warming up\nelapsed 12.5\n", per_run=True) == [12.5], "plain output: last number")
    for f in fails:
        print("FAIL  perf-compare self-test: %s" % f)
    print("perf-compare self-test: %d failure(s)" % len(fails))
    return 1 if fails else 0


# ── main ──────────────────────────────────────────────────────────────────────────────────────
def main(argv):
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    flags = {a for a in argv if a.startswith("--") and "=" not in a}
    known_o = {"base-cmd", "head-cmd", "base-dir", "head-dir", "runs", "warmup", "bench", "save", "pairs", "base",
               "head", "threshold", "min-runs", "repo", "timeout"}
    known_f = {"--wall", "--higher-is-better", "--json", "--not-interleaved-ok", "--self-test"}
    if (set(opts) - known_o) or (flags - known_f) or any(not a.startswith("--") for a in argv):
        print(__doc__.split("\n\n")[0].split("\n", 1)[1], file=sys.stderr)
        return 2
    if "--self-test" in flags:
        return self_test()
    repo = os.path.abspath(opts.get("repo", "."))
    thr = thresholds(repo)
    threshold = float(opts.get("threshold", thr["max_regression_pct"]))
    min_runs = max(HARD_FLOOR, int(float(opts.get("min-runs", thr["min_runs_per_side"]))))
    lower = "--higher-is-better" not in flags
    order, inter = None, True
    try:
        if "base-cmd" in opts or "head-cmd" in opts:
            if not ("base-cmd" in opts and "head-cmd" in opts):
                print("perf-compare: --base-cmd and --head-cmd go together", file=sys.stderr)
                return 2
            runs = int(opts.get("runs", min_runs))
            base, head, order = interleaved(opts["base-cmd"], opts["head-cmd"], os.path.abspath(opts.get("base-dir", repo)),
                                            os.path.abspath(opts.get("head-dir", repo)), runs, int(opts.get("warmup", "1")),
                                            "--wall" in flags, opts.get("bench"), float(opts.get("timeout", "600")))
        elif "pairs" in opts:
            d = json.load(open(opts["pairs"], encoding="utf-8"))
            base, head, inter = [float(x) for x in d["base"]], [float(x) for x in d["head"]], bool(d.get("interleaved"))
        elif "base" in opts and "head" in opts:
            base = parse_values(open(opts["base"], encoding="utf-8").read(), opts.get("bench"))
            head = parse_values(open(opts["head"], encoding="utf-8").read(), opts.get("bench"))
            inter = "--not-interleaved-ok" in flags
        else:
            print("perf-compare: give --base-cmd/--head-cmd, --pairs, or --base/--head", file=sys.stderr)
            return 2
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.TimeoutExpired) as e:
        print("perf-compare: %s" % e, file=sys.stderr)
        return 3
    res = compare(base, head, threshold, min_runs, lower, inter)
    if "--not-interleaved-ok" in flags and "base" in opts:
        res["caveat"] = "base and head were measured separately (not interleaved): machine drift is not controlled"
    res["base"], res["head"] = base, head
    if opts.get("save"):
        json.dump({"schema": "refract/perf-pairs/v1", "base": base, "head": head, "order": order, "interleaved": inter},
                  open(opts["save"], "w"), indent=1)
    if "--json" in flags:
        print(json.dumps(res, indent=2))
    else:
        print("perf-compare — %s: %s" % (res["verdict"], res["why"]))
        if "median_base" in res:
            print("  base median %.6g · head median %.6g · n %d/%d · noise band %.1f%% · %s p=%.4g"
                  % (res["median_base"], res["median_head"], res["n_base"], res["n_head"], res["noise_band_pct"], res["test"], res["p_value"]))
    return 1 if res["verdict"] == "REGRESSION" else 3 if res["verdict"] in REFUSED else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
