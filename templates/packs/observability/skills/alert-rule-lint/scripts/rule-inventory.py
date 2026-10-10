#!/usr/bin/env python3
"""rule-inventory.py — alert-rule-lint's no-tool lane: one JSON row per Prometheus rule, checked per rule.

Reads plain rule files, PrometheusRule CRDs (multi-document), Helm values that embed rule groups
(`additionalPrometheusRulesMap`, `additionalPrometheusRules`) and Mimir / Thanos / Loki ruler files.
A small YAML-subset reader (block maps and lists, flow `{}`/`[]`, quoted and plain scalars, plain
multi-line scalars, `|` / `>` block scalars) skips comment lines, so a commented `# runbook_url:` never
counts, and every rule is judged on its own keys — never on its file's, never on the next group's.
Stdlib only. Read-only: it writes nothing unless `--emit-rules=DIR` is given (a scratch dir).

Usage:  rule-inventory.py <file-or-dir> [...] [--check=all|annotations,for,windows,selectors,prom3,
                          value-in-labels,nan,absent,watchdog,expr,design] [--format=json|text]
                          [--inventory=names.txt] [--prometheus-config=prometheus.yml] [--prometheus-cr=prom.yaml]
                          [--scrape=job=30s,...] [--prom-major=2|3] [--group-labels=yes|no|unknown]
                          [--page-severities=page,critical] [--severity-vocab=page,ticket,info,none]
                          [--page-for-max=30m] [--label-sets] [--am=alertmanager.yml] [--emit-rules=DIR]
        rule-inventory.py --self-test
Exit:   0 no problem · 1 at least one problem (H/M/L; `hardening` and `note` never set it) · 2 usage or parse error

Codes (alert-rule-lint §): AL-01 AL-02 AL-09 (§1) · AL-03..AL-06 (§2) · AL-07 AL-08 AL-13 AL-14 AL-15
AL-20 (§3, --check=expr) · AL-10 AL-22 (§4) · AL-12 AL-21 (§5) · AL-16 AL-17 AL-18 (§6) · SY-01 SY-02
SY-03 SY-04 (§7, --check=design) · AM-01 AM-08 AM-03 (§8, --am). A row is a candidate for the read
step and the tool oracle, never a finding by itself.
"""
import fnmatch, glob, json, os, re, sys

# ---------------------------------------------------------------- YAML subset ------------------
KEY = re.compile(r'^((?:"[^"]*"|\'[^\']*\'|[^\s#\'"{\[\-][^:#]*?|-[^\s:][^:#]*?)):(?:\s+|$)(.*)$')


class Q(str):
    """A scalar that was quoted in the YAML: never typed to a bool, number or null."""


class Doc:
    def __init__(self, text):
        self.lines = text.split("\n")

    def sig(self, i):
        """Index of the next significant line at or after i (skips blanks, comments, Helm directives)."""
        while i < len(self.lines):
            s = self.lines[i].strip()
            if s and not s.startswith("#") and not (s.startswith("{{") and s.endswith("}}")) and s != "---":
                return i
            if s == "---":
                return i
            i += 1
        return i

    def ind(self, i):
        ln = self.lines[i]
        return len(ln) - len(ln.lstrip(" "))

    def block(self, i, minind):
        """Parse the block starting at the next significant line whose indent >= minind."""
        i = self.sig(i)
        if i >= len(self.lines) or self.lines[i].strip() == "---" or self.ind(i) < minind:
            return None, i
        n = self.ind(i)
        s = self.lines[i].strip()
        if s == "-" or s.startswith("- "):
            return self.seq(i, n)
        return self.mapping(i, n, None)

    def seq(self, i, n):
        out = []
        while True:
            i = self.sig(i)
            if i >= len(self.lines) or self.lines[i].strip() == "---" or self.ind(i) != n:
                break
            s = self.lines[i].strip()
            if not (s == "-" or s.startswith("- ")):
                break
            rest = s[1:].lstrip()
            col = n + (len(s) - len(rest))
            if not rest:
                v, i = self.block(i + 1, n + 1)
                out.append(v)
            elif KEY.match(rest) and not rest.startswith(("{", "[")):
                v, i = self.mapping(i, col, rest)
                out.append(v)
            else:
                v, i = self.scalar(rest, i, n)
                out.append(v)
        return out, i

    def mapping(self, i, n, first):
        m = {"__line__": i + 1, "__lines__": {}}
        while True:
            if first is not None:
                s, first, lno = first, None, i
            else:
                i = self.sig(i)
                if i >= len(self.lines) or self.lines[i].strip() == "---" or self.ind(i) != n:
                    break
                s, lno = self.lines[i].strip(), i
                if s == "-" or s.startswith("- "):
                    break
            k = KEY.match(s)
            if not k:
                i = lno + 1
                continue
            key, val = k.group(1).strip("\"'"), k.group(2)
            m["__lines__"][key] = lno + 1
            if val.strip() == "" or val.lstrip().startswith("#"):
                v, j = self.block(lno + 1, n + 1)
                if v is None:  # a list may sit at the key's own indent
                    j2 = self.sig(lno + 1)
                    if j2 < len(self.lines) and self.ind(j2) == n and self.lines[j2].strip().startswith("-"):
                        v, j = self.seq(j2, n)
                m[key], i = v, j
            else:
                m[key], i = self.scalar(val, lno, n)
        return m, i

    def scalar(self, val, lno, n):
        v = val.strip()
        if v[:1] in "|>":  # block scalar
            body, j = [], lno + 1
            while j < len(self.lines) and (not self.lines[j].strip() or self.ind(j) > n):
                body.append(self.lines[j])
                j += 1
            while body and not body[-1].strip():
                body.pop()
            dent = min((len(b) - len(b.lstrip(" ")) for b in body if b.strip()), default=0)
            body = [b[dent:] for b in body]
            return ("\n".join(body) if v[0] == "|" else " ".join(b.strip() for b in body)), j
        if v[:1] in "\"'":  # quoted, possibly over several lines
            q, j, acc = v[0], lno, v
            while not self._closed(acc, q) and j + 1 < len(self.lines):
                j += 1
                acc += " " + self.lines[j].strip()
            body = acc[1:acc.rfind(q)] if acc.rfind(q) > 0 else acc[1:]
            return Q(body.replace('\\"', '"') if q == '"' else body.replace("''", "'")), j + 1
        if v[:1] in "{[" and not v.startswith("{{"):  # flow collection (a Helm `{{ … }}` value is a plain scalar)
            j, acc = lno, v
            while acc.count(v[0]) > acc.count("}" if v[0] == "{" else "]") and j + 1 < len(self.lines):
                j += 1
                acc += " " + self.lines[j].strip()
            return flow(acc), j + 1
        v = re.sub(r"\s+#.*$", "", v)  # inline comment
        j = lno + 1
        while j < len(self.lines):  # plain multi-line continuation
            s = self.lines[j].strip()
            if not s or s.startswith("#") or self.ind(j) <= n or s.startswith("- "):
                break
            v += " " + re.sub(r"\s+#.*$", "", s)
            j += 1
        return v, j

    @staticmethod
    def _closed(acc, q):
        body = acc[1:]
        if q == "'":
            return body.replace("''", "").count("'") >= 1
        return re.search(r'(?<!\\)"', body) is not None


