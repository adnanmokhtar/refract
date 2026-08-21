---
name: seo-audit
description: Static technical-SEO scanner for the rendered document — missing/weak title + meta description, absent canonical, no Open Graph / Twitter cards, missing or invalid JSON-LD structured data, accidental noindex, missing sitemap/robots, i18n hreflang gaps, and CSR-only content on crawl-critical routes. Turns "improve SEO" prose into cited grep detectors + the framework's real metadata primitive.
---

# seo-audit

## Premise

**SEO is machine-read. The crawler sees the HTML the server sends — not your runtime state.** The dominant failure is a route that looks fine in the browser but ships an empty/duplicate/misconfigured `<head>` (or an empty `<body>` on a CSR-only page) to Googlebot, social scrapers, and LLM crawlers. Every finding cites the element at `<file:line>` + the matched pattern + the fix in **this project's own metadata primitive**. "SEO is weak" without the cited tag is not a finding.

This is a *static* scan of source + the rendered document. Pair it with `rendering-strategy` (is the route even server-rendered/prerendered so the crawler sees content?) and `lcp-audit`/`lighthouse-ci` (page-speed is a ranking signal). Structured-data findings should be re-checked against Google's Rich Results Test / Schema.org validator before shipping.

## Adapt to the codebase first (do NOT impose a generic template)

Before flagging anything, read how this project already sets metadata and **mirror that primitive** — never introduce a second mechanism:

1. Detect the framework + router (`_extracted-codebase.md`, `package.json`, file layout).
2. Find the existing metadata surface and match it exactly:

   | Framework | Metadata primitive to mirror | Sitemap / robots |
   |---|---|---|
   | **Next.js (App Router)** | `export const metadata` / `export async function generateMetadata()`; `app/opengraph-image.tsx`; `alternates.canonical` + `alternates.languages` | `app/sitemap.ts`, `app/robots.ts` (native) |
   | **Next.js (Pages Router)** | `next/head` `<Head>`; or `next-seo` `<NextSeo>` / `DefaultSeo` if already used | `next-sitemap` |
   | **Nuxt 3** | `useSeoMeta()` / `useHead()`; `definePageMeta`; per-page in `<script setup>` | `@nuxtjs/sitemap`, `@nuxtjs/robots` |
   | **SvelteKit** | `<svelte:head>` in `+page.svelte`; `+page.ts` `load` returning meta; `prerender` | `src/routes/sitemap.xml/+server.ts` |
   | **Astro** | frontmatter `<head>` in layout; `<SEO>` from `astro-seo` if used | `@astrojs/sitemap` |
   | **Remix / React Router** | route `meta` export (`MetaFunction`); `links` for canonical | resource route |
   | **Plain React (Vite/CRA)** | `react-helmet-async` `<Helmet>` (SSR-only value if not prerendered) | build script |
   | **Angular (Universal/SSR)** | `Title` + `Meta` services; `provideClientHydration`; SSR is mandatory for these to reach crawlers | `sitemap` route / build |

3. If the project has a **shared SEO component/composable** (`<Seo>`, `useSeo`, a `defaultSeo` config), route every fix through it. Only propose a shared primitive if none exists and the same tags are copy-pasted across ≥3 routes.

## Scans for

### 1. Missing, duplicate, or weak `<title>` / meta description

Each indexable route needs a **unique** `<title>` (~50–60 chars) and a meta description (~120–160 chars). Templated-but-unfilled (`%s | Site`) or a single global title across routes is a duplicate-content signal.

```
BAD:  export const metadata = { title: "Home" }            // same title on every page
GOOD: export const metadata = { title: "Blue Running Shoes — Acme", description: "…150 chars…" }
```

Grep for routes with no title export / no `<title>` in head, and for one hard-coded title shared across many routes. Flag missing OR non-unique OR out-of-length-band.

### 2. Missing / wrong canonical URL

Every indexable route should declare `<link rel="canonical">` to its preferred absolute URL — the single biggest defense against duplicate content from query params, trailing slashes, and pagination.

```
GOOD (Next App Router): metadata = { alternates: { canonical: 'https://acme.com/shoes/blue' } }
GOOD (raw):             <link rel="canonical" href="https://acme.com/shoes/blue">
```

Flag: no canonical on an indexable route; a canonical pointing at a *different* page (accidental consolidation); relative canonical (must be absolute); canonical that includes tracking params.

