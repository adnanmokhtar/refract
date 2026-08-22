---
description: FAITHFULLY MIRROR a live website into a folder of static HTML/CSS that looks like the ORIGINAL — real HTML + real CSS + real images + real fonts, one page per template family, with its CSS/images/fonts rewritten to local paths so the folder opens offline. This is a GRAB (reproduce the real design as-is), the opposite of /clone-design (which extracts a design SYSTEM and placeholders the brand — use /grab-site when you want the REAL site, /clone-design when you want a brand-neutral system). Runs a bundled stdlib-Python mirror script — no wget/httrack needed. Stack-agnostic and project-optional. Swap in your own brand/products before shipping; not for passing a site off as its original owner.
kind: command
pack: ui-ux
---

# /grab-site <url> [<out-dir>] [<flags>...]

> **Not this command? (ANTI-triggers)** — you want a reusable, **brand-neutral design SYSTEM** (tokens + a section library, logo and photos placeholdered) rather than the real site → **`/clone-design`**. You want a design invented from your product's goals with **no external reference** → **`/art-direct`** (hand it a URL and it will ignore the site). You want to rethink a page in **your** app's language → **`/redesign`**. You want a working store with real cart/checkout/JS → a static grab cannot give you that, at all. **Same input as `/clone-design` (a URL), opposite output: this one keeps the real assets so it LOOKS like the original.** Full map: [`ui-sweep.md § The ui-ux command map`](ui-sweep.md).

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/grab-site <url> --plan` discovers the template-family page set + the asset inventory and writes the grab plan to `.claude/plans/`, exiting before any file is downloaded.

## The Premise (read this first, internalize, do not deviate)

**You point at a live URL; this command downloads the REAL site — its actual HTML, CSS, images, and fonts — for one page of each template family, rewrites its CSS/images/fonts to local paths, and leaves you a folder that opens offline and looks like the original** (a few secondary `srcset`/inline references may still load from the origin — see the Offline-open gate). It is a **faithful mirror**, not a reinterpretation. Where [`/clone-design`](clone-design.md) extracts a reusable design *system* and **placeholders the brand** (logo → `[LOGO]`, photos → grey boxes) — which is why its output looks like a wireframe — `/grab-site` keeps the **real assets** so the result is visually the actual site. Use `/grab-site` when the answer to "what do you want?" is *"the same design as this site."*

**"All pages" means one page per TEMPLATE FAMILY, not every URL.** A storefront has thousands of product/collection URLs but a handful of *templates* — home, collection, product, cart, search, page, article. Every product URL is the same `product` template with different data. The command auto-discovers one representative of each family from the homepage's links (or takes an explicit `--pages` list) and grabs those. That IS the whole design.

**Two honest limits, stated up front (not failures — the nature of a static grab):**
1. **JS interactions don't work** — sliders, add-to-cart, live search, mega-menu animation. It is a faithful *visual* copy, not a running app.
2. **It is the source site's real content/images.** Legitimate as a starting scaffold or design reference; **swap in your own logo / products / copy before going live.** `/grab-site` does not exist to help pass a site off as its original owner — that is out of scope.

### `/grab-site` vs `/clone-design` vs `/redesign`

| | `/grab-site` | `/clone-design` | `/redesign` |
|---|---|---|---|
| Output | **the REAL site, mirrored** (real assets) | a design *system* + placeholdered brand | a rebuilt page in the app's language |
| Looks like the original? | **yes — faithfully** | no — a clean wireframe by design | no — a new design |
| Brand identity | **kept (swap yours in later)** | placeholdered | the app's own |
| Mechanism | **downloads + link-rewrites** (bundled script) | extract tokens + build + pixel-verify | diagnose → propose → rebuild |
| Needs a project? | **no — writes into a folder** | no (Stage 1) | yes |

## When to use
- You want a design you like rebuilt as real, editable HTML/CSS you own — "grab this site, same design."
- You want a faithful offline reference of a site's real markup + CSS to study or port.
- You're seeding a new build from an existing storefront's look.

## When NOT to use
- You want a clean, brand-neutral design *system* (tokens + components, placeholdered) → `/clone-design`.
- You want to rethink/redesign a page in your app's own language → `/redesign`.
- You want a working store (real cart/checkout/JS) — a static grab can't give you that.
- You intend to deceptively pass the copied site off as its original brand → out of scope.

## Args
- `<url>` — the site to grab. **`shop.example.com` throughout this file is a placeholder host** standing in for a real storefront (`example.com` is the reserved documentation domain and will not itself yield six template pages) — substitute the real URL. Naming a specific third-party commercial site as the canonical example is deliberately avoided: this command downloads someone's real assets, and the docs should not read as an endorsement of a particular target. The scheme+host become the mirror's base; the path (if any) is the `index` page.
- `<out-dir>` — output folder (default: the site's host name). The folder holds one `<template>.html` per family, an `assets/` dir (real CSS/images/fonts), and `_gallery.html`.
- `--pages=/a,/b,/c` — explicit page paths to grab instead of auto-discovery (first entry = `index`).
- `--max-assets=<N>` — cap total downloaded assets (default 800) — a runaway/size guard. CSS/fonts are fetched before images, so a tight cap drops images (not the layout) and the run WARNs.
- `--plan` — write the page-set + asset plan and exit before downloading.

```bash
/grab-site https://shop.example.com/                 # mirror into ./shop.example.com/
/grab-site https://example.com site/                               # mirror into ./site/
/grab-site https://example.com --pages=/,/about,/pricing,/contact  # grab exactly these pages
/grab-site https://example.com --plan                              # page-set + asset plan only
```

## How it runs (the mechanism — this command EXECUTES, it does not describe)

The grab is a **bundled stdlib-Python script** (no `pip`, no `wget`/`httrack` — only `python3`, present on macOS/Linux). Materialize it once to `.claude/scripts/grab-site.py`, then run it:

```bash
python3 .claude/scripts/grab-site.py <url> [out-dir] [--pages=...] [--max-assets=N]
```

It (1) **hard-fetches the first page** with a real browser User-Agent and HALTs (`CAPTURE FAILED`, non-zero exit) if it 404s/errors or returns a short bot-wall / empty shell — this check runs **even with `--pages`**; (2) auto-discovers one page per template family (`/collections/…`, `/products/…`, `/pages/…`, `/blogs/…/…`, plus `/cart` + `/search` on Shopify; on a non-Shopify site it falls back to harvesting the homepage's own nav links) unless `--pages` is given; (3) for each page downloads **CSS/fonts first** (recursing into `@import` and `url(...)` for fonts/background images), then `<img>` `src`/`data-src` + `background-image`, then **every** `srcset`/`data-srcset` candidate; (4) rewrites each remote reference to a local `assets/…` path (page-relative refs resolve against the page, not the site root) and **promotes lazy `data-src`/`data-srcset` into a single working `src`/`srcset`** — dropping the placeholder — so images show without JS; (5) writes `<template>.html` per page + `_gallery.html`, then prints a **localization report** (css / img-ref / img-asset counts · residual-remote-ref count · cap/blocked `WARN`s).

<details><summary>Bundled script — write verbatim to <code>.claude/scripts/grab-site.py</code></summary>

```python
#!/usr/bin/env python3
"""grab-site — faithful static mirror of a website (Shopify/storefront-friendly).
Grabs REAL html + css + images + fonts for one page per template family and
rewrites every remote reference to a local path so the folder opens offline.
Usage:  grab-site.py <url> [out-dir] [--pages=/a,/b,/c] [--max-assets=N]"""
import os, re, sys, hashlib, urllib.request, urllib.parse

