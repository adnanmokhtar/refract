#!/usr/bin/env python3
"""burn-check.py — slo-rule-scan §2: the burn-rate arithmetic, per alert, per tier (THR-OBS-BURN).

The rule is a formula, never a literal: factor = budget_fraction × period / long_window, and the short
window is the long one ÷ 12 (or the accepted set's own short window). A Workbook 14.4, a Pyrra 14, a
sloth 3× ticket and a 28d 13.44 all pass or fail by the same arithmetic (precedents/observability.md § 12).

The rule side is NOT re-parsed here: rule files go through alert-rule-lint's rule-inventory.py (imported
from ../../alert-rule-lint/scripts/, or --rule-inventory=PATH), so plain files, PrometheusRule CRDs and
Helm-embedded groups read the same way in both skills. SLO specs (sloth, Pyrra, OpenSLO) are read with
its YAML-subset loader. Stdlib only, read-only.

Usage:  burn-check.py <rule-file-or-dir> [...] [--spec=<sloth|pyrra|openslo file or dir>]...
                      [--objective=99.9] [--period=30d] [--slo='<alert-name regex>=<objective>[/<period>]']...
                      [--registry=ai/runtime/slos.md] [--retention=15d] [--format=text|json] [--all]
                      [--rule-inventory=PATH]
        burn-check.py --self-test   (Workbook 3-tier; Workbook 4-tier as sloth 0.16.0 emits it; Pyrra 14/7/2/1 on
                                     28d and on 30d with pyrra 0.10.2's minute-rounded windows; 10 negatives;
                                     --registry: a copied objective, two rows on one file, an untied alert,
                                     a hand-written registry that names its alerts)
Exit:   0 no problem · 1 at least one H/M/L row (`note` never sets it) · 2 usage, parse or import error

--registry reads the objective and period of a hand-written burn rule from the SLO registry: any table with
a name column (slo / name / id) and an objective column (target / objective; the period from a window or
period column, else the objective header's "(30 days)"). An alert is tied to a row that names it in an
`alerts` cell (rows naming one alert must agree), else by its `slo` label, else when its file is in the
row's `rules` cell and its name shares the most slo-name words with that row, else when every word of the
slo name is in the alert name. A tie lends an objective only to a `> factor * budget` comparison, never to
a plain threshold. A spec, sloth metadata and --slo win over the registry; the source prints as
`registry <file>:<line> (<slo>)`.

Codes (slo-rule-scan §): SLO-01 (§1) · SLO-02 single window / short ≠ long÷12, SLO-03 factor or objective
(§2) · SLO-04 impossible or unfireable objective (§3) · SLO-10 period > retention (§6). A row is a
candidate for the read step, never a finding by itself.
"""
import importlib.util, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DAY, HOUR, MIN = 86400, 3600, 60
# THR-OBS-BURN accepted sets. Each tier: (factor at the reference period, long, short, tier, scales).
# The budget fraction a tier spends before it fires is factor × long / reference period; a Workbook
# tier keeps its windows on any period (so its factor moves), a Pyrra tier scales its windows with
# period / 28d (so its factor stays). Both are checked through the same formula.
SETS = {
    "workbook": (30 * DAY, False, [(14.4, HOUR, 5 * MIN, "page"), (6, 6 * HOUR, 30 * MIN, "page"),
                                   (3, DAY, 2 * HOUR, "ticket"), (1, 3 * DAY, 6 * HOUR, "ticket")]),
    "pyrra": (28 * DAY, True, [(14, HOUR, 5 * MIN, "critical"), (7, 6 * HOUR, 30 * MIN, "critical"),
                               (2, DAY, 2 * HOUR, "warning"), (1, 4 * DAY, 6 * HOUR, "warning")]),
}
NUM = r"(\d+(?:\.\d+)?(?:e-?\d+)?|\.\d+)"
CMP = re.compile(r">=?\s*\(?\s*" + NUM + r"\s*\*\s*\(?\s*(?:1(?:\.0+)?\s*-\s*" + NUM + r"|" + NUM + r")\s*\)?\s*\)?"
                 r"|>=?\s*" + NUM + r"(?![\w.*])")
SUFFIX = re.compile(r"(?:rate|burnrate|avg|increase|ratio|window|_)((?:\d+[wdhms])+)$")


def die(msg):
    print(f"burn-check: {msg}", file=sys.stderr)
    sys.exit(2)