### 3. Missing Open Graph + Twitter Card tags

Without OG/Twitter tags, shared links render as bare URLs (kills click-through). Minimum: `og:title`, `og:description`, `og:image` (absolute URL, ~1200×630), `og:url`, `og:type`; `twitter:card` (`summary_large_image`).

```
GOOD: og:title, og:description, og:image (absolute), og:url, og:type=website|article
      twitter:card=summary_large_image
```

Flag any indexable/shareable route missing the OG core or using a relative `og:image`.

### 4. Missing or invalid JSON-LD structured data

Structured data unlocks rich results (and feeds LLM crawlers). Match the schema to the page type — don't bolt `Article` onto a product page.

```
GOOD (in <head> or end of <body>):
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Product","name":"…","offers":{"@type":"Offer","price":"49.00","priceCurrency":"USD"}}
</script>
```

| Page type | Schema.org @type |
|---|---|
| Blog / news post | `Article` / `BlogPosting` / `NewsArticle` |
| Product / PDP | `Product` + `Offer` (+ `AggregateRating`) |
| Any page with breadcrumb nav | `BreadcrumbList` |
| Home / global | `Organization` + `WebSite` (+ `SearchAction` for sitelinks searchbox) |
| FAQ / how-to | `FAQPage` / `HowTo` |
| Local business | `LocalBusiness` |

Flag: no JSON-LD on a page type that has a matching schema; JSON-LD whose `@type` mismatches the page; required-property gaps (e.g. `Product` with no `offers`); JSON-LD describing content not actually on the page (structured-data spam → manual action risk).

### 5. Accidental `noindex` / crawl blocking

The scariest SEO bug: a production route silently de-indexed. A leftover `noindex` from a staging config, or a `robots.txt` `Disallow: /` copied from a template, removes the page from Google.

```
BAD (on prod):  <meta name="robots" content="noindex">      // or X-Robots-Tag: noindex header
BAD (robots.txt): Disallow: /
```

Flag any `noindex` / `X-Robots-Tag: noindex` on a route meant to be public; and — inversely — a **missing** `noindex` on routes that must NOT be indexed (staging, `/admin`, `/checkout`, search-result/filter permutations, `?`-param faceted URLs).

### 6. Sitemap + robots.txt

- **sitemap.xml**: present, references *dynamic* routes (not just static pages), valid `<loc>` absolute URLs, optional `lastmod`; split at 50k URLs / 50MB. Flag a hand-maintained static sitemap that omits dynamically generated routes.
- **robots.txt**: present, does not block CSS/JS needed to render, and points to the sitemap (`Sitemap: https://…/sitemap.xml`).

### 7. i18n hreflang (ties into the i18n pack)

If the project ships multiple locales, each localized URL must list `hreflang` alternates for every locale + an `x-default`, and the set must be **reciprocal** (every alternate points back).

```
GOOD: <link rel="alternate" hreflang="en" href="https://acme.com/en/shoes">
      <link rel="alternate" hreflang="fr" href="https://acme.com/fr/chaussures">
      <link rel="alternate" hreflang="x-default" href="https://acme.com/shoes">
```

Flag localized routes missing hreflang, non-reciprocal sets, wrong region codes (`en-uk` → must be `en-GB`), or missing `x-default`.

### 8. Crawlability — CSR-only content on an SEO route

A route whose meaningful content only appears after client-side fetch/render ships an empty shell to crawlers that don't execute JS (most social/LLM scrapers; Googlebot renders but with delay + budget limits).

Flag public content routes (blog, product, marketing, docs) that are CSR-only — no SSR/SSG/prerender. **This is a `rendering-strategy` handoff**, not a tag fix: the answer is to server-render or prerender, then the head/body reach the crawler.

### 9. Semantic + link signals (overlaps a11y, deliberately)

- Exactly **one `<h1>`** per page, describing the page; headings nest without skipping.
- Descriptive link text (`rg '>(click here|read more|here)<'` → flag); no naked `<div onclick>` navigation (crawlers follow `<a href>`).
- Images that carry meaning have descriptive `alt` (also an a11y + image-SEO signal); pair with `lcp-audit` for the LCP image.

## Output

