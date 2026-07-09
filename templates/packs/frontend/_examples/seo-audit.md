---
name: seo-audit
description: Static technical-SEO scanner for the rendered document — missing/weak title + meta description, absent canonical, no Open Graph / Twitter cards, missing or invalid JSON-LD, accidental noindex, missing sitemap/robots, i18n hreflang gaps, and CSR-only content on crawl-critical routes. Turns "improve SEO" prose into cited detectors + the framework's real metadata primitive.
---

# seo-audit

## Premise

SEO is machine-read: the crawler sees the HTML the server sends, not your runtime state. Every finding cites the tag/route at `<file:line>` + the matched pattern + the fix **in this project's own metadata primitive**. Static scan — pair with `rendering-strategy` (is the route even server-rendered?) and `lighthouse-ci`.

## Adapt first

Read + mirror the existing metadata primitive; never add a second mechanism: Next `generateMetadata` / `app/sitemap.ts` / `robots.ts`; Nuxt `useSeoMeta`/`@nuxtjs/sitemap`; SvelteKit `<svelte:head>`; Astro layout head; Angular `Meta`+`Title` (SSR required); `react-helmet-async` (SSR/prerender only); or a shared `<Seo>` if one exists.

## Scans for

1. Missing / duplicate / weak `<title>` + meta description (unique per route; ~50–60 / 120–160 chars).
2. Missing or wrong `<link rel="canonical">` (absolute, self-referencing, no tracking params).
3. Missing Open Graph + Twitter cards (`og:title/description/image`(absolute)/`url`/`type`; `twitter:card`).
4. Missing / invalid JSON-LD — `@type` matches page (Article / Product+Offer / BreadcrumbList / Organization+WebSite / FAQPage); required props present; describes visible content only.
5. Accidental `noindex` / `Disallow: /` on a public route — and missing `noindex` on private/faceted routes.
6. sitemap.xml (includes dynamic routes, absolute locs) + robots.txt (points at sitemap, doesn't block CSS/JS).
7. i18n hreflang — reciprocal alternates for every locale + `x-default`; correct region codes.
8. Crawlability — CSR-only content on a public route ships an empty shell → **rendering-strategy handoff**, not a tag fix.
9. Semantic/link signals — one `<h1>`, descriptive anchors, crawlable `<a href>`, meaningful `alt`.

## Output

```
seo-audit — <routes>  (framework: <x>, primitive: <e.g. Next generateMetadata>)
1. app/blog/[slug]/page.tsx:1  — no generateMetadata → all posts share one title. Fix: unique title/description + canonical.
2. app/products/[id]/page.tsx:40 — no Product JSON-LD. Fix: emit Product+Offer from data already on the page.
3. app/(marketing)/page.tsx:12 [handoff] — CSR-only → empty shell to crawlers → rendering-strategy.
```

## Gotchas

- Self-referencing canonical is correct; only flag consolidation to a *different* URL.
- `noindex` is right on staging/admin/checkout/faceted routes — flag missing-noindex there.
- Never invent JSON-LD values (price/rating/author) — structured-data spam is a manual-action risk.
- Client-set meta on a non-prerendered SPA won't reach scrapers → fix is rendering-strategy.

## Halt conditions

- No finding without `<file:line>` + pattern + fix in the project's own primitive.
- Don't introduce a second metadata mechanism; don't propose JSON-LD for absent data; hand CSR-only crawlability to `rendering-strategy`; don't `noindex` a route meant to rank.