def load_ri(path=None):
    p = path or os.path.join(HERE, "..", "..", "alert-rule-lint", "scripts", "rule-inventory.py")
    if not os.path.isfile(p):
        die(f"blocked (rule-inventory.py not found at {p}; install alert-rule-lint or pass --rule-inventory=)")
    sys.dont_write_bytecode = True  # read-only: never leave a __pycache__ beside an installed skill
    spec = importlib.util.spec_from_file_location("rule_inventory", p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def dur(s):
    out, s = "", int(round(s))
    for u, n in (("d", DAY), ("h", HOUR), ("m", MIN), ("s", 1)):
        if s >= n:
            out += f"{s // n}{u}"
            s %= n
    return out or "0s"


def frac(v, percent):
    """An objective as a fraction: sloth/pyrra write percent, OpenSLO `target` a fraction."""
    try:
        x = float(str(v).strip().strip("%"))
    except ValueError:
        return None
    return x / 100 if percent else x


# ---------------------------------------------------------------- SLO specs --------------------
def read_specs(ri, paths):
    files, slos = [], []
    for p in paths:
        if os.path.isdir(p):
            for dp, dn, fn in os.walk(p):
                dn[:] = [d for d in dn if d not in ("node_modules", ".git", "vendor")]
                files += [os.path.join(dp, f) for f in fn if f.endswith((".yml", ".yaml"))]
        else:
            files.append(p)
    for f in sorted(files):
        for d in ri.load(open(f, encoding="utf-8", errors="replace").read()):
            if not isinstance(d, dict):
                continue
            kind, spec = str(d.get("kind", "")), d.get("spec") if isinstance(d.get("spec"), dict) else {}
            md = d.get("metadata") if isinstance(d.get("metadata"), dict) else {}
            if isinstance(d.get("slos"), list) or (kind == "PrometheusServiceLevel" and isinstance(spec.get("slos"), list)):
                body = d if isinstance(d.get("slos"), list) else spec  # sloth: plain spec or the CRD
                for s in body["slos"]:
                    if not isinstance(s, dict):
                        continue
                    al = s.get("alerting") if isinstance(s.get("alerting"), dict) else {}
                    off = [bool((al.get(k) or {}).get("disable")) if isinstance(al.get(k), dict) else False
                           for k in ("page_alert", "ticket_alert")]
                    slos.append({"gen": "sloth", "file": f, "line": s.get("__line__"), "name": str(s.get("name")),
                                 "service": str(body.get("service", "")), "objective": frac(s.get("objective"), True),
                                 "period": ri.secs(body.get("slo_period") or s.get("slo_period") or "30d"),
                                 "period_src": "spec" if (body.get("slo_period") or s.get("slo_period")) else "sloth default 30d (--default-slo-period overrides)",
                                 "alert_name": str(al.get("name", "")), "alerting": not all(off) and bool(al)})
            elif kind == "ServiceLevelObjective" and "target" in spec:  # Pyrra
                al = spec.get("alerting") if isinstance(spec.get("alerting"), dict) else {}
                slos.append({"gen": "pyrra", "file": f, "line": d.get("__line__"), "name": str(md.get("name")),
                             "objective": frac(spec.get("target"), True), "period": ri.secs(spec.get("window")),
                             "period_src": "spec", "alert_name": str(al.get("name", "ErrorBudgetBurn")),
                             "alerting": str(al.get("disabled", "false")).lower() != "true"})
            elif kind == "SLO" and isinstance(spec.get("objectives"), list):  # OpenSLO v1 / v1alpha
                tw = (spec.get("timeWindow") or spec.get("timeWindows") or [{}])[0]
                per = ri.secs(tw.get("duration")) if isinstance(tw, dict) and tw.get("duration") else None
                if per is None and isinstance(tw, dict) and tw.get("count"):
                    per = int(tw["count"]) * {"day": DAY, "week": 7 * DAY, "hour": HOUR}.get(str(tw.get("unit", "")).lower(), DAY)
                for o in spec["objectives"]:
                    if isinstance(o, dict):
                        ob = frac(o["targetPercent"], True) if "targetPercent" in o else frac(o.get("target"), False)
                        slos.append({"gen": "openslo", "file": f, "line": o.get("__line__"), "name": str(md.get("name")),
                                     "objective": ob, "period": per, "period_src": "spec", "alert_name": "",
                                     "alerting": bool(spec.get("alertPolicies"))})
    return slos


# ---------------------------------------------------------------- the SLO registry -------------
def words(s):
    """Lower-case words of an slo name or a CamelCase / snake / kebab alert name."""
    return set(w.lower() for w in re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])|\d+", str(s)))


def read_registry(ri, path):
    """Rows of every registry table with a name column (`slo` / `name` / `id`) and an objective column
    (`target` / `objective…`): slo-audit's `| slo | sli | target | window | … | rules |`, or a hand-written
    `| id | SLI | objective (30 days) | budget | alerts |`. The period comes from a `window` / `period`
    column, else from the objective header's `(30 days)`; `rules` names files, `alerts` names alerts."""
    if not os.path.isfile(path):
        die(f"registry not found: {path}")
    rows, cols, hdr_per = [], None, None
    for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
        if not line.lstrip().startswith("|"):
            cols = None  # a table ends at the first line that is not a row
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cols is None:
            low = [re.sub(r"[^a-z]", "", re.sub(r"\(.*?\)", "", c.lower())) for c in cells]
            key = {"slo": "name", "name": "name", "id": "name", "target": "objective", "objective": "objective",
                   "window": "period", "period": "period", "rules": "rules", "alerts": "alerts", "alert": "alerts"}
            cand = {}
            for i, c in enumerate(low):
                if key.get(c) and key[c] not in cand:
                    cand[key[c]] = i
            if "name" in cand and "objective" in cand:
                cols = cand
                m = re.search(r"\((\d+)\s*(day|d|week|w|hour|h)s?\b", cells[cand["objective"]].lower())
                hdr_per = int(m.group(1)) * {"day": DAY, "d": DAY, "week": 7 * DAY, "w": 7 * DAY, "hour": HOUR, "h": HOUR}[m.group(2)] if m else None
            continue
        if all(re.fullmatch(r":?-+:?", c) for c in cells if c):
            continue
        get = lambda k: cells[cols[k]] if k in cols and cols[k] < len(cells) else ""
        name, ob = get("name").strip("`"), frac(get("objective").replace(" ", ""), True)
        if not name or ob is None:
            continue
        per = (ri.secs(get("period").replace(" ", "")) if get("period") else hdr_per) or None
        files = [os.path.normpath(f.strip("`")) for f in re.split(r"[,\s]+", get("rules")) if f.strip("`") not in ("", "—", "-")]
        alerts = re.findall(r"`([A-Za-z_:][\w:]*)`", get("alerts")) or \
            [a for a in re.split(r"[,\s]+", get("alerts")) if re.fullmatch(r"[A-Z][\w:]*", a)]
        rows.append({"name": name, "objective": ob, "period": per, "files": files, "alerts": alerts, "line": n, "file": path})
    return rows


