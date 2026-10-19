#!/usr/bin/env python3
"""bill-lane.py — read a cloud billing export (FOCUS 1.x CSV) and answer the finops questions from its rows.

House rule: a $ comes only from a bill row; list price is labelled. Every amount printed is a Decimal sum
of values read from ONE cost column of the export (default EffectiveCost). Nothing is estimated, no rate
card is consulted, and a missing cost column is an error — never a silent fall-back to another column.
With --cost list every money line carries "(list price — not a saving basis)". Output goes to stdout
only; the script never writes beside its input.

Usage (run isolated: python3 -I bill-lane.py ...):
  columns     <export.csv[.gz]>                 canonical column -> actual header, cost column, periods
  summary     <export> [--by service|sku|region|resource|subaccount|tag:<key>] [--top N]
  attribution <export> --required-keys team,env [--allowed team=a|b --allowed env=prod|staging]
              [--untaggable types.txt]           tagged + mis-tagged + untagged + untaggable = total
  split       <export> --base YYYY-MM --cur YYYY-MM [--by sku|service]
                                                 rate + usage + mix + unexplained = delta total
  commitments <export> [--expiry ids.csv --within-days 90 --as-of YYYY-MM-DD]
  --self-test                                    synthetic FOCUS rows through every subcommand
Common options: --profile focus|cur2|gcp  --map Canonical=Header (repeatable)
  --cost effective|billed|list|contracted  --period YYYY-MM  --service NAME  --where Col=value  --json
Headers match after normalisation (lowercase, non-alphanumerics dropped): ResourceId = ResourceID =
resource_id. The cur2 (AWS CUR 2.0) and gcp (BigQuery billing export) maps are unverified against a
real export — check the columns report, and fix a header with --map. gcp maps `cost` to BilledCost, so
pass --cost billed there. Multiple BillingCurrency values are reported per currency, never summed.
Only CSV or CSV.gz is read; Parquet and anything else exits 2 ("unsupported format: convert to CSV").

Exit codes: 0 ok; 1 a reconciliation line did not balance; 2 unreadable/empty input, unsupported
format, a required column absent, or bad arguments.
"""
import argparse, contextlib, csv, datetime as dt, gzip, io, json, os, re, sys, tempfile
from collections import defaultdict
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, getcontext

getcontext().prec = 60          # wide enough that every sum and the split products stay exact
ZERO, CENT, UNIT = Decimal(0), Decimal("0.01"), Decimal("1e-12")
LIST_LABEL = " (list price — not a saving basis)"
UNVERIFIED = "unverified against a real export — check the columns report"
CANON = ("BilledCost EffectiveCost ListCost ContractedCost BillingCurrency BillingPeriodStart "
         "BillingPeriodEnd ChargePeriodStart ChargePeriodEnd ChargeCategory ServiceName SkuId RegionId "
         "ResourceId ResourceType Tags ConsumedQuantity PricingQuantity PricingUnit CommitmentDiscountId "
         "CommitmentDiscountStatus CommitmentDiscountType SubAccountId ServiceProviderName").split()
COST_COL = {"effective": "EffectiveCost", "billed": "BilledCost", "list": "ListCost",
            "contracted": "ContractedCost"}
PROFILES = {  # canonical -> candidate headers, first non-blank value wins; the canonical name is tried last
    "focus": {"ServiceProviderName": ["ServiceProviderName", "ProviderName"]},
    "cur2": {"BilledCost": ["line_item_unblended_cost"], "EffectiveCost": ["line_item_net_unblended_cost"],
             "ListCost": ["pricing_public_on_demand_cost"], "BillingCurrency": ["line_item_currency_code"],
             "BillingPeriodStart": ["bill_billing_period_start_date"],
             "BillingPeriodEnd": ["bill_billing_period_end_date"],
             "ChargePeriodStart": ["line_item_usage_start_date"],
             "ServiceName": ["product_servicecode", "line_item_product_code"],
             "SkuId": ["line_item_usage_type"], "RegionId": ["product_region_code"],
             "ResourceId": ["line_item_resource_id"], "Tags": ["resource_tags"],
             "ChargeCategory": ["line_item_line_item_type"], "ConsumedQuantity": ["line_item_usage_amount"],
             "SubAccountId": ["line_item_usage_account_id"],
             "CommitmentDiscountId": ["savings_plan_savings_plan_a_r_n", "reservation_reservation_a_r_n"]},
    "gcp": {"BilledCost": ["cost"], "ChargePeriodStart": ["usage_start_time"],
            "BillingPeriodStart": ["invoice.month"], "ServiceName": ["service.description"],
            "SkuId": ["sku.description", "sku.id"], "RegionId": ["location.region"], "Tags": ["labels"],
            "ResourceId": ["resource.name"], "BillingCurrency": ["currency"],
            "ConsumedQuantity": ["usage.amount"], "SubAccountId": ["project.id"]},
}


