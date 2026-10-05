#!/usr/bin/env python3
"""seo-head.py — seo-audit's oracle: what a crawler that runs no JavaScript receives.

Fetches each route of a running PRODUCTION build (or reads saved HTML), parses the server HTML and
prints one row per route plus the findings, per seo-audit §1–§9. Stdlib only. Read-only: it never
writes a file and only sends GET requests.

Usage:  seo-head.py --base=http://localhost:3000 --routes=/,/blog/a,/blog/b [--ua=googlebot|facebook|<ua>]
                    [--expect-index=/,/blog/] [--robots] [--sitemap-sample=20] [--min-text=200] [--json]
        seo-head.py --html=dist/index.html [--html=…] [--expect-index=*]
        seo-head.py --self-test
Exit:   0  no finding   1  at least one finding   2  usage, fetch or parse error

--expect-index  route prefixes (or `*`) that are meant to rank — the indexable route class. On those
                routes a noindex is §5 `noindex`; elsewhere it is printed as a fact, never a finding.
--ua            googlebot (default) or facebook. Next.js streams metadata into <body> for clients it
                does not list as HTML-limited bots; run both and compare (§1 `meta-in-body`).

FINDINGS (exit 1):
  §1 title-missing · title-multiple · title-dup (same title on 2+ routes) · desc-missing · desc-dup · meta-in-body
  §2 canonical-missing · canonical-multiple · canonical-relative · canonical-in-body · canonical-tracking
  §3 og-missing (title or image) · og-image-relative · twitter-card-missing
  §4 jsonld-invalid (the block does not parse — the whole block is ignored)
  §5 noindex (meta or X-Robots-Tag on an --expect-index route) · status (not 200 on an --expect-index route)
  §6 robots-disallow-all · robots-disallow-assets · robots-no-sitemap · sitemap-relative-loc ·
     sitemap-over-limit · sitemap-loc-bad (a sampled <loc> answers non-200 or noindex)
  §7 hreflang-code · hreflang-relative · hreflang-self-missing · hreflang-x-default-missing · hreflang-not-reciprocal
  §8 csr-shell (visible body text under --min-text characters)
  §9 h1-count (not exactly one h1)
CANDIDATES (printed, never exit 1 — each needs a read):
  jsonld-no-rich-result (FAQPage, HowTo, SearchAction, ClaimReview, SpecialAnnouncement, Quiz) ·
  canonical-elsewhere (points at another path) · anchor-generic ("click here", "read more", …) ·
  meta-in-body / canonical-in-body on a Next.js page (streamed metadata: settle with URL Inspection)
"""
import json, re, sys, urllib.error, urllib.parse, urllib.request
from html.parser import HTMLParser

UAS = {"googlebot": "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
       "facebook": "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"}
NO_RICH = {"FAQPage", "HowTo", "SearchAction", "ClaimReview", "SpecialAnnouncement", "Quiz"}
TRACKING = re.compile(r"[?&](?:utm_\w+|gclid|fbclid|msclkid|ref|session\w*)=", re.I)
HREFLANG = re.compile(r"^(?:x-default|[a-z]{2,3}(?:-[a-z]{4})?(?:-(?:[a-z]{2}|\d{3}))?)$", re.I)
GENERIC = re.compile(r"^\s*(?:click here|here|read more|more|learn more)\s*$", re.I)


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack, self.titles, self.metas, self.links, self.ld, self.h1 = [], [], [], [], [], 0
        self.text, self.anchors, self._t, self._ld, self._a = [], [], None, None, None

    def handle_starttag(self, tag, attrs):
        a = {k.lower(): (v or "") for k, v in attrs}
        where = "head" if "head" in self.stack else "body"
        if tag == "title" and "svg" not in self.stack:
            self._t = []
        elif tag == "meta":
            self.metas.append((a, where))
        elif tag == "link":
            self.links.append((a, where))
        elif tag == "script" and a.get("type", "").lower() == "application/ld+json":
            self._ld = []
        elif tag == "h1":
            self.h1 += 1
        elif tag == "a" and a.get("href"):
            self._a = [a["href"], []]
        if tag not in ("meta", "link", "br", "img", "input", "hr", "source", "base"):
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if tag == "title" and self._t is not None:
            self.titles.append("".join(self._t).strip()); self._t = None
        elif tag == "script" and self._ld is not None:
            self.ld.append("".join(self._ld)); self._ld = None
        elif tag == "a" and self._a:
            self.anchors.append((self._a[0], "".join(self._a[1]).strip())); self._a = None
        if tag in self.stack:
            while self.stack and self.stack.pop() != tag:
                pass

    def handle_data(self, d):
        if self._t is not None: self._t.append(d)
        if self._ld is not None: self._ld.append(d)
        if self._a: self._a[1].append(d)
        if "body" in self.stack and not {"script", "style", "noscript", "template"} & set(self.stack):
            self.text.append(d)