def registry_row(reg, alert, lab):
    """The registry row a hand-written alert implements, or None (ambiguous ties tie to nothing)."""
    named = [r for r in reg if alert["name"] in r.get("alerts", [])]
    if named:  # the row names the alert; two rows that agree on objective and period are one answer
        return named[0] if len({(r["objective"], r["period"]) for r in named}) == 1 else None
    if lab.get("slo"):
        hit = [r for r in reg if r["name"] == lab["slo"]]
        if len(hit) == 1:
            return hit[0]
    f = os.path.normpath(alert["file"])
    aw = words(alert["name"])
    on_file = [r for r in reg if any(f == x or f.startswith(x.rstrip("/") + os.sep) for x in r["files"])]
    if on_file:
        score = sorted(((len(words(r["name"]) & aw), i) for i, r in enumerate(on_file)), reverse=True)
        if len(on_file) == 1 or (score[0][0] > 0 and (len(score) == 1 or score[0][0] > score[1][0])):
            return on_file[score[0][1]]
        return None
    full = [r for r in reg if words(r["name"]) and words(r["name"]) <= aw]
    return full[0] if len(full) == 1 else None


# ---------------------------------------------------------------- burn clauses -----------------
def split_top(e, word):
    parts, depth, last = [], 0, 0
    for m in re.finditer(r"[()]|\b" + word + r"\b", e):
        t = m.group(0)
        if t == "(":
            depth += 1
        elif t == ")":
            depth -= 1
        elif depth == 0:
            parts.append(e[last:m.start()])
            last = m.end()
    parts.append(e[last:])
    return [p.strip() for p in parts if p.strip()]


def unwrap(e):
    e = e.strip()
    while e.startswith("(") and e.endswith(")"):
        d = 0
        for i, ch in enumerate(e):
            d += (ch == "(") - (ch == ")")
            if d == 0 and i < len(e) - 1:
                return e
        e = e[1:-1].strip()
    return e


def clauses(expr):
    e = re.sub(r"#[^\n]*", "", expr)
    ors = split_top(unwrap(e), "or")
    if len(ors) == 1:
        return [split_top(unwrap(ors[0]), "and")]
    return [split_top(unwrap(o), "and") for o in ors]


def window(ri, conj, records):
    """The window a burn comparison reads: a range literal, else its recording rule's range, else a name suffix."""
    tk = ri.tokens(conj)
    w = set(ri.secs(a) for a, _ in tk["ranges"])
    if len(w) == 1:
        return w.pop(), "range"
    for m in tk["metrics"]:
        rw = set(ri.secs(a) for r in records.get(m, []) for a, _ in r["_tk"]["ranges"])
        if len(rw) == 1:
            return rw.pop(), f"recording rule {m}"
        s = SUFFIX.search(m)
        if s:
            return ri.secs(s.group(1)), f"name suffix {m}"
    return None, "unread"


def comparisons(ri, conj, records, plain_ok):
    """One burn comparison: `> factor * (1 - objective)`, `> factor * budget`, or — only for an alert tied
    to an SLO (spec, sloth labels, --slo) — a plain `> threshold`. Any other comparison is not a burn rule."""
    m = next((x for x in CMP.finditer(conj) if x.group(4) is None or plain_ok), None)
    if not m:
        return None
    a, one_minus, b, plain = m.group(1), m.group(2), m.group(3), m.group(4)
    if one_minus is None and plain is None and min(float(a), float(b)) >= 0.5:
        return None  # two numbers, neither an error budget: an ordinary threshold, not a burn rule
    if plain is not None:
        f, budget, form = None, None, f"> {plain}"
        thr = float(plain)
    else:
        x, y = float(a), float(one_minus if one_minus is not None else b)
        budget = 1 - y if one_minus is not None else y
        f = x
        if one_minus is None and x < y:  # written budget * factor
            f, budget = y, x
        form, thr = m.group(0).lstrip(">= ").strip(), f * budget
    w, src = window(ri, conj[:m.start()], records)
    return {"window": w, "window_src": src, "factor": f, "budget": budget, "threshold": thr, "form": form}


# ---------------------------------------------------------------- checks -----------------------
def tier_match(W, P):
    """Accepted tiers whose long window equals W on period P (Pyrra windows scaled, rounded to a minute)."""
    out = []
    for name, (pref, scales, tiers) in SETS.items():
        k = P / pref if scales else 1
        for f0, L, S, sev in tiers:
            Le, Se = L * k, S * k
            if abs(W - Le) <= max(MIN, 0.02 * Le):
                out.append({"set": name, "budget_fraction": f0 * L / pref, "long": Le, "short": Se, "tier": sev})
    return out


def expected_factor(b, P, W):
    """THR-OBS-BURN: the factor that spends budget fraction b of period P within long window W."""
    return b * P / W