class BillError(Exception):
    def __init__(self, msg, code=2):
        super().__init__(msg)
        self.code = code


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def canonical(name):
    return next((c for c in CANON if norm(c) == norm(name)), None)


def read_csv(path):
    low = path.lower()
    if not (low.endswith(".csv") or low.endswith(".csv.gz")):
        raise BillError("unsupported format: convert to CSV (%s)" % os.path.basename(path))
    if not os.path.isfile(path):
        raise BillError("cannot read %s: no such file" % path)
    csv.field_size_limit(1 << 30)
    try:
        with (gzip.open if low.endswith(".gz") else open)(path, "rt", encoding="utf-8-sig", newline="") as fh:
            reader = csv.reader(fh)
            header = next(reader, None)
            records = [(reader.line_num, r) for r in reader if any(f.strip() for f in r)]
    except (OSError, UnicodeDecodeError, csv.Error, EOFError) as exc:
        raise BillError("cannot read %s: %s" % (path, exc))
    if not header or not any(h.strip() for h in header):
        raise BillError("empty file or no header: %s" % path)
    return [h.strip() for h in header], records


def resolve(header, profile, overrides):
    by_norm = {}
    for h in header:
        by_norm.setdefault(norm(h), h)
    cols = {}
    for c in CANON:
        found = [by_norm[norm(x)] for x in PROFILES[profile].get(c, []) + [c] if norm(x) in by_norm]
        cols[c] = list(dict.fromkeys(found))
    for spec in overrides:
        name, _, head = spec.partition("=")
        c = canonical(name)
        if not c or norm(head) not in by_norm:
            raise BillError("--map %s: need Canonical=Header with a header that exists in this export" % spec)
        cols[c] = [by_norm[norm(head)]]
    return cols


def pick(rec, indexes):
    return next((rec[i].strip() for i in indexes if i < len(rec) and rec[i].strip()), "")


def to_dec(text, line, col):
    try:
        return Decimal(text) if text else ZERO
    except InvalidOperation:
        raise BillError("line %d: %s is not a number: %r" % (line, col, text))


def to_date(text):
    try:
        return dt.date.fromisoformat(text[:10])
    except ValueError:
        return None


def period_of(row):
    v = row.get("BillingPeriodStart") or row.get("ChargePeriodStart") or ""
    return v[:4] + "-" + v[4:6] if re.fullmatch(r"\d{6}", v) else v[:7]


def currency(row):
    return row.get("BillingCurrency") or "(no currency)"


def parse_tags(text):
    """{} for blank, a dict for a JSON object or a GCP-style [{key, value}] list, None when unreadable."""
    if not text:
        return {}
    try:
        obj = json.loads(text)
    except ValueError:
        return None
    if isinstance(obj, dict):
        return {str(k): "" if v is None else str(v) for k, v in obj.items()}
    if isinstance(obj, list) and all(isinstance(t, dict) and "key" in t for t in obj):
        return {str(t["key"]): str(t.get("value", "")) for t in obj}
    return None


def fmt(d):
    return format(d.quantize(CENT, ROUND_HALF_UP), ",.2f")


def share(part, total):
    return "n/a" if not total else "%s%%" % (part * 100 / total).quantize(Decimal("0.1"), ROUND_HALF_UP)