if len(sys.argv) < 2 or sys.argv[1].startswith("-"):
    sys.exit("usage: grab-site.py <url> [out-dir] [--pages=/a,/b] [--max-assets=N]")

START = sys.argv[1].rstrip("/")
P = urllib.parse.urlparse(START)
BASE = f"{P.scheme}://{P.netloc}"
argv = sys.argv[2:]
OUT = next((a for a in argv if not a.startswith("--")), P.netloc.split(":")[0])
PAGES_ARG = next((a.split("=", 1)[1] for a in argv if a.startswith("--pages=")), None)
MAX_ASSETS = int(next((a.split("=", 1)[1] for a in argv if a.startswith("--max-assets=")), "800"))
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120 Safari/537.36")
WALL = ("just a moment", "enable javascript", "access denied", "cf-browser-verification",
        "captcha", "attention required", "checking your browser", "ddos-guard")

def fetch(u, binary=False):
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read() if binary else r.read().decode("utf-8", "replace")

def norm(u, page):
    if not u: return None
    u = u.strip().strip('"\'')
    if u[:5] in ("data:", "javas") or u.startswith("#") or u.startswith("mailto"): return None
    if u.startswith("//"): return "https:" + u
    if u.startswith("http"): return u
    if u.startswith("/"):  return BASE + u
    return urllib.parse.urljoin(page, u)   # page-relative resolves against the PAGE, not the root