def flow(s):
    s = s.strip()
    if s[:1] not in "{[" or s.startswith("{{") or len(s) < 2:
        return Q(s[1:-1]) if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'" else s  # one matching quote pair only
    inner, parts, depth, cur, q = s[1:-1], [], 0, "", None
    for ch in inner:
        if q:
            cur += ch
            q = None if ch == q else q
        elif ch in "\"'":
            q = ch
            cur += ch
        elif ch in "{[":
            depth += 1
            cur += ch
        elif ch in "}]":
            depth -= 1
            cur += ch
        elif ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    if s[0] == "[":
        return [flow(p) for p in parts]
    out = {"__lines__": {}}
    for p in parts:
        k, _, v = p.partition(":")
        out[k.strip().strip("\"'")] = flow(v.strip())
    return out


def load(text):
    docs, d = [], Doc(text)
    i = 0
    while i < len(d.lines):
        v, j = d.block(i, 0)
        if v is not None:
            docs.append(v)
        j = d.sig(j)
        i = j + 1 if j < len(d.lines) and d.lines[j].strip() == "---" else max(j, i + 1)
    return docs


# ---------------------------------------------------------------- PromQL tokens ---------------
FUNCS_RATE = {"rate", "irate", "increase", "delta", "idelta", "deriv", "changes", "resets"}
KW = {"by", "without", "on", "ignoring", "group_left", "group_right", "bool", "and", "or", "unless",
      "offset", "inf", "nan", "Inf", "NaN", "atan2"}