class Export:
    """The rows of one export after column resolution and filters; row["_cost"] is the chosen cost."""

    def __init__(self, a, need_cost=True):
        self.header, records = read_csv(a.file)
        self.profile, self.cols = a.profile, resolve(self.header, a.profile, a.map)
        self.cost_name = COST_COL[a.cost]
        self.label = LIST_LABEL if a.cost == "list" else ""
        has_cost = bool(self.cols[self.cost_name])
        if need_cost and not has_cost:
            have = [c for c in COST_COL.values() if self.cols[c]] or ["none"]
            raise BillError("cost column %s is absent; cost columns present: %s; header: %s"
                            % (self.cost_name, ", ".join(have), ", ".join(self.header)))
        idx = {h: i for i, h in enumerate(self.header)}
        wanted = {c: [idx[h] for h in hs] for c, hs in self.cols.items() if hs}
        wheres = [self._where(spec, idx) for spec in a.where]
        if a.period and not re.fullmatch(r"\d{4}-\d{2}", a.period):
            raise BillError("--period must be YYYY-MM")
        for flag, needs in ((a.period, "BillingPeriodStart"), (a.service, "ServiceName")):
            if flag and not (self.cols[needs] or (needs == "BillingPeriodStart" and self.cols["ChargePeriodStart"])):
                raise BillError("filter needs column %s, which is absent" % needs)
        self.rows = []
        for line, rec in records:
            row = {c: pick(rec, ix) for c, ix in wanted.items()}
            if (a.period and period_of(row) != a.period) or (a.service and row.get("ServiceName") != a.service):
                continue
            if any(pick(rec, ix) != val for ix, val in wheres):
                continue
            if has_cost:
                row["_cost"] = to_dec(row.get(self.cost_name, ""), line, self.cost_name)
            self.rows.append(row)

    def _where(self, spec, idx):
        name, sep, val = spec.partition("=")
        c = canonical(name)
        heads = self.cols[c] if c else [h for h in self.header if norm(h) == norm(name)]
        if not sep or not heads:
            raise BillError("--where %s: need Col=value with a column present in this export" % spec)
        return [idx[h] for h in heads], val

    def need(self, *cols):
        missing = [c for c in cols if not self.cols[c]]
        if missing:
            raise BillError("required column absent: %s (see the columns report; --map fixes a header)"
                            % ", ".join(missing))

    def head(self):
        return "cost column: %s (header %s) · profile %s · %d rows%s" % (
            self.cost_name, " | ".join(self.cols[self.cost_name]), self.profile, len(self.rows), self.label)

    def m(self, text):
        return text + self.label

    def by_currency(self):
        groups = defaultdict(list)
        for r in self.rows:
            groups[currency(r)].append(r)
        return sorted(groups.items())


def total(rows):
    return sum((r["_cost"] for r in rows), ZERO)


def cmd_columns(ex, a):
    lines = ["profile: %s%s" % (ex.profile, "" if ex.profile == "focus" else " — map " + UNVERIFIED)]
    for c in CANON:
        lines.append("  %-25s %s" % (c, " | ".join(ex.cols[c]) or "absent"))
    lines.append("cost column read: %s -> %s" % (ex.cost_name, " | ".join(ex.cols[ex.cost_name])
                                                 or "ABSENT (summary/attribution/split/commitments exit 2)"))
    curs = sorted({currency(r) for r in ex.rows})
    periods = sorted({period_of(r) for r in ex.rows} - {""})
    lines += ["rows: %d" % len(ex.rows), "currencies: %s" % (", ".join(curs) or "none"),
              "billing periods: %s" % (", ".join(periods) or "none")]
    data = {"profile": ex.profile, "columns": {c: ex.cols[c] or None for c in CANON},
            "cost_column": ex.cost_name, "cost_column_present": bool(ex.cols[ex.cost_name]),
            "rows": len(ex.rows), "currencies": curs, "billing_periods": periods}
    if ex.profile != "focus":
        data["note"] = UNVERIFIED
    return 0, data, lines


def completeness(ex):
    days, ends = defaultdict(set), {}
    for r in ex.rows:
        bp = r.get("BillingPeriodStart", "")
        days[bp].add(r.get("ChargePeriodStart", "")[:10])
        ends[bp] = r.get("BillingPeriodEnd", "")
    out = {}
    for bp in sorted(days):
        seen = {d for d in days[bp] if to_date(d)}
        start, end = to_date(bp), to_date(ends[bp])
        if start and end and end > start:
            n = (end - start).days
            k = sum(1 for d in seen if start <= to_date(d) < end)
            out[bp or "(no billing period)"] = ("complete" if k == n else "partial") + " (%d/%d days)" % (k, n)
        else:
            out[bp or "(no billing period)"] = "days with rows: %d" % len(seen)
    return out


def dimension(ex, by):
    simple = {"service": ("ServiceName",), "sku": ("ServiceName", "SkuId"), "region": ("RegionId",),
              "resource": ("ResourceId",), "subaccount": ("SubAccountId",)}
    if by in simple:
        ex.need(*simple[by])
        return lambda r: " / ".join(r.get(c) or "(blank)" for c in simple[by])
    if by.startswith("tag:") and by[4:]:
        ex.need("Tags")
        key = by[4:]
        return lambda r: (parse_tags(r.get("Tags", "")) or {}).get(key) or "(untagged)"
    raise BillError("--by must be service|sku|region|resource|subaccount|tag:<key>")