def check_clause(c, o, P, add):
    """c: burn comparisons of one `or` branch. o: objective fraction (None = unread). P: period seconds."""
    if len(c) == 1:
        add("SLO-02", "M", 2, f"single-window burn ({dur(c[0]['window'] or 0)}): no short window ANDed — resets slowly after the burn stops")
    ws = [x for x in c if x["window"]]
    if not ws:
        add("SLO-02", "note", 2, "burn comparison with no readable window (range, recording rule or name suffix): read it")
        return
    lg = max(ws, key=lambda x: x["window"])
    sh = min(ws, key=lambda x: x["window"]) if len(ws) > 1 else None
    f, b = lg["factor"], lg["budget"]
    if b is None and o is not None:
        b, f = 1 - o, lg["threshold"] / (1 - o)
    if f is None:
        add("SLO-03", "note", 2, f"threshold {lg['form']} with no objective: pass --objective or --slo to derive the factor")
        return
    if sh and sh["factor"] is not None and abs(sh["factor"] - f) > 1e-9:
        add("SLO-03", "M", 2, f"long and short windows compare to different factors ({f:g} vs {sh['factor']:g})")
    if o is not None and b is not None and abs(b - (1 - o)) > 0.01 * (1 - o):
        add("SLO-03", "H", 2, f"threshold budget {b:g} is not 1 − objective ({1 - o:.6g}): the rule is for another objective "
            f"and fires at {b / (1 - o):.3g}× the intended burn")
    ob = 1 - b if b is not None else o
    if ob is not None and b is not None and f * b >= 1:
        add("SLO-04", "H", 3, f"factor {f:g} × budget {b:g} = {f * b:.3g} ≥ 1: an error ratio cannot exceed it, so this tier never fires (objective {ob:.4%})")
    W = lg["window"]
    if P is None:
        add("SLO-03", "note", 2, f"period unread: factor {f:g} on {dur(W)} spends {f * W / (30 * DAY):.2%} of a 30d budget, "
            f"{f * W / (28 * DAY):.2%} of a 28d one — pass --period or a spec")
        return
    spent = f * W / P
    tiers = tier_match(W, P)
    if sh:
        S = sh["window"]
        okS = [t for t in tiers if abs(S - t["short"]) <= max(MIN, 0.1 * t["short"])] or \
            ([{"short": W / 12}] if abs(S - W / 12) <= max(MIN, 0.1 * W / 12) else [])
        if not okS:
            want = " or ".join(sorted(set(dur(t["short"]) for t in tiers))) or dur(W / 12)
            add("SLO-02", "M", 2, f"short window {dur(S)} for long {dur(W)}: expected {want} (long ÷ 12 or the set's own)")
    if not tiers:
        add("SLO-03", "L", 2, f"custom tier {dur(W)}: factor {f:g} spends {spent:.2%} of the {dur(P)} budget before firing — "
            "no THR-OBS-BURN set has this window; read for an ADR")
        return
    best = min(tiers, key=lambda t: abs(f / expected_factor(t["budget_fraction"], P, W) - 1))
    fe = expected_factor(best["budget_fraction"], P, W)
    r = f / fe
    msg = (f"factor {f:g} on {dur(W)}/{dur(P)} spends {spent:.2%} of the budget; the {best['set']} {best['tier']} tier "
           f"spends {best['budget_fraction']:.2%} → expected {fe:.4g}")
    if abs(r - 1) <= 0.01:
        add("OK", "ok", 2, msg)
    elif abs(r - 1) <= 0.10:
        add("SLO-03", "note", 2, msg + " (within 10 %: precedents § 12, a note)")
    else:
        add("SLO-03", "H" if (r > 2 or r < 0.5) else "M", 2, msg + f" ({r:.2f}× — fires {'later' if r > 1 else 'earlier'} than the tier intends)")


