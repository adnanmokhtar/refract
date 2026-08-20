#!/usr/bin/env python3
"""pack-search.py — BM25 retrieval over the repo's row-shaped metadata. Pure stdlib.

WHAT IT ANSWERS: "where is the thing I need?" — which file, which line, which section.
WHAT IT DOES NOT ANSWER: the question itself. Every row is a POINTER at prose, never a
substitute for it. Read the cited `path:line` before acting on any result.

  python3 scripts/pack-search.py "tenant isolation cache key"
  python3 scripts/pack-search.py "focus ring contrast" --pack=ui-ux --kind=rule-directive
  python3 scripts/pack-search.py "guest checkout" --domain=ecommerce --limit=5
  python3 scripts/pack-search.py "repository pattern" --stack=nestjs --format=paths
  python3 scripts/pack-search.py "webhook replay" --json
  python3 scripts/pack-search.py --check          # catalog integrity + retrieval smoke test

The index is built from source markdown by scripts/gen-pack-catalog.py and cached under
`tmp/pack-search/` (already gitignored). The cache is keyed on a fingerprint of every
source file's size+mtime, so an edit invalidates it automatically; `--rebuild` forces.
Nothing is committed, so the catalog cannot drift from the markdown that produced it.

Complements — does NOT replace — `templates/import-tiers.md`:
tiers decide what is RESIDENT, search decides what is REACHABLE. See docs/RETRIEVAL.md.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
import re
import sys
import time
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, ".."))
CACHE_REL = "tmp/pack-search/index.json"
# Bump when tokenizer / weights / row schema change, so stale caches are rejected.
INDEX_FORMAT = 3

K1, B = 1.5, 0.75
FIELD_WEIGHTS = (("name", 3), ("owner", 2), ("kind", 1), ("anchor", 1), ("text", 1))
STACK_BOOST = 1.5
SYNONYM_WEIGHT = 0.6
SNIPPET_LEN = 160
HARD_CAP = 25          # a 50-row dump defeats the point of retrieving rows

TOKEN_RE = re.compile(r"[a-z0-9][a-z0-9_+#.-]*")
STOP = frozenset("""a an and are as at be by for from in into is it its of on or that the
this to with when what which how not no do does you your we our their they""".split())

# Hand-curated, deliberately small. BM25 is LEXICAL — it cannot bridge vocabulary on its
# own. These are the gaps observed on this corpus; the list is not exhaustive and is not
# a substitute for a semantic model. Expansions score at SYNONYM_WEIGHT of a literal hit.
SYNONYMS = {
    "a11y": ["accessibility"], "accessibility": ["a11y"],
    "i18n": ["internationalization", "locale"], "l10n": ["localization", "locale"],
    "rtl": ["bidi", "logical"],
    "authz": ["authorization", "permission"], "authn": ["authentication", "login"],
    "perf": ["performance"], "a11y-audit": ["accessibility"],
    "n+1": ["eager", "batch", "preload"], "nplusone": ["eager", "batch"],
    "token": ["design-token"], "tokens": ["design-token"],
    "multitenant": ["tenant", "multi-tenant"], "multi-tenant": ["tenant"],
    "tenancy": ["tenant"], "rbac": ["role", "permission", "authorization"],
    "pii": ["personal", "privacy", "gdpr"],
    "idempotent": ["idempotency"], "retries": ["retry", "backoff"],
    "sql": ["query", "database"], "orm": ["query", "repository"],
    "e2e": ["end-to-end", "integration"], "ci": ["pipeline", "continuous"],
    "obs": ["observability"], "otel": ["opentelemetry", "tracing"],
    "a11y_contrast": ["contrast"], "keyboard": ["focus", "tab"],
    "darkmode": ["dark-mode", "theme"], "theming": ["theme"],
    "migration": ["migrate"], "webhooks": ["webhook"],
}


# ---------------------------------------------------------------------------
# catalog module (filename is hyphenated, so import it by path)
# ---------------------------------------------------------------------------
def load_catalog_module():
    path = os.path.join(HERE, "gen-pack-catalog.py")
    spec = importlib.util.spec_from_file_location("pack_catalog", path)
    if spec is None or spec.loader is None:
        raise SystemExit("pack-search: cannot load %s" % path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# tokenizer
# ---------------------------------------------------------------------------
def tokenize(text):
    out = []
    for raw in TOKEN_RE.findall((text or "").lower()):
        t = raw.strip(".-")
        if not t or len(t) < 2 or t in STOP:
            continue
        out.append(t)
        # Emit kebab/snake/dot sub-tokens so `prefers-reduced-motion` also matches `motion`
        # and `design-token` also matches `token`.
        if re.search(r"[-_./]", t):
            for part in re.split(r"[-_./]+", t):
                if len(part) > 2 and part not in STOP and part != t:
                    out.append(part)
    return out


def expand_query(text):
    """[(term, weight)] — literals at 1.0, curated synonyms at SYNONYM_WEIGHT."""
    weights = {}
    for t in tokenize(text):
        weights[t] = max(weights.get(t, 0.0), 1.0)
        for syn in SYNONYMS.get(t, ()):
            for s in tokenize(syn):
                weights[s] = max(weights.get(s, 0.0), SYNONYM_WEIGHT)
    return sorted(weights.items())


# ---------------------------------------------------------------------------
# index
# ---------------------------------------------------------------------------
def fingerprint(catalog, root):
    h = hashlib.sha256()
    h.update(b"pack-search/%d\n" % INDEX_FORMAT)
    for p in (os.path.join(HERE, "gen-pack-catalog.py"), os.path.abspath(__file__)):
        st = os.stat(p)
        h.update(("%s|%d|%d\n" % (os.path.basename(p), st.st_size, st.st_mtime_ns)).encode())
    for f in catalog.source_files(root):
        st = os.stat(f)
        h.update(("%s|%d|%d\n" % (os.path.relpath(f, root), st.st_size, st.st_mtime_ns)).encode())
    return h.hexdigest()


def build_index(rows):
    postings = defaultdict(dict)      # term -> {row_index: weighted tf}
    lengths = []
    for i, r in enumerate(rows):
        tf = Counter()
        for field, w in FIELD_WEIGHTS:
            for t in tokenize(r.get(field, "")):
                tf[t] += w
        lengths.append(sum(tf.values()) or 1)
        for t, c in tf.items():
            postings[t][i] = c
    return {"postings": postings, "dl": lengths, "N": len(rows),
            "avgdl": (sum(lengths) / len(lengths)) if lengths else 1.0}


def save_cache(path, rows, index, fp, columns):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    payload = {
        "format": INDEX_FORMAT, "fingerprint": fp, "columns": columns,
        "rows": [[r.get(c, "") for c in columns] for r in rows],
        "dl": index["dl"], "avgdl": index["avgdl"],
        "postings": {t: [list(p.keys()), list(p.values())]
                     for t, p in index["postings"].items()},
    }
    tmp = path + ".tmp%d" % os.getpid()
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, separators=(",", ":"))
    os.replace(tmp, path)


def load_cache(path, fp):
    with open(path, encoding="utf-8") as fh:
        payload = json.load(fh)
    if payload.get("format") != INDEX_FORMAT or payload.get("fingerprint") != fp:
        return None
    cols = payload["columns"]
    rows = [dict(zip(cols, vals)) for vals in payload["rows"]]
    postings = {t: dict(zip(ids, tfs)) for t, (ids, tfs) in payload["postings"].items()}
    return rows, {"postings": postings, "dl": payload["dl"], "N": len(rows),
                  "avgdl": payload["avgdl"]}


def get_index(root, rebuild=False, use_cache=True, cache_rel=CACHE_REL, timing=None):
    catalog = load_catalog_module()
    t0 = time.perf_counter()
    fp = fingerprint(catalog, root)
    cache_path = os.path.join(root, cache_rel)
    if use_cache and not rebuild and os.path.isfile(cache_path):
        try:
            hit = load_cache(cache_path, fp)
        except (ValueError, KeyError, OSError):
            hit = None
        if hit:
            if timing is not None:
                timing["source"] = "cache"
                timing["ms"] = (time.perf_counter() - t0) * 1000
            return hit[0], hit[1], catalog
    rows = catalog.build(root)
    index = build_index(rows)
    if use_cache:
        try:
            save_cache(cache_path, rows, index, fp, catalog.COLUMNS)
        except OSError:
            pass          # read-only checkout / sandbox — degrade to build-every-time
    if timing is not None:
        timing["source"] = "rebuild"
        timing["ms"] = (time.perf_counter() - t0) * 1000
    return rows, index, catalog


# ---------------------------------------------------------------------------
# search
# ---------------------------------------------------------------------------
def search(rows, index, query, limit=8, packs=None, domains=None, kinds=None,
           scopes=None, stack=None, owners=None):
    terms = expand_query(query)
    if stack:
        for t, w in expand_query(stack.replace("-", " ") + " " + stack):
            terms.append((t, min(w, 1.0)))
    if not terms:
        return []

    postings, dl, N, avgdl = (index["postings"], index["dl"], index["N"], index["avgdl"])
    scores = defaultdict(float)
    for term, qw in terms:
        pl = postings.get(term)
        if not pl:
            continue
        df = len(pl)
        idf = math.log(1 + (N - df + 0.5) / (df + 0.5))     # non-negative form
        for i, tf in pl.items():
            i = int(i)
            scores[i] += qw * idf * (tf * (K1 + 1)) / (tf + K1 * (1 - B + B * dl[i] / avgdl))

    if stack:
        want = stack.lower()
        for i in list(scores):
            if want in [s for s in (rows[i].get("stack") or "").split(",") if s]:
                scores[i] *= STACK_BOOST

    def keep(r):
        if kinds and r["kind"] not in kinds:
            return False
        if scopes and r["scope"] not in scopes:
            return False
        if owners and r["owner"] not in owners:
            return False
        if packs and not (r["scope"] == "pack" and r["owner"] in packs):
            return False
        if domains and not (r["scope"] in ("domain", "business-domain")
                            and r["owner"] in domains):
            return False
        return True

    out = []
    for i, s in sorted(scores.items(), key=lambda kv: (-kv[1], rows[kv[0]]["id"])):
        r = rows[i]
        if not keep(r):
            continue
        out.append((round(s, 3), r))
        if len(out) >= limit:
            break
    return out


# ---------------------------------------------------------------------------
# output
# ---------------------------------------------------------------------------
FOOTER = ("%d rows indexed from templates/ + commands/ (metadata only). Rows point AT "
          "prose;\nthey do not replace it. Read the cited path before acting on any row.")


def render_text(hits, total_rows, query, timing):
    if not hits:
        return ("no rows matched %r\n\nBM25 is lexical: try the vocabulary the repo uses "
                "(e.g. 'token' not 'colour var'),\nor drop a filter. "
                % query) + (FOOTER % total_rows)
    lines = ["%-6s %-16s %-20s %s" % ("score", "kind", "owner", "path")]
    for score, r in hits:
        lines.append("%-6.2f %-16s %-20s %s" % (score, r["kind"][:16], r["owner"][:20], r["path"]))
        snip = r["text"]
        if len(snip) > SNIPPET_LEN:
            snip = snip[:SNIPPET_LEN - 1].rstrip() + "…"
        lines.append("       %s" % snip)
        if r["anchor"]:
            lines.append("       § %s" % r["anchor"][:100])
    lines.append("")
    lines.append(FOOTER % total_rows)
    if timing:
        lines.append("index: %s in %.0f ms" % (timing.get("source", "?"), timing.get("ms", 0)))
    return "\n".join(lines)


def render_paths(hits):
    seen, out = set(), []
    for _, r in hits:
        if r["path"] not in seen:
            seen.add(r["path"])
            out.append(r["path"])
    return "\n".join(out)


def render_json(hits, total_rows, query):
    return json.dumps({
        "query": query, "indexed_rows": total_rows, "count": len(hits),
        "disclaimer": ("Rows are pointers into prose, not answers. "
                       "Read the cited path before acting."),
        "results": [dict(score=s, **{k: v for k, v in r.items()}) for s, r in hits],
    }, indent=2, sort_keys=False)


# ---------------------------------------------------------------------------
# --check
# ---------------------------------------------------------------------------
SMOKE = [
    ("multi-tenant isolation cross-tenant leak", None),
    ("webhook signature verification replay", None),
    ("focus ring keyboard contrast", None),
]


def run_check(root, cache_rel):
    catalog = load_catalog_module()
    rc = catalog.run_check(root, catalog.DEFAULT_OUT)
    print("")
    print("[7] index build + retrieval smoke")
    rows, index, _ = get_index(root, rebuild=True, use_cache=False, cache_rel=cache_rel)
    print("    %d rows, %d terms, %d postings"
          % (len(rows), len(index["postings"]),
             sum(len(p) for p in index["postings"].values())))
    bad = 0
    for q, _f in SMOKE:
        hits = search(rows, index, q, limit=3)
        if not hits:
            print("    FAIL — no hits for %r" % q)
            bad += 1
        else:
            print("    ok — %-42r top=%s" % (q, hits[0][1]["path"]))
    return 1 if (rc or bad) else 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def csv_set(value):
    return {v.strip() for v in (value or "").split(",") if v.strip()} or None


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="pack-search.py",
        description="BM25 over the repo's row-shaped metadata. Rows are pointers, not answers.")
    ap.add_argument("query", nargs="?", default="", help="free-text query")
    ap.add_argument("--pack", default="", metavar="KEY[,KEY]",
                    help="restrict to pack owners (templates/packs/_registry.md)")
    ap.add_argument("--domain", default="", metavar="KEY[,KEY]",
                    help="restrict to technical-signal OR business-domain owners")
    ap.add_argument("--owner", default="", metavar="KEY[,KEY]",
                    help="restrict to any owner key regardless of scope")
    ap.add_argument("--kind", default="", metavar="KIND[,KIND]",
                    help="rule-directive | closure-verb | topic-agent | command | ...")
    ap.add_argument("--scope", default="", metavar="SCOPE[,SCOPE]",
                    help="pack | domain | business-domain | registry | core")
    ap.add_argument("--stack", default="", metavar="NAME",
                    help="bias toward a stack (nestjs, react, postgres, flutter, ...)")
    ap.add_argument("--limit", "--top", type=int, default=8, dest="limit",
                    help="results to return (default 8, hard cap %d)" % HARD_CAP)
    ap.add_argument("--format", choices=("text", "json", "paths"), default="text")
    ap.add_argument("--json", action="store_true", help="alias for --format=json")
    ap.add_argument("--rebuild", action="store_true", help="ignore the cache and re-extract")
    ap.add_argument("--no-cache", action="store_true", help="never read or write the cache")
    ap.add_argument("--cache", default=CACHE_REL, metavar="PATH",
                    help="repo-relative cache path (default %s)" % CACHE_REL)
    ap.add_argument("--kinds", action="store_true", help="list available kinds/scopes/owners")
    ap.add_argument("--check", action="store_true",
                    help="catalog integrity + determinism + retrieval smoke test")
    ap.add_argument("--repo-root", default=REPO_ROOT)
    a = ap.parse_args(argv)
    root = os.path.abspath(a.repo_root)

    if a.check:
        return run_check(root, a.cache)

    timing = {}
    rows, index, _ = get_index(root, rebuild=a.rebuild, use_cache=not a.no_cache,
                               cache_rel=a.cache, timing=timing)

    if a.kinds:
        print("%d rows indexed\n" % len(rows))
        for label, field in (("kinds", "kind"), ("scopes", "scope")):
            print("%s:" % label)
            for k, n in sorted(Counter(r[field] for r in rows).items()):
                print("  %-22s %5d" % (k, n))
            print("")
        print("owners:")
        for k, n in sorted(Counter(r["owner"] for r in rows).items()):
            print("  %-28s %5d" % (k, n))
        return 0

    if not a.query.strip():
        ap.error("a query is required (or use --kinds / --check)")

    limit = max(1, min(a.limit, HARD_CAP))
    hits = search(rows, index, a.query, limit=limit, packs=csv_set(a.pack),
                  domains=csv_set(a.domain), kinds=csv_set(a.kind),
                  scopes=csv_set(a.scope), stack=a.stack.strip().lower() or None,
                  owners=csv_set(a.owner))

    fmt = "json" if a.json else a.format
    if fmt == "json":
        print(render_json(hits, len(rows), a.query))
    elif fmt == "paths":
        out = render_paths(hits)
        if out:
            print(out)
    else:
        print(render_text(hits, len(rows), a.query, timing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