DUR = re.compile(r"(\d+)(ms|s|m|h|d|w|y)")
UNIT = {"ms": 0.001, "s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800, "y": 31536000}
RESOURCE = re.compile(r"^(node_|container_(cpu|memory|fs)|process_(cpu|resident)|kube_pod_container_status_restarts|machine_)")
EXPORTER = ("up", "ALERTS", "scrape_", "process_", "nodejs_", "go_", "node_", "container_", "kube_",
            "kubelet_", "prometheus_", "alertmanager_", "probe_", "http_server_", "jvm_", "python_")


def secs(d):
    """A Prometheus duration ("1h30m", "0s", "0") in seconds; None when absent or unparseable."""
    if d is None or str(d).strip() == "":
        return None
    parts = DUR.findall(str(d))
    return sum(int(a) * UNIT[b] for a, b in parts) if parts else (0 if str(d).strip() == "0" else None)


def tokens(expr):
    e = re.sub(r"\{\{.*?\}\}", "0", expr)  # Helm / Go templates
    e = re.sub(r"#[^\n]*", "", e)
    sels = re.findall(r"([a-zA-Z_:][a-zA-Z0-9_:]*)?\{([^}]*)\}(\[[^\]]*\])?", e)
    ranges = re.findall(r"\[(\d+[a-z0-9]*)(?::(\d+[a-z0-9]*)?)?\]", e)
    funcs = set(f for f in re.findall(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\(", e) if f not in KW)
    bare = re.sub(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', '""', e)
    bare = re.sub(r"\{[^}]*\}", " ", bare)
    bare = re.sub(r"\b(by|without|on|ignoring|group_left|group_right)\s*\([^)]*\)", " ", bare)
    bare = re.sub(r"\[[^\]]*\]", " ", bare)
    bare = re.sub(r"\boffset\s+-?\d+\w*", " ", bare)
    metrics = []
    for m in re.finditer(r"(?<![\w.])([a-zA-Z_:][a-zA-Z0-9_:]*)\b(?!\s*\()", bare):
        t = m.group(1)
        if t not in KW and t not in metrics and not re.fullmatch(r"\d+\w*", t):
            metrics.append(t)
    for _, body, _ in sels:
        n = re.search(r'__name__\s*=\s*"([^"]+)"', body)
        if n and n.group(1) not in metrics:
            metrics.append(n.group(1))
    return {"metrics": metrics, "functions": sorted(funcs), "selectors": sels, "ranges": ranges,
            "comparison": bool(re.search(r"(==|!=|>=|<=|(?<![=!<>])>(?!=)|(?<![=<>])<(?![=-]))", bare))}


AGG = r"\b(?:sum|avg|min|max|count|group|stddev|stdvar|topk|bottomk|quantile|count_values)\b"


def kept_labels(e):
    """Labels an alert's result keeps when every aggregation at paren depth 0 has a `by` list; else None."""
    def depth(pos):
        return e[:pos].count("(") - e[:pos].count(")")
    aggs = [m for m in re.finditer(AGG + r"\s*(?=by\b|without\b|\()", e) if depth(m.start()) == 0]
    if not aggs or re.search(r"\b(without|group_left|group_right)\b", e):
        return None
    keep = set()
    for m in aggs:
        t = e[m.end():]
        b = re.match(r"\s*by\s*\(([^)]*)\)", t)
        if not b:  # `sum(...) by (x)` form: skip the balanced argument first
            d, j = 0, 0
            for j, ch in enumerate(t):
                d += (ch == "(") - (ch == ")")
                if d == 0 and ch == ")":
                    break
            b = re.match(r"\s*by\s*\(([^)]*)\)", t[j + 1:])
        if not b:
            return None
        keep |= set(x.strip() for x in b.group(1).split(",") if x.strip())
    return keep


# ---------------------------------------------------------------- rows ------------------------
def walk(node, path, file, doc_meta, rows):
    if isinstance(node, dict):
        g = node.get("groups")
        if isinstance(g, list) and any(isinstance(x, dict) and isinstance(x.get("rules"), list) for x in g):
            for grp in g:
                if isinstance(grp, dict) and isinstance(grp.get("rules"), list):
                    group_rows(grp, file, doc_meta, rows, bool(path) or doc_meta.get("kind", "rules") != "rules")
            return
        for k, v in node.items():
            if not k.startswith("__"):
                walk(v, path + [k], file, doc_meta, rows)
    elif isinstance(node, list):
        for v in node:
            walk(v, path, file, doc_meta, rows)


def group_rows(grp, file, doc_meta, rows, embedded):
    glabels = {k: str(v) for k, v in (grp.get("labels") or {}).items() if not k.startswith("__")} \
        if isinstance(grp.get("labels"), dict) else {}
    for r in grp["rules"]:
        if not isinstance(r, dict):
            continue
        kind = "alert" if "alert" in r else "record" if "record" in r else None
        if not kind:
            continue
        labels = {k: str(v) for k, v in (r.get("labels") or {}).items() if not k.startswith("__")} \
            if isinstance(r.get("labels"), dict) else {}
        ann = {k: str(v) for k, v in (r.get("annotations") or {}).items() if not k.startswith("__")} \
            if isinstance(r.get("annotations"), dict) else {}
        expr = str(r.get("expr", ""))
        tk = tokens(expr)
        rows.append({
            "file": file, "line": r.get("__line__"), "group": str(grp.get("name", "")), "kind": kind,
            "name": str(r[kind]), "group_interval": grp.get("interval"), "embedded": embedded, "doc_kind": doc_meta.get("kind", "rules"), "doc_labels": doc_meta.get("labels", {}),
            "for": r.get("for"), "keep_firing_for": r.get("keep_firing_for"), "labels": labels,
            "group_labels": glabels, "annotation_keys": sorted(ann), "annotations": ann, "expr": expr,
            "metrics": tk["metrics"], "functions": tk["functions"], "comparison": tk["comparison"],
            "windows": sorted(set(a for a, _ in tk["ranges"])),
            "value_in_labels": any(re.search(r"\$value|\.Value\b", v) for v in labels.values()),
            "_tk": tk, "problems": []})


def read_rules(paths):
    files, rows = [], []
    for p in paths:
        if os.path.isdir(p):
            for dp, dn, fn in os.walk(p):
                dn[:] = [d for d in dn if d not in ("node_modules", ".git", "vendor")]
                files += [os.path.join(dp, f) for f in fn if f.endswith((".yml", ".yaml"))]
        else:
            files.append(p)
    for f in sorted(files):
        try:
            text = open(f, encoding="utf-8", errors="replace").read()
        except OSError as e:
            sys.exit(f"rule-inventory: cannot read {f}: {e}")
        try:
            docs = load(text)
        except (IndexError, ValueError, RecursionError) as e:  # never let one odd file hide the rest
            print(f"rule-inventory: {f}: not parsed ({type(e).__name__}) — read it by hand", file=sys.stderr)
            rows.append({"file": f, "line": 0, "kind": "file", "name": "(unparsed)", "problems": [
                {"code": "PARSE", "severity": "note", "section": 0, "message": "blocked (file not parsed): read it"}]})
            continue
        for d in docs:
            if not isinstance(d, dict):
                continue
            meta = {"kind": str(d.get("kind", "rules"))}
            md = d.get("metadata") if isinstance(d.get("metadata"), dict) else {}
            if isinstance(md.get("labels"), dict):
                meta["labels"] = {k: str(v) for k, v in md["labels"].items() if not k.startswith("__")}
            walk(d, [], f, meta, rows)
    return rows


# ---------------------------------------------------------------- checks ----------------------
def add(r, code, sev, sect, msg):
    r["problems"].append({"code": code, "severity": sev, "section": sect, "message": msg})


def is_burn(r):
    e = r["expr"]
    if not re.search(r"\band\b", e):
        return False
    wins = set(a for a, _ in r["_tk"]["ranges"])
    sfx = set(m.group(1) for t in r["metrics"] for m in [re.search(r"(\d+[smhdw])$", t)] if m)
    return len(wins) >= 2 or len(sfx) >= 2


def is_watchdog(r):
    return re.fullmatch(r"\s*vector\(\s*1\s*\)\s*", r["expr"]) is not None


def sev_of(r, o):
    s = r["labels"].get("severity")
    if s is None and o["group_labels"] != "no":
        s = r["group_labels"].get("severity")
    return s


def jobs_of(r):
    return set(re.findall(r'\bjob\s*=\s*"([^"]+)"', r["expr"]))


def check(rows, o):
    if o["prom_major"] == "2":  # promtool 2.55.1 rejects group `labels:`; 3.15.0 applies them (run 2026-10-10)
        o["group_labels"] = "no"
        bad = {r["file"] for r in rows if r.get("group_labels") and not r["embedded"]}
        for r in rows:
            if r["file"] in bad:
                add(r, "AL-22", "H", 4, "its file has a group-level `labels:`: on Prometheus 2.x the whole file fails to load")
    alerts = [r for r in rows if r["kind"] == "alert"]
    recorded = set(r["name"] for r in rows if r["kind"] == "record")
    page = set(o["page_severities"])
    for r in alerts:
        sv = sev_of(r, o)
        tier = "page" if sv in page else "unknown" if sv is None else "ticket"
        r["tier"], r["severity"] = tier, sv
        gl = " (group label; [K?] on this version, precedents § 41)" if "severity" not in r["labels"] and sv else ""
        c, e = o["checks"], r["expr"]
        burn, wd = is_burn(r), is_watchdog(r)
        if "for" in c:
            f = secs(r["for"]) if r["for"] is not None else 0
            if not f and not wd and not burn:
                add(r, "AL-01", "M" if tier == "page" else "L", 1, f"{tier} alert with no `for` (a one-sample spike fires)")
            if tier == "page" and f and f >= secs(o["page_for_max"]) and "predict_linear" not in r["functions"] and not burn:
                add(r, "AL-02", "M", 1, f"page `for: {r['for']}` ≥ THR-OBS-ALERT.page_for_max {o['page_for_max']}")
            k = secs(r["keep_firing_for"]) if r["keep_firing_for"] else 0
            if k and (k > (f or 0) or (tier == "page" and k > 1800)):
                add(r, "AL-09", "M" if tier == "page" else "L", 1, f"keep_firing_for {r['keep_firing_for']} exceeds for {r['for']} or 30m")
        if "annotations" in c:
            if sv is None:
                add(r, "AL-03", "M", 2, "no `severity` label (routes on it fall to the root receiver)")
            elif sv not in o["vocab"]:
                add(r, "AL-03", "M", 2, f"severity `{sv}` outside the vocabulary {sorted(o['vocab'])}{gl}")
            has_rb = any(k in r["annotations"] for k in ("runbook_url", "runbook"))
            if not has_rb and not wd:
                add(r, "AL-04", {"page": "M", "unknown": "L"}.get(tier, "hardening"), 2,
                    "page without runbook_url" + gl if tier == "page" else "no severity, so the tier is unknown, and no runbook"
                    if tier == "unknown" else "non-page alert without runbook (precedents § 1)")
            if not any(k in r["annotations"] for k in ("summary", "description", "message")):
                add(r, "AL-04", "L", 2, "no summary / description annotation")
            keep = kept_labels(e)
            if keep is not None:
                keep |= set(r["labels"])
                for v in r["annotations"].values():
                    for lab in re.findall(r"\$labels\.(\w+)|\.Labels\.(\w+)", v):
                        lab = lab[0] or lab[1]
                        if lab not in keep:
                            add(r, "AL-05", "L", 2, f"annotation reads $labels.{lab}, dropped by `by ({', '.join(sorted(keep - set(r['labels'])))})`")
        if "value-in-labels" in c and r["value_in_labels"]:
            add(r, "AL-06", "H", 2, "$value in labels: every new value is a new alert, so `for` never completes")
        if "expr" in c and not wd:
            fns = set(r["functions"])
            if not r["comparison"] and "absent" not in fns and "absent_over_time" not in fns:
                add(r, "AL-07", "M", 3, "no comparison operator: fires whenever the series exists")
            raw = [m for m in r["metrics"] if re.search(r"_(total|count|bucket)$", m) and m not in recorded]
            if raw and r["comparison"] and not (fns - {"sum", "max", "min", "avg"}):
                add(r, "AL-08", "M", 3, f"raw counter {raw[0]} compared without rate/increase")
            if re.search(r"\b(?:rate|irate|increase)\s*\(\s*(?:sum|avg|max|min|count)\b", e):
                add(r, "AL-13", "M", 3, "rate over an aggregation (`rate(sum(…))`): resets are no longer visible")
            if "irate" in fns:
                add(r, "AL-14", "L", 3, "irate in an alert (two-sample, flaps)")
            if re.search(r"\bincrease\s*\([^)]*\)\s*\)?\s*==", e):
                add(r, "AL-15", "L", 3, "increase(…) == N: extrapolated, rarely an integer")
            for m in re.finditer(r"histogram_quantile\s*\(", e):
                inner, d, j = "", 1, m.end()
                while j < len(e) and d:
                    d += (e[j] == "(") - (e[j] == ")")
                    inner += e[j]
                    j += 1
                lists = re.findall(r"\b(?:by|without)\s*\(([^)]*)\)", inner)
                if "_bucket" in inner and (not lists or not any("le" in [x.strip() for x in l.split(",")] for l in lists)) \
                        and not re.search(r"without\s*\(", inner):
                    add(r, "AL-20", "M", 3, "histogram_quantile over an aggregation that drops `le`")
        if "windows" in c:
            jobs_iter = r["_tk"]["selectors"] or []
            for name, body, rng in jobs_iter:
                if not rng:
                    continue
                w = re.match(r"\[(\d+[a-z0-9]*)(?::(\d*[a-z0-9]*))?\]", rng)
                job = re.search(r'\bjob\s*=\s*"([^"]+)"', body)
                sc = o["scrape"].get(job.group(1)) if job else None
                sc = sc or o["scrape"].get("__default__")
                ws = secs(w.group(1)) if w else None
                if not (sc and ws):
                    continue
                tag = f"[{w.group(1)}] on job {job.group(1) if job else '(global)'} scraped every {sc}s"
                if ws < 2 * sc:
                    add(r, "AL-12", "H", 5, f"window {tag}: under 2× (THR-OBS-RATE-WINDOW)" + ("; exactly 1× is empty on Prometheus 3" if ws == sc else ""))
                elif ws < 4 * sc:
                    add(r, "AL-12", "hardening", 5, f"window {tag}: 2–4× is style (precedents § 6)")
        if "prom3" in c:
            hits = []
            if re.search(r'\ble\s*=\s*"\d+"', e):
                hits.append('integer `le="N"` matches nothing (values are floats)')
            for a, b in r["_tk"]["ranges"]:
                if b and secs(a) == secs(b):
                    hits.append(f"subquery [{a}:{b}] is empty (left-open ranges)")
            if "holt_winters" in r["functions"]:
                hits.append("holt_winters is double_exponential_smoothing behind a feature flag")
            for h in hits:
                if o["prom_major"] == "3":
                    add(r, "AL-21", "H", 5, h + " (Prometheus 3, read from file)")
                elif o["prom_major"] is None:
                    add(r, "AL-21", "note", 5, h + " — Prometheus version unread: Unconfirmed (gate 3, precedents § 17)")
        if "absent" in c and ("absent" in r["functions"]):
            if not r["for"]:
                add(r, "AL-17", "M", 6, "absent() with no `for` (fires on the first missed scrape and on restarts)")
            if re.search(r'absent\s*\([^)]*=~', e):
                add(r, "AL-17", "M", 6, "absent() with a regex matcher: one surviving match hides every missing target")
        if "design" in c and tier == "page":
            ms = [m for m in r["metrics"] if m not in recorded]
            if ms and all(RESOURCE.match(m) for m in ms) and "predict_linear" not in r["functions"]:
                add(r, "SY-01", "M", 7, "page on a cause (resource metrics only); precedents § 4 needs definite and imminent")
            if re.search(r"rate\(\s*\w+_sum\b[^/]*/\s*rate\(\s*\w+_count\b", e):
                add(r, "SY-03", "L", 7, "latency page on the mean (rate(_sum)/rate(_count))")
            if re.search(r"\bby\s*\([^)]*\b(instance|pod)\b", e):
                add(r, "SY-04", "L", 7, "page per instance/pod: N replicas → N pages")
    if "nan" in o["checks"]:
        for r in alerts:
            ex = re.sub(r'"(?:[^"\\]|\\.)*"', '""', r["expr"])  # a `/` inside a matcher string is not a division
            if "/" not in ex or not re.search(r"\b(rate|irate|increase)\s*\(", ex.split("/", 1)[1]):
                continue
            den = tokens(ex.split("/", 1)[1])["metrics"]
            if den and all(RESOURCE.match(m) for m in den):  # a host counter (node_*) never drops to zero traffic
                continue
            jb = jobs_of(r)
            sib = [s for s in alerts if s is not r and (re.search(r"==\s*0\b|\babsent(_over_time)?\s*\(", s["expr"]))
                   and ((jb and jobs_of(s) & jb) or set(s["metrics"]) & set(den))]
            if not sib:
                add(r, "AL-16", "M" if r.get("tier") == "page" else "L", 6,
                    "ratio of rates with no traffic-absent / zero-traffic sibling: NaN at zero traffic never fires (precedents § 5)")
    if "watchdog" in o["checks"] and alerts and not any(is_watchdog(r) for r in alerts):
        rows.append({"file": "-", "line": 0, "kind": "repo", "name": "(all rule files)", "problems": [
            {"code": "AL-18", "severity": "M", "section": 6, "message": "no `vector(1)` Watchdog: a dead pipeline looks like a quiet one"}]})
    if "design" in o["checks"] and alerts and all(r.get("tier") == "page" for r in alerts):
        rows.append({"file": "-", "line": 0, "kind": "repo", "name": "(all alerts)", "problems": [
            {"code": "SY-02", "severity": "M", "section": 7, "message": "every alert pages: no ticket tier"}]})
    if "selectors" in o["checks"]:
        selectors(rows, alerts, recorded, o)


def grounded(m, inv, recorded):
    if m in recorded or m in inv:
        return "inventory" if m in inv else "recorded"
    base = re.sub(r"_(bucket|sum|count|created|total|info)$", "", m)
    if base in inv or base + "_total" in inv:
        return "inventory"
    for n in inv:  # OTel dotted names, translated with suffixes [K?] (precedents § 43)
        t = re.sub(r"[^a-zA-Z0-9_:]", "_", n)
        if m.startswith(t) and re.fullmatch(r"(_[a-z]+)?(_total|_bucket|_sum|_count)?", m[len(t):]):
            return "translated [K?]"
    if m.startswith(EXPORTER) or m in EXPORTER:
        return "exporter-default (unverified)"
    for n in inv:  # client_golang Namespace/Subsystem prefixes are not in the Name literal
        if "." not in n and re.fullmatch(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)?_" + re.escape(n), m):
            return "suffix-only [K?]"
    return None


def selectors(rows, alerts, recorded, o):
    if o["inventory"] is None:
        rows.append({"file": "-", "line": 0, "kind": "repo", "name": "(selectors)", "problems": [
            {"code": "AL-10", "severity": "note", "section": 4, "message": "blocked (no --inventory): selectors not grounded"}]})
    else:
        for r in alerts:
            for m in r["metrics"]:
                g = grounded(m, o["inventory"], recorded)
                r.setdefault("grounding", {})[m] = g or "UNGROUNDED"
                if g == "suffix-only [K?]":
                    add(r, "AL-10", "L", 4, f"{m} grounds only by suffix: read the Namespace/Subsystem of the registration")
                if g is None:
                    add(r, "AL-10", "H" if r.get("tier") == "page" else "M", 4,
                        f"{m} resolves in no inventory: never-fire candidate (HIGH Unconfirmed until a live count())")
    cfg = o["prom_cfg"]
    if cfg:
        base = os.path.dirname(cfg["path"])
        globs = [os.path.normpath(os.path.join(base, g)) for g in cfg.get("rule_files", [])]
        for r in rows:
            if r.get("kind") in ("alert", "record") and not r["embedded"]:
                if not any(fnmatch.fnmatch(os.path.normpath(r["file"]), g) for g in globs):
                    add(r, "AL-22", "H" if r.get("tier") == "page" else "M", 4, f"file matched by no rule_files glob {cfg.get('rule_files')}: never loaded")
    sel = o["rule_selector"]
    if sel is not None:
        for r in rows:
            if r.get("doc_kind") == "PrometheusRule":
                miss = {k: v for k, v in sel.items() if r["doc_labels"].get(k) != v}
                if miss:
                    add(r, "AL-22", "H" if r.get("tier") == "page" else "M", 4,
                        f"PrometheusRule labels {r['doc_labels']} miss ruleSelector {sel}: never loaded")


ROUTE_KEYS = ("severity", "team", "service", "owner", "squad", "priority")
PAGER = ("pagerduty_configs", "opsgenie_configs", "victorops_configs", "pushover_configs", "incidentio_configs")


def am_config(docs):
    """The Alertmanager config map: top level, or embedded (Helm `alertmanager.config`, a Secret's string excluded)."""
    stack = list(docs)
    while stack:
        n = stack.pop(0)
        if isinstance(n, dict):
            if isinstance(n.get("route"), dict) and isinstance(n.get("receivers"), list):
                return n
            stack += [v for k, v in n.items() if not k.startswith("__")]
        elif isinstance(n, list):
            stack += n
    return {}


def typed(n):
    """The parsed tree as JSON-ready data: plain scalars typed the way YAML would, quoted ones kept as text."""
    if isinstance(n, dict):
        return {k: typed(v) for k, v in n.items() if not k.startswith("__")}
    if isinstance(n, list):
        return [typed(v) for v in n]
    if isinstance(n, Q) or not isinstance(n, str):
        return str(n) if isinstance(n, Q) else n
    if n in ("true", "false"):
        return n == "true"
    if n in ("null", "~", ""):
        return None
    return int(n) if re.fullmatch(r"-?\d+", n) else float(n) if re.fullmatch(r"-?\d+\.\d*", n) else n


def alertmanager(path, alerts, o):
    out = []
    d = am_config(load(open(path).read()))
    recv = {x["name"]: x for x in d.get("receivers") or [] if isinstance(x, dict) and "name" in x}
    null = sorted(n for n, x in recv.items() if not any(k.endswith("_configs") for k in x))
    route = d.get("route") or {}
    if route.get("receiver") in null:
        out.append(("AM-01", "H", 8, f"root route → `{route['receiver']}` (no *_configs): every unmatched label set vanishes; prove each emitted set with amtool --verify.receivers (precedents § 9)"))

    used, pagers = {route.get("receiver")}, {n for n, x in recv.items() if any(k in x for k in PAGER)}

    def walk_routes(rt, inh):
        for c in rt.get("routes") or []:
            if isinstance(c, dict):
                cur = {k: c.get(k, inh[k]) for k in inh}
                used.add(cur["receiver"])
                for k in ("match", "match_re"):
                    if k in c:
                        out.append(("AM-08", "L", 8, f"deprecated `{k}` at line {c['__lines__'].get(k)} (precedents § 7)"))
                if cur["receiver"] in pagers:
                    gw, ri = secs(cur["group_wait"]), secs(cur["repeat_interval"])
                    if gw is not None and gw > secs(o["group_wait_page_max"]):
                        out.append(("AM-04", "M", 8, f"pager route line {c['__line__']}: group_wait {cur['group_wait']} > THR-OBS-ALERT.group_wait_page_max {o['group_wait_page_max']}"))
                    if ri is not None and ri < secs(o["repeat_interval_min"]):
                        out.append(("AM-04", "L", 8, f"pager route line {c['__line__']}: repeat_interval {cur['repeat_interval']} < {o['repeat_interval_min']}"))
                walk_routes(c, cur)
    walk_routes(route, {"receiver": route.get("receiver"), "group_wait": route.get("group_wait", "30s"),
                        "repeat_interval": route.get("repeat_interval", "4h")})
    for n in sorted(set(recv) - used):
        out.append(("AM-06", "L", 8, f"receiver `{n}` is reached by no route (an archive receiver is Hardening)"))
    emitted = set(k for r in alerts for k in list(r["labels"]) + list(r["group_labels"]))
    for ir in d.get("inhibit_rules") or []:
        if isinstance(ir, dict):
            miss = [x for x in ir.get("equal") or [] if x not in emitted]
            if miss:
                out.append(("AM-03", "M", 8, f"inhibit_rules line {ir.get('__line__')}: `equal: {miss}` is emitted by no rule (empty == empty, so it mutes across every scope)"))
    return out, null


# ---------------------------------------------------------------- CLI ------------------------
def opts(argv):
    o = {"checks": set(), "format": "json", "inventory": None, "prom_cfg": None, "rule_selector": None,
         "scrape": {}, "prom_major": None, "group_labels": "unknown", "page_severities": ["page", "critical"],
         "vocab": {"page", "ticket", "info", "none", "critical", "warning"}, "page_for_max": "30m",
         "group_wait_page_max": "5m", "repeat_interval_min": "30m", "all": False,
         "label_sets": False, "am": None, "emit_am": None, "emit": None, "paths": []}
    allc = {"annotations", "for", "windows", "selectors", "prom3", "value-in-labels", "nan", "absent", "watchdog", "expr", "design"}
    for a in argv:
        k, _, v = a.partition("=")
        if k == "--check":
            o["checks"] = allc if v == "all" else set(v.split(","))
            if o["checks"] - allc:
                sys.exit(f"rule-inventory: unknown check {sorted(o['checks'] - allc)}")
        elif k == "--format": o["format"] = v
        elif k == "--inventory":
            o["inventory"] = set(x.strip() for x in open(v) if x.strip() and not x.startswith("#"))
        elif k == "--prometheus-config":
            d = (load(open(v).read()) or [{}])[0]
            o["prom_cfg"] = {"path": v, "rule_files": [str(x) for x in d.get("rule_files") or []]}
            gs = secs((d.get("global") or {}).get("scrape_interval", "1m"))
            o["scrape"].setdefault("__default__", gs)
            for sc in d.get("scrape_configs") or []:
                if isinstance(sc, dict) and "job_name" in sc:
                    o["scrape"].setdefault(str(sc["job_name"]), secs(sc.get("scrape_interval")) or gs)
        elif k == "--prometheus-cr":
            for d in load(open(v).read()):
                if isinstance(d, dict) and d.get("kind") == "Prometheus":
                    rs = (d.get("spec") or {}).get("ruleSelector")
                    o["rule_selector"] = {} if rs is None else {k2: str(v2) for k2, v2 in (rs.get("matchLabels") or {}).items() if not k2.startswith("__")}
        elif k == "--scrape":
            for p in v.split(","):
                j, _, s = p.partition("=")
                o["scrape"][j if j != "*" else "__default__"] = secs(s)
        elif k == "--prom-major": o["prom_major"] = v
        elif k == "--group-labels": o["group_labels"] = v
        elif k == "--page-severities": o["page_severities"] = v.split(",")
        elif k == "--severity-vocab": o["vocab"] = set(v.split(","))
        elif k == "--page-for-max": o["page_for_max"] = v
        elif k == "--label-sets": o["label_sets"] = True
        elif k == "--am": o["am"] = v
        elif k == "--emit-am": o["emit_am"] = v
        elif k == "--emit-rules": o["emit"] = v
        elif k == "--all": o["all"] = True
        elif a.startswith("--"):
            sys.exit(f"rule-inventory: unknown flag {a}")
        else:
            o["paths"].append(a)
    if not o["checks"]:
        o["checks"] = allc
    return o


def emit(rows, out):
    os.makedirs(out, exist_ok=True)
    by = {}
    for r in rows:
        if r.get("kind") in ("alert", "record") and r["embedded"]:  # plain files are copied as they are
            by.setdefault((r["file"], r["group"]), []).append(r)
    for i, ((f, g), rs) in enumerate(sorted(by.items())):
        L = ["groups:", f"- name: {json.dumps(g)}"] + ([f"  interval: {rs[0]['group_interval']}"] if rs[0]["group_interval"] else [])
        if rs[0]["group_labels"]:
            L.append("  labels: " + json.dumps(rs[0]["group_labels"]))
        L.append("  rules:")
        for r in rs:
            L.append(f"  - {r['kind']}: {json.dumps(r['name'])}")
            L.append(f"    expr: {json.dumps(r['expr'])}")
            for k in ("for", "keep_firing_for"):
                if r[k]:
                    L.append(f"    {k}: {r[k]}")
            for k in ("labels", "annotations"):
                if r[k]:
                    L.append(f"    {k}: {json.dumps(r[k])}")
        open(os.path.join(out, f"{i:03d}-{os.path.basename(f).rsplit('.', 1)[0]}.yml"), "w").write("\n".join(L) + "\n")


def run(argv):
    o = opts(argv)
    if not o["paths"]:
        print(__doc__, file=sys.stderr)
        return 2
    rows = read_rules(o["paths"])
    check(rows, o)
    alerts = [r for r in rows if r.get("kind") == "alert"]
    if o["am"]:
        probs, _ = alertmanager(o["am"], alerts, o)
        rows.append({"file": o["am"], "line": 0, "kind": "alertmanager", "name": "(route tree)",
                     "problems": [{"code": c, "severity": s, "section": n, "message": m} for c, s, n, m in probs]})
    if o["emit"]:
        emit(rows, o["emit"])
    if o["emit_am"] and o["am"]:  # an embedded config (Helm alertmanager.config) as a file amtool can read
        open(o["emit_am"], "w").write(json.dumps(typed(am_config(load(open(o["am"]).read()))), indent=1) + "\n")
    if o["label_sets"]:
        sets = set()
        for r in alerts:  # one routes-test case per emitted label set; a Watchdog routes by alertname
            lab = {k: v for k, v in {**r["group_labels"], **r["labels"]}.items() if k in ROUTE_KEYS}
            if is_watchdog(r):
                lab["alertname"] = r["name"]
            sets.add(" ".join(f"{k}={v}" for k, v in sorted(lab.items())) or "(no routing labels)")
        print("\n".join(sorted(sets)))
        return 0
    bad = 0
    for r in rows:
        r.pop("_tk", None)
        bad += sum(p["severity"] in ("H", "M", "L") for p in r["problems"])
        if o["format"] == "text":
            for p in r["problems"]:
                if p["severity"] not in ("H", "M", "L") and not o["all"]:
                    continue
                print(f"{r['file']}:{r['line']}  {r['kind']} {r['name']}  §{p['section']} {p['code']} [{p['severity']}]  {p['message']}")
        else:
            print(json.dumps(r, sort_keys=True))
    print(f"rule-inventory: {len(alerts)} alerts, {sum(r.get('kind') == 'record' for r in rows)} recording rules, "
          f"{bad} problems (H/M/L), {sum(p['severity'] in ('hardening', 'note') for r in rows for p in r['problems'])} hardening/notes"
          f"{'' if o['all'] or o['format'] == 'json' else ' (text hides them; --all shows them)'} — checks: {','.join(sorted(o['checks']))}", file=sys.stderr)
    return 1 if bad else 0


SELF = {
    "mixed.yaml": "groups:\n- name: g1\n  rules:\n  - alert: A\n    expr: sum(rate(x_total[5m])) > 1\n    for: 5m\n"
                  "    labels:\n      severity: page\n    annotations:\n      summary: a\n      runbook_url: x\n"
                  "  - alert: B\n    expr: sum(rate(x_total[5m])) > 2\n    annotations:\n      summary: b\n"
                  "      # runbook_url: x\n- name: g2\n  labels:\n    severity: page\n  rules:\n  - alert: C\n"
                  "    expr: |\n      sum(rate(x_total[5m]))\n        > 3\n    annotations: {summary: c}\n",
    "crd.yaml": "apiVersion: monitoring.coreos.com/v1\nkind: PrometheusRule\nmetadata:\n  labels:\n    release: kps\n"
                "spec:\n  groups:\n    - name: g3\n      rules:\n        - alert: D\n          expr: >-\n"
                "            sum(rate(x_total[5m]))\n            > 4\n          for: 10m\n          labels:\n"
                "            severity: ticket\n          annotations:\n            summary: d\n---\nkind: PrometheusRule\n"
                "metadata: {labels: {release: monitoring}}\nspec:\n  groups:\n  - name: wd\n    rules:\n"
                "    - alert: Watchdog\n      expr: vector(1)\n      labels: {severity: none}\n      annotations: {summary: w}\n",
    "burn.yaml": "groups:\n- name: pyrra\n  rules:\n  - record: x:burnrate5m\n    expr: sum(rate(e_total[5m])) / sum(rate(t_total[5m]))\n"
                 "  - record: x:burnrate1h\n    expr: sum(rate(e_total[1h])) / sum(rate(t_total[1h]))\n"
                 "  - alert: ErrorBudgetBurn\n    expr: x:burnrate5m > (14 * (1-0.99)) and x:burnrate1h > (14 * (1-0.99))\n"
                 "    labels: {severity: critical}\n    annotations: {summary: s, runbook_url: r}\n"
                 "  - alert: Wb4\n    expr: sum(rate(e_total[1d])) / sum(rate(t_total[1d])) > (3 * 0.001) and sum(rate(e_total[2h])) / sum(rate(t_total[2h])) > (3 * 0.001)\n"
                 "    labels: {severity: ticket}\n    annotations: {summary: s}\n"
                 "  - alert: Bad\n    expr: rate(sum(t_total)[5m:5m]) > 1 or y_total{le=\"1\"} > 0\n    labels:\n      severity: page\n      v: '{{ $value }}'\n"
                 "    annotations: {summary: '{{ $labels.instance }}', runbook_url: r}\n"
                 "  - alert: Ratio\n    expr: sum by (job) (rate(e_total{job=\"api\"}[30s])) / sum by (job) (rate(t_total{job=\"api\"}[30s])) > 0.1\n"
                 "    for: 5m\n    labels: {severity: page}\n    annotations: {summary: '{{ $labels.instance }}', runbook_url: r}\n"
                 "  - alert: Gone\n    expr: absent(up{job=~\"api.*\"})\n    labels: {severity: page}\n    annotations: {summary: s, runbook_url: r}\n",
}


def self_test():
    import tempfile
    d = tempfile.mkdtemp(prefix="rule-inventory-")
    for n, t in SELF.items():
        open(os.path.join(d, n), "w").write(t)
    o = opts(["--check=all", "--prom-major=3", "--scrape=job=30s,api=30s,*=15s"])
    o["inventory"], o["rule_selector"] = {"x_total", "t_total", "e_total"}, {"release": "monitoring"}
    rows = read_rules([d])
    check(rows, o)
    got = {}
    for r in rows:
        for p in r["problems"]:
            got.setdefault(r["name"], set()).add((p["code"], p["severity"]))
    want = {
        "B": {("AL-03", "M"), ("AL-04", "L"), ("AL-01", "L")},                  # all three, from its own keys only
        "C": {("AL-04", "M"), ("AL-01", "M")},                                   # severity from its group (page)
        "D": {("AL-04", "hardening"), ("AL-22", "M")},                           # ticket: precedent 1; kps ≠ selector
        "Bad": {("AL-06", "H"), ("AL-13", "M"), ("AL-21", "H"), ("AL-01", "M"), ("AL-10", "H")},
        "Ratio": {("AL-12", "H"), ("AL-16", "M"), ("AL-05", "L")},
        "Gone": {("AL-17", "M"), ("AL-01", "M")},
    }
    ok = True
    for name, codes in want.items():
        if not codes <= got.get(name, set()):
            ok = False
            print(f"self-test: {name} missing {sorted(codes - got.get(name, set()))}; got {sorted(got.get(name, set()))}")
    for name in ("A", "Watchdog", "ErrorBudgetBurn", "Wb4"):  # controls: precedents § 1, § 2, § 12
        noisy = {c for c in got.get(name, set()) if c[1] in ("H", "M") and c[0] in ("AL-01", "AL-03", "AL-04", "AL-10")}
        if noisy:
            ok = False
            print(f"self-test: control {name} flagged {sorted(noisy)}")
    b = [r for r in rows if r.get("name") == "B"][0]
    if "runbook_url" in b["annotation_keys"] or b["labels"].get("severity"):
        ok = False
        print("self-test: the comment or the next group leaked into B")
    c = [r for r in rows if r.get("name") == "C"][0]
    if "\n" not in c["expr"] or [r for r in rows if r.get("name") == "D"][0]["expr"] != "sum(rate(x_total[5m])) > 4":
        ok = False
        print("self-test: block scalar parse")
    if any(r["name"] == "(all rule files)" for r in rows):
        ok = False
        print("self-test: Watchdog present but AL-18 raised")
    open(os.path.join(d, "am.yml"), "w").write(
        "route:\n  receiver: null\n  routes:\n  - receiver: pd\n    match: {severity: page}\n    group_wait: 10m\n"
        "receivers:\n- name: 'null'\n- name: pd\n  pagerduty_configs:\n  - routing_key: k\n"
        "inhibit_rules:\n- source_matchers: ['severity=\"page\"']\n  equal: [cluster]\n")
    am = {c for c, *_ in alertmanager(os.path.join(d, "am.yml"), [r for r in rows if r.get("kind") == "alert"], o)[0]}
    if am != {"AM-01", "AM-03", "AM-04", "AM-08"}:
        ok = False
        print(f"self-test: alertmanager codes {sorted(am)}")
    print("self-test:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else run(sys.argv[1:]))