def run_check(ri, rule_paths, specs, o):
    rows = ri.read_rules(rule_paths) if rule_paths else []
    records, meta = {}, {}
    for r in rows:
        if r.get("kind") == "record":
            records.setdefault(r["name"], []).append(r)
            v = re.fullmatch(r"\s*vector\(\s*" + NUM + r"\s*\)\s*", r["expr"])
            sid = {**r.get("group_labels", {}), **r.get("labels", {})}.get("sloth_id", "")
            if v and r["name"] in ("slo:objective:ratio", "slo:time_period:days"):
                meta.setdefault(sid, {})[r["name"]] = float(v.group(1))
    out = []
    for s in specs:
        pr = []
        add = lambda code, sev, sect, msg: pr.append({"code": code, "severity": sev, "section": sect, "message": msg})
        ob, P = s["objective"], s["period"]
        if ob is not None and ob >= 1:
            add("SLO-04", "H", 3, "objective 100 %: no error budget, every failure is an incident and no burn rate exists (precedents § 14)")
        elif ob is not None and P and s["alerting"] and (1 - ob) * P < 5 * MIN:
            add("SLO-04", "M", 3, f"objective {ob:.4%} over {dur(P)}: a full outage spends the whole budget in {dur((1 - ob) * P)}, "
                "before the fastest 5m short window can page (precedents § 14)")
        fast = SETS["pyrra" if s["gen"] == "pyrra" else "workbook"][2][0][0]  # the generator's fast page factor
        if ob is not None and ob < 1 and s["alerting"] and fast * (1 - ob) >= 1:
            add("SLO-04", "M", 3, f"objective {ob:.4%}: the fast page needs an error ratio of {fast:g} × {1 - ob:.3g} = {fast * (1 - ob):.3g} > 1, "
                "so it never fires; only slower tiers can (ticket-only by design is Hardening)")
        if not s["alerting"]:
            add("SLO-01", "M", 1, f"{s['gen']} SLO with alerting disabled or no alertPolicies: no burn alert is generated — "
                "find a hand-written burn rule for it or report SLO-01")
        if o["retention"] and P and P > o["retention"]:
            add("SLO-10", "M", 6, f"period {dur(P)} > TSDB retention {dur(o['retention'])}: the budget is computed over partial data unless a long-term store reads it")
        out.append({"file": s["file"], "line": s["line"], "kind": f"slo/{s['gen']}", "name": s["name"],
                    "objective": ob, "period": P, "period_src": s["period_src"], "problems": pr})
    for r in rows:
        if r.get("kind") != "alert":
            continue
        lab = {**r.get("group_labels", {}), **r.get("labels", {})}
        sp = next((s for s in specs if (s["gen"] == "sloth" and lab.get("sloth_slo") == s["name"])
                   or (s["gen"] == "pyrra" and (lab.get("slo") == s["name"] or f'slo="{s["name"]}"' in r["expr"]))
                   or (s["alert_name"] and s["alert_name"] == r["name"] and s["gen"] == "sloth")), None)
        ob, P, src = None, None, "unread"
        cli = next((v for rx, v in o["slo"] if re.fullmatch(rx, r["name"])), None)
        reg = registry_row(o["registry"], r, lab) if o["registry"] else None
        # A registry row lends its objective only to a burn comparison (`> factor * budget`): it often names
        # every alert an SLO owns, so a plain `> 10` depth or lag threshold beside them is no burn rule.
        tied = bool(sp or cli or lab.get("sloth_id") in meta)
        cl = [[c for c in (comparisons(ri, conj, records, tied) for conj in cj) if c] for cj in clauses(r["expr"])]
        cl = [c for c in cl if c]
        if not cl:
            continue
        if sp:
            ob, P, src = sp["objective"], sp["period"], f"spec {sp['file']}:{sp['line']} ({sp['period_src']})"
        elif cli:
            ob, P, src = cli[0], cli[1] or o["period"], "--slo"
        elif lab.get("sloth_id") in meta:
            m = meta[lab["sloth_id"]]
            ob, P = m.get("slo:objective:ratio"), m.get("slo:time_period:days") and m["slo:time_period:days"] * DAY
            src = "sloth metadata recording rules"
        elif reg:
            ob, P, src = reg["objective"], reg["period"], f"registry {reg['file']}:{reg['line']} ({reg['name']})"
        if P is None and o["period"]:
            P, src = o["period"], "--period"
        if ob is None and o["objective"] is not None:
            ob = o["objective"]
        if P is None and lab.get("exhaustion") and cl[0][0]["factor"]:
            P, src = ri.secs(lab["exhaustion"]) * cl[0][0]["factor"], "pyrra exhaustion label × factor (pyrra 0.10.2)"
        pr = []
        for c in cl:
            def add(code, sev, sect, msg, c=c):
                pr.append({"code": code, "severity": sev, "section": sect, "message": msg,
                           "tier": "/".join(dur(w) for w in sorted((x["window"] for x in c if x["window"]), reverse=True))})
            check_clause(c, ob, P, add)
        out.append({"file": r["file"], "line": r["line"], "kind": "alert", "name": r["name"], "objective": ob,
                    "period": P, "period_src": src, "tiers": len(cl), "problems": pr})
    return out


def opts(argv, ri):
    o = {"paths": [], "specs": [], "objective": None, "period": None, "slo": [], "retention": None,
         "format": "text", "all": False, "registry": [], "registry_path": None}
    for a in argv:
        k, _, v = a.partition("=")
        if k == "--spec": o["specs"].append(v)
        elif k == "--objective": o["objective"] = frac(v, True)
        elif k == "--period": o["period"] = ri.secs(v)
        elif k == "--retention": o["retention"] = ri.secs(v)
        elif k == "--registry": o["registry_path"], o["registry"] = v, read_registry(ri, v)
        elif k == "--slo":
            rx, _, val = v.rpartition("=")
            ob, _, per = val.partition("/")
            o["slo"].append((rx, (frac(ob, True), ri.secs(per) if per else None)))
        elif k == "--format": o["format"] = v
        elif k == "--all": o["all"] = True
        elif k == "--rule-inventory": pass
        elif a.startswith("--"): die(f"unknown flag {a}")
        else: o["paths"].append(a)
    return o


def main(argv):
    rip = next((a.partition("=")[2] for a in argv if a.startswith("--rule-inventory=")), None)
    ri = load_ri(rip)
    o = opts(argv, ri)
    if not o["paths"] and not o["specs"]:
        print(__doc__, file=sys.stderr)
        return 2
    out = run_check(ri, o["paths"], read_specs(ri, o["specs"]), o)
    bad = 0
    for r in out:
        bad += sum(p["severity"] in ("H", "M", "L") for p in r["problems"])
        if o["format"] == "json":
            print(json.dumps(r, sort_keys=True))
            continue
        for p in r["problems"]:
            if p["severity"] in ("H", "M", "L") or o["all"]:
                t = f" [{p['tier']}]" if p.get("tier") else ""
                print(f"{r['file']}:{r['line']}  {r['kind']} {r['name']}{t}  §{p['section']} {p['code']} [{p['severity']}]  {p['message']}  (objective/period: {r['period_src']})")
    reg = "" if not o["registry_path"] else (f", registry {o['registry_path']}: {len(o['registry'])} rows, "
                                            f"{sum(str(r['period_src']).startswith('registry ') for r in out)} alerts tied")
    print(f"burn-check: {sum(r['kind'] == 'alert' for r in out)} burn alerts, {sum(r['kind'] != 'alert' for r in out)} SLO specs{reg}, "
          f"{bad} problems (H/M/L){'' if o['all'] else ' — --all shows ok rows and notes'}", file=sys.stderr)
    return 1 if bad else 0