def ld_types(node, out):
    if isinstance(node, list):
        for n in node: ld_types(n, out)
    elif isinstance(node, dict):
        t = node.get("@type")
        out.update(t if isinstance(t, list) else [t] if t else [])
        for v in node.values():
            if isinstance(v, (dict, list)): ld_types(v, out)
    return out


def fetch(url, ua, head_only=False):
    req = urllib.request.Request(url, headers={"User-Agent": ua}, method="HEAD" if head_only else "GET")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, dict(r.headers), ("" if head_only else r.read(60_000_000).decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), ""


def analyse(route, status, headers, html, expect, min_text):
    p = Page(); p.feed(html)
    meta = lambda k, v: [m for m, w in p.metas if m.get(k, "").lower() == v]
    content = lambda k, v: [m.get("content", "") for m in meta(k, v)]
    canon = [(l.get("href", ""), w) for l, w in p.links if l.get("rel", "").lower() == "canonical"]
    alts = [l for l, _ in p.links if l.get("rel", "").lower() == "alternate" and l.get("hreflang")]
    robots = " ".join(content("name", "robots") + content("name", "googlebot") + [headers.get("X-Robots-Tag", headers.get("x-robots-tag", ""))]).lower()
    types, bad_ld = set(), 0
    for block in p.ld:
        try: ld_types(json.loads(block), types)
        except ValueError: bad_ld += 1
    row = {"route": route, "status": status, "title": p.titles[0] if p.titles else None,
           "description": (content("name", "description") or [None])[0], "robots": robots.strip() or None,
           "canonical": [c for c, _ in canon], "og": sorted({m.get("property") for m, _ in p.metas if m.get("property", "").startswith("og:")}),
           "jsonld_types": sorted(t for t in types if isinstance(t, str)), "hreflang": {l["hreflang"]: l.get("href", "") for l in alts},
           "h1": p.h1, "text_chars": len(re.sub(r"\s+", " ", "".join(p.text)).strip()), "links": len(p.anchors)}
    F, C = [], []
    want = expect(route)
    if want and status != 200: F.append(("§5", "status", f"answers {status}"))
    if want and "noindex" in robots: F.append(("§5", "noindex", robots.strip()))
    if not p.titles: F.append(("§1", "title-missing", "no <title> in the server HTML"))
    elif len(p.titles) > 1: F.append(("§1", "title-multiple", " | ".join(p.titles)))
    if want and not row["description"]: F.append(("§1", "desc-missing", "no meta description"))
    streamed = "__next_f" in html          # Next.js streaming metadata appends late tags to <body> by design
    if any(w == "body" for m, w in p.metas if m.get("name", "").lower() in ("description", "robots") or m.get("property", "").startswith("og:")):
        (C if streamed else F).append(("§1", "meta-in-body", "metadata in <body> — a crawler that runs no JavaScript reads none of it"))
    if want and not canon: F.append(("§2", "canonical-missing", ""))
    if len(canon) > 1: F.append(("§2", "canonical-multiple", " | ".join(c for c, _ in canon)))
    for c, w in canon:
        if not re.match(r"^https?://", c): F.append(("§2", "canonical-relative", c))
        if w == "body": (C if streamed else F).append(("§2", "canonical-in-body", c + " (Google accepts rel=canonical only in <head>)"))
        if TRACKING.search(c): F.append(("§2", "canonical-tracking", c))
        elif re.match(r"^https?://", c) and urllib.parse.urlsplit(c).path.rstrip("/") != urllib.parse.urlsplit(route).path.rstrip("/"):
            C.append(("§2", "canonical-elsewhere", c))
    if want:
        if not {"og:title", "og:image"} <= set(row["og"]): F.append(("§3", "og-missing", "has " + (",".join(row["og"]) or "none")))
        if not meta("name", "twitter:card"): F.append(("§3", "twitter-card-missing", ""))
    for img in content("property", "og:image"):
        if not re.match(r"^https?://", img): F.append(("§3", "og-image-relative", img))
    if bad_ld: F.append(("§4", "jsonld-invalid", f"{bad_ld} block(s) do not parse"))
    for t in sorted(types & NO_RICH): C.append(("§4", "jsonld-no-rich-result", t))
    for code, href in row["hreflang"].items():
        if not HREFLANG.match(code) or re.search(r"_|-uk$", code, re.I): F.append(("§7", "hreflang-code", code))
        if not re.match(r"^https?://", href): F.append(("§7", "hreflang-relative", f"{code} {href}"))
    if row["hreflang"]:
        if "x-default" not in {k.lower() for k in row["hreflang"]}: F.append(("§7", "hreflang-x-default-missing", ""))
        if not any(urllib.parse.urlsplit(h).path.rstrip("/") == urllib.parse.urlsplit(route).path.rstrip("/") for h in row["hreflang"].values()):
            F.append(("§7", "hreflang-self-missing", "the page does not list itself"))
    if row["text_chars"] < min_text: F.append(("§8", "csr-shell", f"{row['text_chars']} visible characters in the server HTML"))
    if want and p.h1 != 1: F.append(("§9", "h1-count", f"{p.h1} h1"))
    for href, txt in p.anchors:
        if GENERIC.match(txt): C.append(("§9", "anchor-generic", f"'{txt}' → {href}"))
    return row, F, C