def looks_blocked(html):
    low = html.lower()
    # a genuine bot-wall / challenge page is SHORT (the challenge IS the whole page); a real
    # page can mention "captcha"/"enable javascript" in a widget/noscript and be huge — don't flag it.
    if len(html) < 4000 and any(w in low for w in WALL): return True
    # empty-shell: no stylesheet AND no images AND almost no text (a real page has at least one)
    if "<link" not in low and "<img" not in low and len(re.sub(r"<[^>]+>", "", html).strip()) < 200:
        return True
    return False

# ---- Capture gate: hard-fetch the FIRST page (runs even with --pages); HALT on failure/wall ----
def hard_first_fetch(path):
    url = BASE + path if path.startswith("/") else path
    try:
        html = fetch(url)
    except Exception as e:
        sys.exit(f"CAPTURE FAILED — {url} did not return real HTML ({e})")
    if looks_blocked(html):
        sys.exit(f"CAPTURE FAILED — {url} returned a bot-wall / empty shell, not real content")
    return url, html

def discover(home):
    is_shopify = ("cdn.shopify.com" in home) or ("Shopify" in home) or ('href="/cart' in home)
    pages = {"index": P.path or "/"}
    for key, pat in [("collection", r'/collections/[a-z0-9\-]+'),
                     ("product",    r'/products/[a-z0-9\-]+'),
                     ("page",       r'/pages/[a-z0-9\-]+'),
                     ("article",    r'/blogs/[a-z0-9\-]+/[a-z0-9\-]+')]:
        m = re.search(pat, home, re.I)
        if m: pages[key] = m.group(0)
    if is_shopify:
        pages.setdefault("cart", "/cart"); pages.setdefault("search", "/search?q=a")
    if len(pages) <= 2:   # generic (non-Shopify) fallback: harvest same-host internal links
        seen = set()
        for href in re.findall(r'<a[^>]+href=["\']([^"\']+)["\']', home, re.I):
            n = norm(href, BASE + "/")
            if not n or not n.startswith(BASE): continue
            path = urllib.parse.urlparse(n).path
            seg = path.strip("/").split("/")[0]
            if not seg or seg in seen or path in ("/", P.path): continue
            seen.add(seg); pages[("nav-" + seg)[:20]] = path
            if len(pages) >= 6: break
    return pages

if PAGES_ARG:
    plist = [p for p in PAGES_ARG.split(",") if p]
    first_url, first_html = hard_first_fetch(plist[0])
    PAGES = {("index" if i == 0 else f"page{i}"): p for i, p in enumerate(plist)}
else:
    first_url, first_html = hard_first_fetch(P.path or "/")
    PAGES = discover(first_html)

os.makedirs(os.path.join(OUT, "assets"), exist_ok=True)
_cache = {}
_prefetched = {first_url: first_html}

def local_name(u):
    path = urllib.parse.urlparse(u).path
    ext = (os.path.splitext(path)[1].split("?")[0] or ".bin")[:6]
    stem = re.sub(r"[^A-Za-z0-9]+", "-", os.path.basename(path).split("?")[0])[:40] or "asset"
    return f"{stem}-{hashlib.md5(u.encode()).hexdigest()[:10]}{ext}"

def grab_asset(u, page, depth=0):
    u = norm(u, page)
    if not u or u in _cache: return _cache.get(u)
    if len(_cache) >= MAX_ASSETS: return None
    try:
        is_css = ".css" in u.split("?")[0]
        raw = fetch(u, binary=not is_css)
    except Exception:
        return None
    name = local_name(u); _cache[u] = "assets/" + name
    if is_css and depth < 3:
        for ref in set(re.findall(r"url\(([^)]+)\)", raw)) | set(re.findall(r'@import\s+["\']([^"\']+)', raw)):
            child = grab_asset(urllib.parse.urljoin(u, ref.strip('"\' ')), u, depth + 1)
            if child: raw = raw.replace(ref, child.split("/")[-1])
        open(os.path.join(OUT, "assets", name), "w", encoding="utf-8").write(raw)
    else:
        open(os.path.join(OUT, "assets", name), "wb").write(raw if isinstance(raw, bytes) else raw.encode())
    return _cache[u]