# ---------------------------------------------------------------- self-test --------------------
def _burn(name, long_, short_, f, o, labels="{severity: page}"):
    return (f"  - alert: {name}\n    expr: sum(rate(e_total[{long_}])) / sum(rate(t_total[{long_}])) > ({f} * (1-{o}))"
            f" and sum(rate(e_total[{short_}])) / sum(rate(t_total[{short_}])) > ({f} * (1-{o}))\n    labels: {labels}\n")


def self_test():
    import tempfile
    ri = load_ri(next((a.partition("=")[2] for a in sys.argv if a.startswith("--rule-inventory=")), None))
    d = tempfile.mkdtemp(prefix="burn-check-")
    W = lambda *t: "groups:\n- name: g\n  rules:\n" + "".join(t)
    files = {
        # Workbook 3-tier, 30d, 99.9 — the three tiers as three alerts.
        "wb3.yml": W(_burn("Wb3Fast", "1h", "5m", 14.4, 0.999), _burn("Wb3Slow", "6h", "30m", 6, 0.999),
                     _burn("Wb3Ticket", "3d", "6h", 1, 0.999, "{severity: ticket}")),
        # Workbook 4-tier as sloth emits it: recording rules named by window, `or` of two tiers per alert,
        # objective and period from sloth's metadata recordings.
        "sloth.yml": "groups:\n- name: sloth-slo-sli-recordings-api\n  rules:\n" + "".join(
            f"  - record: slo:sli_error:ratio_rate{w}\n    expr: sum(rate(e_total[{w}])) / sum(rate(t_total[{w}]))\n"
            f"    labels: {{sloth_id: api-avail, sloth_slo: avail, sloth_window: {w}}}\n" for w in ("5m", "30m", "1h", "2h", "6h", "1d", "3d"))
        + "- name: sloth-slo-meta-recordings-api\n  rules:\n  - record: slo:objective:ratio\n    expr: vector(0.9990000000000001)\n"
          "    labels: {sloth_id: api-avail}\n  - record: slo:time_period:days\n    expr: vector(30)\n    labels: {sloth_id: api-avail}\n"
          "- name: sloth-slo-alerts-api\n  rules:\n"
          "  - alert: ApiAvailBudgetBurn\n    expr: |\n      (\n        max(slo:sli_error:ratio_rate5m{sloth_id=\"api-avail\"} > (14.4 * 0.0009999999999999432)) without (sloth_window)\n"
          "        and\n        max(slo:sli_error:ratio_rate1h{sloth_id=\"api-avail\"} > (14.4 * 0.0009999999999999432)) without (sloth_window)\n      )\n"
          "      or\n      (\n        max(slo:sli_error:ratio_rate30m{sloth_id=\"api-avail\"} > (6 * 0.0009999999999999432)) without (sloth_window)\n"
          "        and\n        max(slo:sli_error:ratio_rate6h{sloth_id=\"api-avail\"} > (6 * 0.0009999999999999432)) without (sloth_window)\n      )\n"
          "    labels: {sloth_id: api-avail, sloth_slo: avail, sloth_severity: page}\n"
          "  - alert: ApiAvailBudgetBurnTicket\n    expr: |\n"
          "      (max(slo:sli_error:ratio_rate2h{sloth_id=\"api-avail\"} > (3 * 0.0009999999999999432)) without (sloth_window)\n"
          "       and max(slo:sli_error:ratio_rate1d{sloth_id=\"api-avail\"} > (3 * 0.0009999999999999432)) without (sloth_window))\n"
          "      or\n      (max(slo:sli_error:ratio_rate6h{sloth_id=\"api-avail\"} > (1 * 0.0009999999999999432)) without (sloth_window)\n"
          "       and max(slo:sli_error:ratio_rate3d{sloth_id=\"api-avail\"} > (1 * 0.0009999999999999432)) without (sloth_window))\n"
          "    labels: {sloth_id: api-avail, sloth_slo: avail, sloth_severity: ticket}\n",
        # Pyrra 14/7/2/1 on 28d (recording-rule names, as pyrra emits them) and on 30d (windows scaled, rounded).
        "pyrra.yml": "groups:\n- name: checkout\n  rules:\n" + "".join(
            f"  - record: http:burnrate{w}\n    expr: sum(rate(e_total{{job=\"co\"}}[{w}])) / sum(rate(t_total{{job=\"co\"}}[{w}]))\n    labels: {{slo: checkout}}\n"
            for w in ("5m", "30m", "1h", "2h", "6h", "1d", "4d"))
        + "".join(f"  - alert: ErrorBudgetBurn\n    expr: http:burnrate{s}{{slo=\"checkout\"}} > ({f} * (1-0.99)) and http:burnrate{l}{{slo=\"checkout\"}} > ({f} * (1-0.99))\n"
                  f"    for: 2m\n    labels: {{severity: critical, slo: checkout, exhaustion: {e}}}\n"
                  for f, l, s, e in ((14, "1h", "5m", "2d"), (7, "6h", "30m", "4d"), (2, "1d", "2h", "2w"), (1, "4d", "6h", "4w"))),
        "pyrra30.yml": W(*(_burn(f"Pyrra30x{f}", l, s, f, 0.995, "{severity: critical, slo: search}")
                           for f, l, s in ((14, "1h4m", "5m", ), (7, "6h26m", "32m"), (2, "1d1h43m", "2h9m"), (1, "4d6h51m", "6h26m")))),
        # Negatives and notes.
        "bad.yml": W(_burn("Hand14On30d", "1h", "5m", 14, 0.999),             # 1.94 % vs 2 %: § 12 note
                     _burn("Wb14p4On28d", "1h", "5m", 14.4, 0.999),          # 13.44 expected: § 12 note
                     _burn("WrongObjective", "1h", "5m", 14.4, 0.99),        # spec says 99.9: SLO-03 H
                     _burn("ThirtyDayOn7d", "1h", "5m", 14.4, 0.999),        # 7d period: expected 3.36, SLO-03 H
                     _burn("ShortTooLong", "1h", "30m", 14.4, 0.999),        # short ≠ long ÷ 12: SLO-02 M
                     _burn("NinetyPct", "1h", "5m", 14.4, 0.9),              # 14.4 × 0.1 ≥ 1: SLO-04 H
                     "  - alert: SingleWindow\n    expr: sum(rate(e_total[1h])) / sum(rate(t_total[1h])) > (14.4 * 0.001)\n"),
        "specs.yaml": "version: prometheus/v1\nservice: api\nslos:\n  - name: perfect\n    objective: 100\n    sli: {events: {error_query: x, total_query: y}}\n"
                      "    alerting: {name: P}\n  - name: fiveninesish\n    objective: 99.999\n    sli: {events: {error_query: x, total_query: y}}\n"
                      "    alerting: {name: F}\n  - name: lax\n    objective: 90\n    sli: {events: {error_query: x, total_query: y}}\n"
                      "    alerting: {name: L}\n  - name: silent\n    objective: 99.9\n    sli: {events: {error_query: x, total_query: y}}\n"
                      "    alerting:\n      name: S\n      page_alert:\n        disable: true\n      ticket_alert:\n        disable: true\n"
                      "---\napiVersion: pyrra.dev/v1alpha1\nkind: ServiceLevelObjective\nmetadata:\n  name: checkout\nspec:\n  target: \"99\"\n  window: 28d\n"
                      "---\napiVersion: openslo/v1\nkind: SLO\nmetadata:\n  name: login\nspec:\n  budgetingMethod: Occurrences\n"
                      "  timeWindow:\n    - duration: 30d\n      isRolling: true\n  objectives:\n    - target: 0.995\n",
    }
    # The registry (--registry): a burn rule copied from another SLO is caught on the first pass; two rows on
    # one file are told apart by the alert's name; an alert in a file no row names, whose name does not hold
    # every word of an slo name, stays untied (a note, never a borrowed objective).
    files["reg.yml"] = W(_burn("PaymentsCaptureFastBurn", "1h", "5m", 14.4, 0.99),   # registry 99.9: SLO-03 H
                         _burn("CheckoutLatencyFastBurn", "1h", "5m", 14.4, 0.99),   # registry 99 / 30d: ok
                         _burn("InventoryLatencyFastBurn", "1h", "5m", 14.4, 0.995))  # registry 99.5: ok only on its own row
    files["other.yml"] = W(_burn("OrphanLatencyBurn", "1h", "5m", 14.4, 0.99))       # no row names it: untied
    reg = os.path.join(d, "slos.md")
    open(reg, "w").write("# SLO registry\n\n| slo | sli | target | window | owner | origin | rules |\n|---|---|---|---|---|---|---|\n"
                         f"| payments-capture-availability | ok / all | 99.9 % | 30d | payments | contract | {os.path.join(d, 'reg.yml')} |\n"
                         f"| checkout-latency | < 250 ms / all | 99 % | 30d | checkout | terms | {os.path.join(d, 'reg.yml')} |\n"
                         f"| inventory-latency | < 200 ms / all | 99.5 % | 30d | inventory | ADR | `{os.path.join(d, 'reg.yml')}` |\n"
                         "| search-latency | < 400 ms / all | 99 % | 30d | catalog | measured | — |\n\nNot a row: | x | 1 |\n")
    for n, t in files.items():
        open(os.path.join(d, n), "w").write(t)
    o = opts([f"--registry={reg}", "--slo=Hand14On30d=99.9/30d", "--slo=Wb14p4On28d=99.9/28d", "--slo=WrongObjective=99.9/30d",
              "--slo=ThirtyDayOn7d=99.9/7d", "--slo=ShortTooLong=99.9/30d", "--slo=NinetyPct=90/30d",
              "--slo=SingleWindow=99.9/30d", "--slo=Wb3.*=99.9/30d", "--slo=Pyrra30x.*=99.5/30d", "--retention=15d"], ri)
    specs = read_specs(ri, [os.path.join(d, "specs.yaml")])
    out = run_check(ri, [os.path.join(d, f) for f in files if f != "specs.yaml"], specs, o)
    got = {}
    for r in out:
        for p in r["problems"]:
            got.setdefault(r["name"], set()).add((p["code"], p["severity"]))
    ok = True

    def expect(name, want, exact=False):
        nonlocal ok
        g = got.get(name, set())
        if not want <= g or (exact and g != want):
            ok = False
            print(f"self-test: {name} want {sorted(want)} got {sorted(g)}")

    # Controls: every accepted set passes on the arithmetic, never on a literal — Pyrra's 14 and the
    # 4-tier 3× fail a `factor == 14.4` test and must pass this one.
    for n in ("Wb3Fast", "Wb3Slow", "Wb3Ticket", "ApiAvailBudgetBurn", "ApiAvailBudgetBurnTicket", "ErrorBudgetBurn",
              "Pyrra30x14", "Pyrra30x7", "Pyrra30x2", "Pyrra30x1"):
        bad = {c for c in got.get(n, set()) if c[1] in ("H", "M", "L", "note")}
        if bad or ("OK", "ok") not in got.get(n, set()):
            ok = False
            print(f"self-test: control {n} got {sorted(got.get(n, set()))}")
    sl = [r for r in out if r["name"] == "ApiAvailBudgetBurn"][0]
    if sl["period"] != 30 * DAY or abs(sl["objective"] - 0.999) > 1e-9 or sl["tiers"] != 2:
        ok = False
        print(f"self-test: sloth metadata or `or` split: {sl['period']} {sl['objective']} {sl['tiers']}")
    # The arithmetic itself: factor = budget_fraction × period / long_window for every tier of every set.
    for name, (pref, scales, tiers) in SETS.items():
        for f0, L, _, _ in tiers:
            for P in (7 * DAY, 28 * DAY, 30 * DAY, 90 * DAY):
                Wl = L * (P / pref if scales else 1)
                fe = expected_factor(f0 * L / pref, P, Wl)
                if abs(fe - (f0 if scales else f0 * P / pref)) > 1e-9:
                    ok = False
                    print(f"self-test: arithmetic {name} {f0} on {dur(P)} gave {fe}")
    expect("Hand14On30d", {("SLO-03", "note")}, exact=True)
    expect("Wb14p4On28d", {("SLO-03", "note")}, exact=True)
    expect("WrongObjective", {("SLO-03", "H")})
    expect("ThirtyDayOn7d", {("SLO-03", "H")})
    expect("ShortTooLong", {("SLO-02", "M")})
    expect("NinetyPct", {("SLO-04", "H")})
    expect("SingleWindow", {("SLO-02", "M")})
    expect("perfect", {("SLO-04", "H"), ("SLO-10", "M")})
    expect("fiveninesish", {("SLO-04", "M")})
    expect("silent", {("SLO-01", "M")})
    expect("lax", {("SLO-04", "M")})
    expect("login", {("SLO-01", "M")})
    expect("checkout", {("SLO-10", "M")}, exact=True)
    expect("PaymentsCaptureFastBurn", {("SLO-03", "H")})
    for n in ("CheckoutLatencyFastBurn", "InventoryLatencyFastBurn"):
        expect(n, {("OK", "ok")}, exact=True)
    orphan = [r for r in out if r["name"] == "OrphanLatencyBurn"][0]
    if orphan["objective"] is not None or any(p["severity"] in ("H", "M", "L") for p in orphan["problems"]):
        ok = False
        print(f"self-test: registry tied an alert no row names: {orphan['period_src']} {orphan['problems']}")
    if len(o["registry"]) != 4 or [r for r in out if r["name"] == "PaymentsCaptureFastBurn"][0]["period"] != 30 * DAY:
        ok = False
        print(f"self-test: registry rows {len(o['registry'])}")
    # A hand-written registry: `| id | SLI | objective (30 days) | budget | alerts |`, the alerts named in the row,
    # the period in the objective header. Two rows naming one alert tie only when they agree.
    reg2 = os.path.join(d, "slos-hand.md")
    open(reg2, "w").write("| source | where |\n|---|---|\n| an audit | a laptop |\n\n"
                          "| id | SLI — good / valid | objective (30 days) | budget | alerts |\n|---|---|---|---|---|\n"
                          "| `slo:availability` | not 5xx / all | 99.9% | 0.001 | `HandAvailBurn` (page), `HandAvailTicket` (ticket) |\n"
                          "| `slo:latency-read` | <= 100 ms / all | 99% | 0.01 | `HandLatencyBurn` (page), label `class=\"read\"` |\n"
                          "| `slo:latency-write` | <= 300 ms / all | 99% | 0.01 | `HandLatencyBurn` (page), label `class=\"write\"` |\n"
                          "| `slo:fresh-a` | fresh / all | 99.5% | 0.005 | `HandSplitBurn` (page) |\n"
                          "| `slo:fresh-b` | fresh / all | 99.9% | 0.001 | `HandSplitBurn` (page) |\n")
    open(os.path.join(d, "hand.yml"), "w").write(W(_burn("HandAvailBurn", "1h", "5m", 14.4, 0.99),
                                                    _burn("HandLatencyBurn", "1h", "5m", 14.4, 0.99),
                                                    _burn("HandSplitBurn", "1h", "5m", 14.4, 0.995)))
    o2 = opts([f"--registry={reg2}"], ri)
    got2 = {r["name"]: r for r in run_check(ri, [os.path.join(d, "hand.yml")], [], o2)}
    sev = lambda n: {(p["code"], p["severity"]) for p in got2[n]["problems"]}
    if len(o2["registry"]) != 5 or o2["registry"][0]["period"] != 30 * DAY or o2["registry"][0]["alerts"] != ["HandAvailBurn", "HandAvailTicket"]:
        ok = False
        print(f"self-test: hand-written registry rows {o2['registry']}")
    if ("SLO-03", "H") not in sev("HandAvailBurn") or sev("HandLatencyBurn") != {("OK", "ok")} or got2["HandSplitBurn"]["objective"] is not None:
        ok = False
        print(f"self-test: hand-written registry ties {sev('HandAvailBurn')} {sev('HandLatencyBurn')} {got2['HandSplitBurn']['period_src']}")
    lg = [s for s in specs if s["name"] == "login"][0]
    if abs(lg["objective"] - 0.995) > 1e-9 or lg["period"] != 30 * DAY:
        ok = False
        print(f"self-test: OpenSLO objective/period {lg['objective']} {lg['period']}")
    print("self-test:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main(sys.argv[1:]))