def cross(rows, findings):
    for key, code in (("title", "title-dup"), ("description", "desc-dup")):
        seen = {}
        for r in rows:
            if r[key]: seen.setdefault(r[key], []).append(r["route"])
        for v, routes in seen.items():
            if len(routes) > 1:
                for rt in routes: findings.append((rt, "§1", code, f"'{v}' also on " + ", ".join(x for x in routes if x != rt)))
    paths = {urllib.parse.urlsplit(r["route"]).path.rstrip("/"): r for r in rows}
    for r in rows:
        me = urllib.parse.urlsplit(r["route"]).path.rstrip("/")
        for code, href in r["hreflang"].items():
            if code.lower() == "x-default": continue
            other = paths.get(urllib.parse.urlsplit(href).path.rstrip("/"))
            if other is not None and other is not r and me not in {urllib.parse.urlsplit(h).path.rstrip("/") for k, h in other["hreflang"].items() if k.lower() != "x-default"}:
                findings.append((r["route"], "§7", "hreflang-not-reciprocal", f"{code} → {href} does not link back"))


def crawl_files(base, ua, sample, out):
    st, _, txt = fetch(urllib.parse.urljoin(base, "/robots.txt"), ua)
    maps = []
    if st != 200:
        out.append(("/robots.txt", "§6", "robots-missing", f"answers {st}"))
    else:
        if re.search(r"^\s*Disallow:\s*/\s*$", txt, re.M | re.I): out.append(("/robots.txt", "§6", "robots-disallow-all", "Disallow: /"))
        for m in re.finditer(r"^\s*Disallow:\s*(/(?:_next|_nuxt|assets|static|build|_app)/|/?\*?\.(?:js|css)\b)", txt, re.M | re.I):
            out.append(("/robots.txt", "§6", "robots-disallow-assets", m.group(0).strip()))
        maps = re.findall(r"^\s*Sitemap:\s*(\S+)", txt, re.M | re.I)
        if not maps: out.append(("/robots.txt", "§6", "robots-no-sitemap", "no Sitemap: line"))
    for sm in (maps or [urllib.parse.urljoin(base, "/sitemap.xml")])[:5]:
        sm = urllib.parse.urljoin(base, urllib.parse.urlsplit(sm).path)   # the local build serves the same path
        st, _, xml = fetch(sm, ua)
        if st != 200: out.append((sm, "§6", "sitemap-missing", f"answers {st}")); continue
        locs = re.findall(r"<loc>\s*([^<\s]+)\s*</loc>", xml)
        if len(locs) > 50000 or len(xml.encode()) > 50 * 1024 * 1024: out.append((sm, "§6", "sitemap-over-limit", f"{len(locs)} URLs"))
        for l in locs:
            if not re.match(r"^https?://", l): out.append((sm, "§6", "sitemap-relative-loc", l)); break
        if "<sitemapindex" in xml: continue
        for l in locs[:sample]:
            st2, h2, body = fetch(urllib.parse.urljoin(base, urllib.parse.urlsplit(l).path), ua)
            if st2 != 200 or "noindex" in (h2.get("X-Robots-Tag", "") + " ".join(re.findall(r"<meta[^>]+robots[^>]+>", body[:200000]))).lower():
                out.append((sm, "§6", "sitemap-loc-bad", f"{l} → {st2}{' noindex' if st2 == 200 else ''}"))