def rewrite(html, page_url):
    # 1) CSS + fonts FIRST — the layout/colour/type skeleton is what makes it "look like the
    #    original"; grab it before images so a tight --max-assets never leaves an unstyled page.
    for m in set(re.findall(r'<link[^>]+href=["\']([^"\']+)["\']', html)):
        if ".css" in m or "font" in m:
            loc = grab_asset(m, page_url)
            if loc: html = html.replace(m, loc)
    # 2) IMAGES — src / data-src / background-image
    imgs = set(re.findall(r'(?:data-src|src)=["\']([^"\']+\.(?:png|jpe?g|webp|gif|svg|avif)[^"\']*)["\']', html, re.I))
    for m in re.findall(r'background-image:\s*url\(([^)]+)\)', html, re.I):
        imgs.add(m.strip('"\' '))
    for u in imgs:
        loc = grab_asset(u, page_url)
        if loc: html = html.replace(u, loc)
    # 3) SRCSET / DATA-SRCSET — localize EVERY candidate, not just the first
    for m in set(re.findall(r'(?:data-srcset|srcset)=["\']([^"\']+)["\']', html, re.I)):
        parts = []
        for cand in m.split(","):
            seg = cand.strip().split()
            if not seg: continue
            loc = grab_asset(seg[0], page_url); seg[0] = loc or seg[0]
            parts.append(" ".join(seg))
        html = html.replace(m, ", ".join(parts))
    # 4) promote lazy attrs to ONE working src/srcset (fix duplicate-src + blank data-srcset)
    def fix_img(mo):
        tag = mo.group(0)
        if re.search(r'\sdata-src=', tag, re.I):
            tag = re.sub(r'\ssrc=(["\']).*?\1', '', tag, count=1, flags=re.I)   # drop placeholder src
            tag = re.sub(r'\sdata-src=', ' src=', tag, count=1, flags=re.I)      # promote data-src -> src
        if re.search(r'\sdata-srcset=', tag, re.I):
            tag = re.sub(r'\sdata-srcset=', ' srcset=', tag, count=1, flags=re.I)
        if re.search(r'\ssrcset=', tag, re.I) and not re.search(r'\ssrc=', tag, re.I):
            sm = re.search(r'\ssrcset=(["\'])(.*?)\1', tag, re.I)
            if sm:
                first = sm.group(2).split(",")[0].strip().split(" ")[0]
                if first: tag = re.sub(r'\s*/?>$', f' src="{first}">', tag)
        return tag
    return re.sub(r'<img\b[^>]*>', fix_img, html, flags=re.I)

manifest = []
for name, path in PAGES.items():
    url = BASE + path if path.startswith("/") else path
    try:
        html = _prefetched.get(url) or fetch(url)
    except Exception as e:
        print(f"  page fail {name}: {e}"); continue
    open(os.path.join(OUT, f"{name}.html"), "w", encoding="utf-8").write(rewrite(html, url))
    manifest.append((name, path)); print(f"PAGE  {name:11} {path}")

if not manifest:
    sys.exit("CAPTURE FAILED — no pages could be grabbed")

# ---- real gate reporting (Asset-localization / Offline-open / Template-coverage) ----
idx = open(os.path.join(OUT, f"{manifest[0][0]}.html")).read()
css_local = len(re.findall(r'href="assets/[^"]+\.css"', idx))
img_local = len(re.findall(r'src="assets/[^"]+\.(?:png|jpe?g|webp|gif|svg|avif)"', idx, re.I))
img_assets = sum(1 for v in _cache.values() if re.search(r'\.(?:png|jpe?g|webp|gif|svg|avif)$', v, re.I))
remote_left = len(re.findall(r'(?:src|href)="https?://', idx)) + len(re.findall(r'(?:src|href)="//', idx))
cap_hit = len(_cache) >= MAX_ASSETS
links = "\n".join(f'<li><a href="{n}.html">{n}</a> <small>{p}</small></li>' for n, p in manifest)
open(os.path.join(OUT, "_gallery.html"), "w").write(
    f"<meta charset=utf8><h1>{P.netloc} — grabbed</h1><ul>{links}</ul>")