def cmd_summary(ex, a):
    keyf = dimension(ex, a.by)
    comp = completeness(ex)
    lines = [ex.head()] + ["period %s: %s" % kv for kv in comp.items()]
    data, code = {"cost_column": ex.cost_name, "by": a.by, "completeness": comp, "totals": {}, "groups": {}}, 0
    for cur, rows in ex.by_currency():
        groups = defaultdict(lambda: ZERO)
        for r in rows:
            groups[keyf(r)] += r["_cost"]
        tot = total(rows)
        ranked = sorted(groups.items(), key=lambda kv: (-kv[1], kv[0]))
        lines.append(ex.m("[%s] total %s across %d %s groups" % (cur, fmt(tot), len(ranked), a.by)))
        for k, v in ranked[:a.top]:
            lines.append(ex.m("  %14s  %6s  %s" % (fmt(v), share(v, tot), k)))
        if len(ranked) > a.top:
            rest = sum((v for _, v in ranked[a.top:]), ZERO)
            lines.append(ex.m("  %14s  %6s  (other %d groups)" % (fmt(rest), share(rest, tot), len(ranked) - a.top)))
        ok = sum(groups.values(), ZERO) == tot
        code = code or (0 if ok else 1)
        lines.append("[%s] sum of groups == total: %s" % (cur, "yes" if ok else "NO"))
        data["totals"][cur], data["groups"][cur] = tot, dict(ranked)
    if a.by.startswith("tag:"):
        bad = sum(1 for r in ex.rows if parse_tags(r.get("Tags", "")) is None)
        lines.append("tags unreadable: %d rows (counted as untagged)" % bad)
        data["tags_unreadable_rows"] = bad
    return code, data, lines


def attribute(row, keys, allowed, untaggable):
    if row.get("ResourceType") in untaggable or row.get("ServiceName") in untaggable:
        return "untaggable"
    cat = row.get("ChargeCategory", "")
    if not row.get("ResourceId") and cat and cat.lower() != "usage":
        return "untaggable"
    tags = parse_tags(row.get("Tags", "")) or {}
    state = "tagged"
    for k in keys:
        if k in tags:
            if k in allowed and tags[k] not in allowed[k]:
                state = "mis-tagged"
        elif any(t.lower() == k.lower() for t in tags):
            state = "mis-tagged"
        else:
            return "untagged"
    return state