```
seo-audit — <route set>   (framework: <detected>, primitive: <e.g. Next generateMetadata>)

Findings: 5

1. app/blog/[slug]/page.tsx:1                          [report-with-fix]
   No generateMetadata — every post ships the layout's default title "Acme Blog" (duplicate titles across all posts).
   Fix: export async function generateMetadata({params}) → unique title + description from the post; alternates.canonical.

2. app/products/[id]/page.tsx:40                       [report-with-fix]
   Product page has no JSON-LD. No rich result eligibility.
   Fix: emit <script type="application/ld+json"> Product + Offer (name, image, price, priceCurrency, availability).

3. next.config.js / app/robots.ts (absent)            [report-with-fix]
   No robots.ts and no sitemap.ts — nothing tells Google what to crawl.
   Fix: add app/robots.ts (allow, point at sitemap) + app/sitemap.ts enumerating dynamic product/blog routes.

4. app/(marketing)/page.tsx:12                         [halt-handoff]
   Marketing home is CSR-only ('use client' at the root, content from useEffect fetch) — crawlers see an empty shell.
   Handoff: rendering-strategy — server-render or prerender this route before any tag fix matters.

5. components/LocaleSwitcher + app/[lang]/…            [report-with-fix]
   fr/es locales render but no hreflang alternates → Google can't pair localized URLs.
   Fix: alternates.languages in generateMetadata (en, fr, es + x-default), reciprocal.
```

## False positives / gotchas

- **Don't demand a canonical that points elsewhere.** A self-referencing canonical is correct and expected; only flag canonicals that consolidate to a *different* URL by mistake.
- **`noindex` is correct on many routes** — staging, auth-gated, thank-you, faceted-filter permutations. Flag missing-noindex there, not present-noindex.
- **JSON-LD must describe visible content.** Proposing markup for data the page doesn't show is structured-data spam (manual-action risk) — never invent ratings/prices.
- **Client-set meta tags may or may not reach crawlers.** `react-helmet` on a non-prerendered SPA sets tags after JS runs — social scrapers won't see them. If the route isn't SSR/prerendered, the fix is rendering-strategy, not more tags.
- **Trailing-slash + www/non-www + http/https** are the same page to users but four URLs to Google — canonical + one 301 target resolves it; don't file four separate findings.
- Length bands (title 50–60, description 120–160) are guidance, not hard limits — flag *missing* or *obviously wrong* (empty, 8 chars, 300 chars), not a 62-char title.

## When to run

- Before launching any public, indexable route (marketing, blog, product, docs).
- After a routing/rendering refactor (App↔Pages router, CSR→SSR, i18n rollout).
- When Search Console reports "Discovered – not indexed", "Duplicate without canonical", "Excluded by noindex", or missing rich results.
- Alongside `lighthouse-ci` (its SEO + best-practices categories) and `rendering-strategy` on any new public route.

## Halt conditions

- Halt on any finding without the cited tag/route at `<file:line>` + the matched pattern + the fix in the project's own metadata primitive.
- Halt if a fix introduces a **second** metadata mechanism instead of the one already in use (e.g. raw `<Head>` tags in an App-Router project that uses `generateMetadata`).
- Halt if a JSON-LD proposal asserts data (price, rating, author, date) not present on the page.
- Halt if the real problem is crawlability (CSR-only) — hand off to `rendering-strategy` instead of proposing tags the crawler will never see.
- Halt if a `noindex`/`Disallow` "fix" would de-index a route the project intends to rank.

## Related

- `@technical-seo` — the agent that owns the judgment calls (indexation strategy, canonical policy, structured-data choice) and dispatches this skill for the mechanical sweep. This is the reverse link that agent's `## Related` already assumes: findings flow scan -> agent, decisions flow agent -> scan.
- `rendering-strategy.md` (ai-pattern) — a route that must rank cannot be CSR-only. When this scan finds an empty server HTML body, the fix is a rendering-strategy change first, a metadata change second.
- `streaming-ssr` — streamed HTML still contains the head; a boundary that defers `<title>`/canonical into a streamed chunk is this skill's finding, that skill's fix.
- `i18n.md` (ai-pattern) + `@i18n-auditor` — `hreflang` reciprocity is only checkable against the declared locale set; the locale list comes from there.
- `image-optimization` — OG/Twitter image dimensions and `alt` text overlap; this skill grades the social card, that skill grades delivery.
- `.claude/rules/frontend-principles.md` — the unique-title/description, canonical, OG/Twitter, JSON-LD, `noindex`, sitemap+robots and SSR-for-indexable-routes MUSTs.