print(f"\nDONE  {BASE}  pages={len(manifest)}  assets={len(_cache)}  -> {OUT}/  (open _gallery.html)")
print(f"  localized: css={css_local} img-refs={img_local} img-assets={img_assets} · residual-remote-refs={remote_left}")
if css_local == 0: print("  WARN: no local CSS on the index page — layout may be wrong (assets blocked?)")
if img_assets == 0: print("  WARN: no images localized — the mirror will look empty")
if cap_hit: print(f"  WARN: --max-assets={MAX_ASSETS} cap hit — coverage is partial; raise it")
print("  limits: JS interactions not live (visual copy) · carries source content — swap your brand before shipping")
```
</details>

## Gates (what the script enforces vs. what the agent reads)

The script enforces the Capture gate itself and **prints** the signals for the other three on its final lines — the agent reads them, it does not re-derive them.

- **Capture gate — SCRIPT-ENFORCED HALT.** The script hard-fetches the first page (even under `--pages`) and `sys.exit`s non-zero with `CAPTURE FAILED` if it 404s/errors or returns a short bot-wall / empty shell; if no page grabs at all, it also exits non-zero. It never writes a mirror from an error page. (Heuristic: a challenge marker only counts on a *short* page, so a real page that merely mentions "captcha" in a widget is not flagged.)
- **Asset-localization — SCRIPT-REPORTED.** The final line prints `localized: css=N img-refs=N img-assets=N`; a `WARN: no local CSS` or `WARN: no images localized` fires when the primary page didn't localize its stylesheet or any image. A mirror reporting `css=0` is not done — say so, don't claim success.
- **Offline-open — REPORTED, not absolute.** Primary CSS/fonts/images are localized so the folder opens offline; the printed `residual-remote-refs=N` counts secondary `srcset`/inline/preload refs that still load from the origin (fine online; a higher `--max-assets` or a second pass localizes more). Do not claim "fully offline" if the count is high.
- **Template-coverage — REPORTED.** The `PAGE <name> <path>` lines list every grabbed family; `page fail <name>` names any that 404'd. One representative per discovered family.

## What you see
```
/grab-site https://shop.example.com/

PAGE  index       /
PAGE  collection  /collections/classic-all
PAGE  product     /products/quarter-zip-sweatshirt
PAGE  page        /pages/wish-list
PAGE  cart        /cart
PAGE  search      /search?q=a

DONE  https://shop.example.com  pages=6  assets=300  -> shop.example.com/  (open _gallery.html)
  localized: css=54 img-refs=54 img-assets=262 · residual-remote-refs=63
  WARN: --max-assets=800 cap hit — coverage is partial; raise it        (only printed if the cap was hit)
  limits: JS interactions not live (visual copy) · carries source content — swap your brand before shipping
```

The `PAGE`, `DONE`, `localized:`, and any `WARN:` / `CAPTURE FAILED` lines are printed by the **script itself** (not agent narration) — they are the machine-readable signal for the gates above.

## Don't (hard rules)
- **DON'T claim a faithful mirror without the assets.** If CSS/images did not localize (bot wall, blocked assets), say so — a page with remote-only CSS is not grabbed.
- **DON'T pass the grab off as the original brand.** It carries the source's real content; swap your own brand/products in before any public use.
- **DON'T promise working interactions.** A static grab has no live JS — state it.
- **DON'T re-download unboundedly.** `--max-assets` caps it; report if the cap was hit (coverage is then partial).
- **Rollback is a folder.** The run writes only under `<out-dir>` (+ the one script) — delete the folder to undo.

## Failure modes
- **Capture blocked** (bot wall / consent gate / non-200) — `CAPTURE FAILED` HALT; try a real browser User-Agent (already sent) or grab from saved HTML.
- **Assets blocked / hotlink-protected** — the page localizes what it can; the Asset-localization gate names what stayed remote.
- **JS-only content** (SPA that renders nothing server-side) — the static grab captures the shell only; note that a headless-render capture (Playwright) is needed for such sites.
- **`--max-assets` cap hit** — coverage is partial; raise the cap or narrow `--pages`.

## Cross-references
- [`/clone-design`](clone-design.md) — the sibling that extracts a brand-neutral design *system* (placeholdered) instead of mirroring the real site; use it when you want tokens/components, not a copy.
- [`/redesign`](redesign.md) / [`/add-theme-variant`](add-theme-variant.md) — once you have the grab as a reference, rebuild it inside your app's own language / theme system.

## Stack scope
**Stack-agnostic and project-optional** — it writes plain HTML/CSS into a folder and needs only `python3`; no framework, no repo, no `_extracted-idioms.md`. It does not HALT on a backend/empty repo.