def cmd_attribution(ex, a):
    ex.need("Tags")
    keys = [k.strip() for k in a.required_keys.split(",") if k.strip()]
    allowed = {}
    for spec in a.allowed:
        k, sep, vals = spec.partition("=")
        if not sep:
            raise BillError("--allowed must be key=v1|v2")
        allowed[k.strip()] = set(vals.split("|"))
    untaggable = set()
    if a.untaggable:
        try:
            with open(a.untaggable, encoding="utf-8") as fh:
                untaggable = {ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")}
        except OSError as exc:
            raise BillError("cannot read --untaggable: %s" % exc)
    cats = ("tagged", "mis-tagged", "untagged", "untaggable")
    bad = sum(1 for r in ex.rows if parse_tags(r.get("Tags", "")) is None)
    lines = [ex.head(), "required keys: %s · allowed: %s" % (
        ",".join(keys), "; ".join("%s=%s" % (k, "|".join(sorted(v))) for k, v in allowed.items()) or "any")]
    data, code = {"cost_column": ex.cost_name, "tags_unreadable_rows": bad, "by_currency": {}}, 0
    for cur, rows in ex.by_currency():
        sums, untagged = {c: ZERO for c in cats}, defaultdict(lambda: ZERO)
        for r in rows:
            c = attribute(r, keys, allowed, untaggable)
            sums[c] += r["_cost"]
            if c == "untagged":
                untagged[r.get("ResourceId") or "(no resource id)"] += r["_cost"]
        tot = total(rows)
        ok = sum(sums.values(), ZERO) == tot
        code = code or (0 if ok else 1)
        lines += [ex.m("[%s] %-10s %14s  %6s" % (cur, c, fmt(sums[c]), share(sums[c], tot))) for c in cats]
        lines.append(ex.m("[%s] tagged + mis-tagged + untagged + untaggable = total (%s) %s" % (
            cur, " + ".join(fmt(sums[c]) for c in cats) + " = " + fmt(tot), "OK" if ok else "MISMATCH")))
        top = sorted(untagged.items(), key=lambda kv: (-kv[1], kv[0]))[:a.top]
        lines += [ex.m("  untagged %14s  %s" % (fmt(v), k)) for k, v in top]
        data["by_currency"][cur] = {"sums": sums, "total": tot, "reconciled": ok, "top_untagged": dict(top)}
    lines.append("tags unreadable: %d rows (counted as untagged)" % bad)
    return code, data, lines


def quantity(row):
    q = row.get("PricingQuantity") or row.get("ConsumedQuantity") or ""
    try:
        return Decimal(q) if q else ZERO
    except InvalidOperation:
        return ZERO


def split_key(base_cur, key):
    (c1, q1), (c2, q2) = base_cur
    if c1 is None:
        return {"mix": c2}, "mix: new line"
    if c2 is None:
        return {"mix": -c1}, "mix: gone"
    if q1 and q2:
        at_old_price = (c1 / q1 * q2).quantize(UNIT)        # p1 x q2
        return {"usage": at_old_price - c1, "rate": c2 - at_old_price}, "priced"   # (q2-q1)p1, (p2-p1)q2
    return {"unexplained": c2 - c1}, "unexplained (no quantity)"


def cmd_split(ex, a):
    for p in (a.base, a.cur):
        if not re.fullmatch(r"\d{4}-\d{2}", p):
            raise BillError("--base/--cur must be YYYY-MM")
    if not (ex.cols["BillingPeriodStart"] or ex.cols["ChargePeriodStart"]):
        ex.need("BillingPeriodStart")
    ex.need("ServiceName", *(("SkuId",) if a.by == "sku" else ()))
    lines = [ex.head(), "split %s -> %s by %s; rate = (p2-p1)*q2, usage = (q2-q1)*p1, p = cost / quantity"
             % (a.base, a.cur, a.by)]
    data, code = {"cost_column": ex.cost_name, "base": a.base, "cur": a.cur, "by_currency": {}}, 0
    for cur, rows in ex.by_currency():
        agg = defaultdict(lambda: [ZERO, ZERO])
        totals = {a.base: ZERO, a.cur: ZERO}
        for r in rows:
            p = period_of(r)
            if p in totals:
                key = (r.get("ServiceName", ""), r.get("SkuId", "")) if a.by == "sku" else (r.get("ServiceName", ""),)
                slot = agg[(p, key)]
                slot[0] += r["_cost"]
                slot[1] += quantity(r)
                totals[p] += r["_cost"]
        effects = {k: ZERO for k in ("rate", "usage", "mix", "unexplained")}
        movers = []
        for key in sorted({k for _, k in agg}):
            pair = [tuple(agg[(p, key)]) if (p, key) in agg else (None, None) for p in (a.base, a.cur)]
            eff, kind = split_key(pair, key)
            for k, v in eff.items():
                effects[k] += v
            delta = (pair[1][0] or ZERO) - (pair[0][0] or ZERO)
            movers.append((abs(delta), " / ".join(k or "(blank)" for k in key), delta, kind, eff))
        delta_total = totals[a.cur] - totals[a.base]
        ok = sum(effects.values(), ZERO) == delta_total
        code = code or (0 if ok else 1)
        lines.append(ex.m("[%s] %s total %s -> %s total %s" % (cur, a.base, fmt(totals[a.base]), a.cur, fmt(totals[a.cur]))))
        lines += [ex.m("[%s] %-12s %14s" % (cur, k, fmt(v))) for k, v in effects.items()]
        lines.append(ex.m("[%s] rate + usage + mix + unexplained = Δtotal (%s = %s) %s" % (
            cur, " + ".join(fmt(v) for v in effects.values()), fmt(delta_total), "OK" if ok else "MISMATCH")))
        movers.sort(key=lambda m: (-m[0], m[1]))
        for _, name, delta, kind, eff in movers[:a.top]:
            parts = ", ".join("%s %s" % (k, fmt(v)) for k, v in eff.items())
            lines.append(ex.m("  Δ %14s  %s  [%s] %s" % (fmt(delta), name, kind, parts)))
        data["by_currency"][cur] = {"totals": totals, "effects": effects, "delta": delta_total, "reconciled": ok,
                                    "movers": [{"key": n, "delta": d, "kind": k, "effects": e}
                                               for _, n, d, k, e in movers[:a.top]]}
    return code, data, lines


def read_expiry(path):
    try:
        with open(path, encoding="utf-8-sig", newline="") as fh:
            rows = list(csv.DictReader(fh))
    except (OSError, csv.Error) as exc:
        raise BillError("cannot read --expiry: %s" % exc)
    out = {}
    for r in rows:
        r = {norm(k or ""): (v or "").strip() for k, v in r.items()}
        if r.get("id") and to_date(r.get("enddate", "")):
            out[r["id"]] = to_date(r["enddate"])
    return out


def cmd_commitments(ex, a):
    ex.need("CommitmentDiscountId")
    as_of = to_date(a.as_of) if a.as_of else dt.date.today()
    if not as_of:
        raise BillError("--as-of must be YYYY-MM-DD")
    expiry = read_expiry(a.expiry) if a.expiry else None
    lines = [ex.head(), "utilisation = Used / (Used + Unused) by CommitmentDiscountStatus",
             "coverage = commitment-covered usage cost / eligible usage cost; eligible = ChargeCategory Usage rows "
             "excluding Unused-commitment rows; covered = eligible rows with a CommitmentDiscountId"]
    if not ex.cols["CommitmentDiscountStatus"]:
        lines.append("CommitmentDiscountStatus absent: utilisation cannot be read from this export")
    data = {"cost_column": ex.cost_name, "as_of": str(as_of), "by_currency": {}}
    for cur, rows in ex.by_currency():
        ids = defaultdict(lambda: {"used": ZERO, "unused": ZERO, "other": ZERO})
        eligible = covered = ZERO
        for r in rows:
            cid, status = r.get("CommitmentDiscountId", ""), r.get("CommitmentDiscountStatus", "").lower()
            if cid:
                ids[cid][status if status in ("used", "unused") else "other"] += r["_cost"]
            if r.get("ChargeCategory", "").lower() == "usage" and status != "unused":
                eligible += r["_cost"]
                covered += r["_cost"] if cid else ZERO
        lines.append(ex.m("[%s] coverage %s (covered %s of eligible %s)" % (
            cur, share(covered, eligible), fmt(covered), fmt(eligible))))
        out = {}
        for cid in sorted(ids):
            s = ids[cid]
            util = share(s["used"], s["used"] + s["unused"])
            line = "[%s] %s used %s unused %s other %s utilisation %s" % (
                cur, cid, fmt(s["used"]), fmt(s["unused"]), fmt(s["other"]), util)
            out[cid] = dict(s, utilisation=util)
            if expiry is not None:
                end = expiry.get(cid)
                left = (end - as_of).days if end else None
                flag = ("" if left is None or left > a.within_days else
                        " EXPIRED" if left < 0 else " EXPIRES in %d days" % left)
                line += " · end %s%s" % (end or "not in expiry file", flag)
                out[cid].update(end_date=str(end) if end else None, flagged=bool(flag))
            lines.append(ex.m(line))
        data["by_currency"][cur] = {"coverage": share(covered, eligible), "covered": covered,
                                    "eligible": eligible, "commitments": out}
    if expiry is None:
        lines.append("expiry: not in this export (pass --expiry <csv>)")
    return 0, data, lines


COMMANDS = {"columns": cmd_columns, "summary": cmd_summary, "attribution": cmd_attribution,
            "split": cmd_split, "commitments": cmd_commitments}


def build_parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("file")
    common.add_argument("--profile", choices=sorted(PROFILES), default="focus")
    common.add_argument("--map", action="append", default=[], metavar="Canonical=Header")
    common.add_argument("--cost", choices=list(COST_COL), default="effective")
    common.add_argument("--period", metavar="YYYY-MM")
    common.add_argument("--service")
    common.add_argument("--where", action="append", default=[], metavar="Col=value")
    common.add_argument("--top", type=int, default=15)
    common.add_argument("--json", action="store_true")
    p = argparse.ArgumentParser(prog="bill-lane.py", description="Read a FOCUS billing export (CSV).")
    p.add_argument("--self-test", action="store_true")
    sub = p.add_subparsers(dest="cmd")
    sub.add_parser("columns", parents=[common])
    sub.add_parser("summary", parents=[common]).add_argument("--by", default="service")
    at = sub.add_parser("attribution", parents=[common])
    at.add_argument("--required-keys", required=True)
    at.add_argument("--allowed", action="append", default=[], metavar="key=v1|v2")
    at.add_argument("--untaggable", metavar="PATH")
    sp = sub.add_parser("split", parents=[common])
    sp.add_argument("--base", required=True)
    sp.add_argument("--cur", required=True)
    sp.add_argument("--by", choices=["sku", "service"], default="sku")
    cm = sub.add_parser("commitments", parents=[common])
    cm.add_argument("--expiry", metavar="PATH")
    cm.add_argument("--within-days", type=int, default=90)
    cm.add_argument("--as-of", metavar="YYYY-MM-DD")
    return p


def run(argv):
    """(exit code, data dict, text lines, parsed args) — the one path main() and the self-test share."""
    try:
        a = build_parser().parse_args(argv)
    except SystemExit as exc:
        return (exc.code if isinstance(exc.code, int) else 2), {"error": "bad arguments"}, [], None
    if a.self_test or not a.cmd:
        return None, {}, [], a
    try:
        code, data, lines = COMMANDS[a.cmd](Export(a, need_cost=a.cmd != "columns"), a)
    except BillError as exc:
        return exc.code, {"error": str(exc)}, [], a
    return code, data, lines, a


def render(data, lines, as_json):
    return json.dumps(data, default=str, indent=2, ensure_ascii=False) if as_json else "\n".join(lines)


def self_test():
    rows, header = [], ("BilledCost EffectiveCost ListCost BillingCurrency BillingPeriodStart BillingPeriodEnd "
                        "ChargePeriodStart ChargeCategory ServiceName SkuId RegionId ResourceID ResourceType Tags "
                        "PricingQuantity CommitmentDiscountId CommitmentDiscountStatus SubAccountId ProviderName").split()

    def add(day, cost, svc, sku, res, tags, qty="", cat="Usage", cid="", status="", cur="USD"):
        d = dt.date.fromisoformat(day)
        end = (d.replace(day=28) + dt.timedelta(days=4)).replace(day=1)
        cost = Decimal(cost)
        rows.append([cost, cost, cost * Decimal("1.2"), cur, "%sT00:00:00Z" % d.replace(day=1),
                     "%sT00:00:00Z" % end, "%sT00:00:00Z" % d, cat, svc, sku, "eu-west-1", res, "vm",
                     tags if isinstance(tags, str) else json.dumps(tags), qty, cid, status, "acct-1", "Cloud"])
    for month, ndays in (("2026-07", 31), ("2026-08", 31), ("2026-09", 10)):
        for day in range(1, ndays + 1):
            d = "%s-%02d" % (month, day)
            used = month == "2026-08"
            add(d, "2.88" if month == "2026-09" else "2.40", "Compute", "vm-small", "vm-1",
                {"team": "core", "env": "prod"}, "24", cid="cd-1" if used else "", status="Used" if used else "")
            if month != "2026-09":
                add(d, "12.00", "Compute", "vm-large", "vm-2", {"Team": "core", "env": "prod"}, "24")
            add(d, "2.40" if month == "2026-09" else "2.00", "Storage", "blob-hot", "bucket-1",
                {"team": "data", "env": "qa"}, "120" if month == "2026-09" else "100")
            if month == "2026-09":
                add(d, "0.50", "Storage", "blob-archive", "bucket-2", [{"key": "team", "value": "data"}], "50")
        add(month + "-01", "6.00" if month == "2026-09" else "5.00", "Compute", "", "", "", cat="Tax")
    add("2026-07-01", "1.00", "Compute", "ip-address", "vm-3", "{bad json")
    add("2026-08-01", "24.80", "Compute", "commitment", "", "", cid="cd-1", status="Unused")
    results = []

    def check(name, cond):
        results.append((name, bool(cond)))

    with tempfile.TemporaryDirectory() as tmp:
        def write(name, extra=()):
            path = os.path.join(tmp, name)
            opener = gzip.open if name.endswith(".gz") else open
            with opener(path, "wt", newline="", encoding="utf-8") as fh:
                csv.writer(fh).writerows([header] + rows + list(extra))
            return path
        f, gz = write("focus.csv"), write("focus.csv.gz")
        multi = write("multi.csv", [["7.00", "7.00", "8.40", "EUR", "2026-09-01T00:00:00Z", "2026-10-01T00:00:00Z",
                                     "2026-09-02T00:00:00Z", "Usage", "Storage", "blob-hot", "eu", "b-9", "vm",
                                     "{}", "1", "", "", "acct-1", "Cloud"]])
        expiry = os.path.join(tmp, "expiry.csv")
        with open(expiry, "w") as fh:
            fh.write("id,end_date\ncd-1,2026-11-15\n")
        code, data, _, _ = run(["columns", f])
        check("columns: default cost column is EffectiveCost", code == 0 and data["cost_column"] == "EffectiveCost")
        check("columns: ResourceID header matches ResourceId", data["columns"]["ResourceId"] == ["ResourceID"])
        check("columns: ProviderName accepted as ServiceProviderName", data["columns"]["ServiceProviderName"] == ["ProviderName"])
        check("--cost contracted (absent) exits 2", run(["summary", f, "--cost", "contracted"])[0] == 2)
        code, data, lines, _ = run(["summary", f, "--by", "sku"])
        check("summary: sum of groups == total yes", code == 0 and "[USD] sum of groups == total: yes" in lines)
        check("summary: total exact", data["totals"]["USD"] == Decimal("1116.40"))
        comp = data["completeness"]
        check("summary: 2026-07 complete", comp["2026-07-01T00:00:00Z"] == "complete (31/31 days)")
        check("summary: 2026-09 partial", comp["2026-09-01T00:00:00Z"] == "partial (10/30 days)")
        code, data, lines, _ = run(["summary", gz, "--by", "tag:team", "--json"])
        check("summary: gzip + tag dimension + json", code == 0 and json.loads(render(data, lines, True))["tags_unreadable_rows"] == 1)
        code, data, lines, _ = run(["attribution", f, "--required-keys", "team,env",
                                    "--allowed", "team=core|data", "--allowed", "env=prod|staging"])
        s = data["by_currency"]["USD"]["sums"]
        check("attribution: reconciliation OK", code == 0 and data["by_currency"]["USD"]["reconciled"]
              and sum(s.values(), ZERO) == Decimal("1116.40") and any(l.endswith(" OK") for l in lines))
        check("attribution: tagged", s["tagged"] == Decimal("177.60"))
        check("attribution: Team variant + value outside set are mis-tagged", s["mis-tagged"] == Decimal("892.00"))
        check("attribution: missing key + malformed tags untagged", s["untagged"] == Decimal("30.80"))
        check("attribution: Tax row untaggable", s["untaggable"] == Decimal("16.00"))
        check("attribution: malformed Tags counted", data["tags_unreadable_rows"] == 1)
        code, data, lines, _ = run(["split", f, "--base", "2026-08", "--cur", "2026-09"])
        e = data["by_currency"]["USD"]["effects"]
        check("split: reconciliation exact", code == 0 and sum(e.values(), ZERO) == data["by_currency"]["USD"]["delta"])
        check("split: rate effect of the price change", e["rate"] == Decimal("4.80"))
        check("split: usage effect", e["usage"] == Decimal("-88.40"))
        check("split: mix new + gone", e["mix"] == Decimal("-391.80"))
        check("split: no-quantity line is unexplained", e["unexplained"] == Decimal("1.00"))
        code, data, lines, _ = run(["commitments", f, "--period", "2026-08"])
        c = data["by_currency"]["USD"]
        check("commitments: utilisation 75%", c["commitments"]["cd-1"]["utilisation"] == "75.0%")
        check("commitments: coverage", c["covered"] == Decimal("74.40") and c["eligible"] == Decimal("508.40"))
        check("commitments: expiry absent stated", "expiry: not in this export (pass --expiry <csv>)" in lines)
        code, data, lines, _ = run(["commitments", f, "--expiry", expiry, "--as-of", "2026-10-01"])
        check("commitments: expiry flagged", data["by_currency"]["USD"]["commitments"]["cd-1"]["flagged"])
        code, data, lines, _ = run(["summary", multi])
        check("multi-currency: not summed across", code == 0 and data["totals"]["EUR"] == Decimal("7.00")
              and data["totals"]["USD"] == Decimal("1116.40"))
        code, data, lines, _ = run(["summary", f, "--cost", "list"])
        money = [l for l in lines if re.search(r"\d\.\d\d\b", l)]
        check("--cost list labels every money line", money and all(l.endswith(LIST_LABEL) for l in money))
        check(".parquet exits 2", run(["summary", os.path.join(tmp, "x.parquet")])[0] == 2)
        check("missing file exits 2", run(["summary", os.path.join(tmp, "nope.csv")])[0] == 2)
        open(os.path.join(tmp, "empty.csv"), "w").close()
        check("empty file exits 2", run(["columns", os.path.join(tmp, "empty.csv")])[0] == 2)
        with contextlib.redirect_stderr(io.StringIO()):
            check("bad args exit 2", run(["split", f, "--base", "2026-08"])[0] == 2)
    failed = [n for n, ok in results if not ok]
    for n in failed:
        print("FAIL: " + n)
    print("self-test: %d/%d passed" % (len(results) - len(failed), len(results)))
    return 1 if failed else 0


def main(argv=None):
    code, data, lines, a = run(sys.argv[1:] if argv is None else argv)
    if a is not None and (a.self_test or not a.cmd):
        if a.self_test:
            return self_test()
        build_parser().print_usage(sys.stderr)
        return 2
    if "error" in data:
        if a is not None:
            print("bill-lane: " + data["error"], file=sys.stderr)
        return code
    print(render(data, lines, a.json))
    return code


if __name__ == "__main__":
    sys.exit(main())