def run(args):
    opt = {k: v for a in args if a.startswith("--") and "=" in a for k, v in [a[2:].split("=", 1)]}
    htmls = [a.split("=", 1)[1] for a in args if a.startswith("--html=")]
    ua = UAS.get(opt.get("ua", "googlebot"), opt.get("ua", UAS["googlebot"]))
    exp = [e for e in opt.get("expect-index", "").split(",") if e]
    expect = lambda r: "*" in exp or any(r == e or (e.endswith("/") and r.startswith(e)) for e in exp)
    min_text = int(opt.get("min-text", "200"))
    pages = []
    if htmls:
        for h in htmls:
            try: pages.append((h, 200, {}, open(h, encoding="utf-8", errors="replace").read()))
            except OSError as e: print(f"ERR {e}", file=sys.stderr); return 2
    elif opt.get("base") and opt.get("routes"):
        for r in opt["routes"].split(","):
            try: st, hd, body = fetch(urllib.parse.urljoin(opt["base"], r), ua)
            except (urllib.error.URLError, OSError) as e: print(f"ERR {r}: {e}", file=sys.stderr); return 2
            pages.append((r, st, hd, body))
    else:
        print(__doc__, file=sys.stderr); return 2
    rows, findings, cands = [], [], []
    for route, st, hd, body in pages:
        row, F, C = analyse(route, st, hd, body, expect, min_text)
        rows.append(row); findings += [(route,) + f for f in F]; cands += [(route,) + c for c in C]
    cross(rows, findings)
    if "--robots" in args and opt.get("base"):
        crawl_files(opt["base"], ua, int(opt.get("sitemap-sample", "20")), findings)
    if "--json" in args:
        print(json.dumps({"rows": rows, "findings": findings, "candidates": cands}, indent=1, ensure_ascii=False))
    else:
        for r in rows:
            print(f"ROW {r['route']} {r['status']} title={r['title']!r} canonical={r['canonical']} robots={r['robots']} og={len(r['og'])} ld={r['jsonld_types']} hreflang={len(r['hreflang'])} h1={r['h1']} text={r['text_chars']} links={r['links']}")
        for f in findings: print("FINDING", *f)
        for c in cands: print("CANDIDATE", *c)
        print(f"seo-head: {len(rows)} route(s) · {len(findings)} finding(s) · {len(cands)} candidate(s) · ua={opt.get('ua', 'googlebot')}")
    return 1 if findings else 0


def self_test():
    import os, tempfile
    good = ('<html><head><title>Blue shoes — Acme</title><meta name="description" content="d">'
            '<link rel="canonical" href="https://acme.com/en/shoes"><meta property="og:title" content="t">'
            '<meta property="og:image" content="https://acme.com/o.png"><meta name="twitter:card" content="summary_large_image">'
            '<link rel="alternate" hreflang="en" href="https://acme.com/en/shoes"><link rel="alternate" hreflang="ar" href="https://acme.com/ar/shoes">'
            '<link rel="alternate" hreflang="x-default" href="https://acme.com/en/shoes">'
            '<script type="application/ld+json">{"@context":"https://schema.org","@type":"Product","name":"x"}</script></head>'
            '<body><h1>Blue shoes</h1><svg><title>icon</title></svg>' + "<p>" + "word " * 60 + '</p><a href="/en/a">Running shoes</a></body></html>')
    bad = ('<html><head><title>Acme</title><title>Acme 2</title><meta name="robots" content="noindex">'
           '<link rel="canonical" href="/x?utm_source=a"><meta property="og:image" content="/o.png">'
           '<link rel="alternate" hreflang="en_US" href="/en/shoes">'
           '<script type="application/ld+json">{"@type":"FAQPage",}</script>'
           '<script type="application/ld+json">{"@type":"FAQPage"}</script></head>'
           '<body><div id="root"></div><a href="/y">read more</a></body></html>')
    d = tempfile.mkdtemp()
    fa, fb = os.path.join(d, "en", "shoes"), os.path.join(d, "bad")
    os.makedirs(os.path.dirname(fa))
    open(fa, "w").write(good); open(fb, "w").write(bad)
    exp = lambda r: True
    _, F1, C1 = analyse("/en/shoes", 200, {}, good, exp, 200)
    _, F2, C2 = analyse("/bad", 200, {}, bad, exp, 200)
    codes = {c for _, c, _ in F2}
    want = {"title-multiple", "noindex", "desc-missing", "canonical-relative", "canonical-tracking", "og-missing", "og-image-relative",
            "twitter-card-missing", "jsonld-invalid", "hreflang-code", "hreflang-relative", "hreflang-x-default-missing",
            "hreflang-self-missing", "csr-shell", "h1-count"}
    ok = not F1 and not C1 and want <= codes and {c for _, c, _ in C2} == {"jsonld-no-rich-result", "anchor-generic"}
    rows = [analyse("/a", 200, {}, good.replace("Blue shoes — Acme", "Same"), exp, 0)[0],
            analyse("/b", 200, {}, good.replace("Blue shoes — Acme", "Same"), exp, 0)[0]]
    xf = []; cross(rows, xf)
    ok = ok and sum(1 for f in xf if f[2] == "title-dup") == 2
    print("self-test:", "PASS" if ok else f"FAIL good={F1} {C1} missing={want - codes} cross={xf}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else run(sys.argv[1:]))
