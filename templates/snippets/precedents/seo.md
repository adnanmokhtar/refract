# Precedents — SEO (titles, canonicals, social cards, structured data, indexation, sitemaps, hreflang, rendering for crawlers)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10 for
every candidate in a **technical-SEO** class: a defect in what a crawler that runs no JavaScript
receives from the server. The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § SEO (V180–V188); the detector is `seo-audit` (frontend
pack), judged by `@technical-seo`. The three cross-domain precedents are in
`refute-before-report.md § 4`; accessibility, routing and rendering precedents are in
[`ui.md`](ui.md).

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening** (or Refuted, where the entry says so); the flip
evidence makes it a candidate again. A precedent applies only when its "must be true" clause is
shown with a `file:line` or a `seo-head.py` row. Numbers are stable: detectors cite
`precedents/seo.md § <n>`.

Index: the claim and the gates · posting rules § 1–6 · titles, canonicals and social cards § 7–12 ·
structured data and indexation § 13–17 · rendering and links § 18–21 · version and platform
precedents § 22–29.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that fits it with no concrete value is not a
finding.

> On **[the route and its route class — indexable, public not meant to rank, auth-gated, not a
> document]**, the **server HTML of a production build** (or its response headers) carries
> **[the defect: no title, the layout's title on N routes, a canonical with `?utm_source=`, a
> `noindex`, an empty body]** from **[the source at file:line, or the wrapper or layout it
> inherits]**, so a crawler that runs no JavaScript **[indexes the wrong URL / drops the page / shows
> no card / ignores the hreflang set]**, proven by **[the `seo-head.py` row on the route set]**.

**The proof rule.** A grep hit is a candidate. The `seo-head.py` row from a production build is the
proof (gate 6); a candidate with no build to fetch is **Unconfirmed** with the settling command
written out, never dropped and never promoted on reading alone. Rich-result eligibility and what
Google stored are manual rows (Rich Results Test, URL Inspection), reported `manual-required`.

## Reading the seven gates for SEO

| Gate | SEO |
|---|---|
| 1 Reachability | The route is served in production and its route class makes the class matter (`seo-audit` § Route class decides which classes run); a page file the router never serves is not reached |
| 2 Trigger condition | A crawler really receives it: the defect is in the server HTML or the headers, not only in client state after hydration |
| 3 Version | The framework's metadata behaviour on the installed version (§ 22–24), read from the lockfile; Google's current documentation for the feature, read at audit time with its updated date |
| 4 No existing control | The layout's metadata, the project's SEO wrapper, the framework default (Next `metadataBase`), an SEO module (`@nuxtjs/seo`, `@nuxtjs/i18n` hreflang) or a server header already gives the right answer |
| 5 Real impact | An indexable route mis-indexed, dropped, duplicated or shown without a card; a private route left indexable. Length bands and "best practice" alone fail here |
| 6 Proof | The `seo-head.py` row for the route set on a production build, failing first (`proof-oracles.md` § SEO) |
| 7 Deployment and environment | The host, CDN or route rule that adds or strips a header (`X-Robots-Tag`, redirects); environment-gated `noindex` read for the production environment |

## Do not flag — posting rules the verifier applies

1. **Pre-existing lines.** On a diff run, a defect on lines the change neither touched nor copied is Pre-existing (`refute-before-report.md § 5`).
2. **A class outside its route class.** A title band on an admin dashboard, Open Graph tags on a thank-you page, social cards on an auth-gated route: `seo: N/A (<route class>)`, never a finding.
3. **Page speed as a ranking input** belongs to `lcp-audit`, `lighthouse-ci` and `/bundle-perf` (performance pack, when installed); it is not graded here.
4. **Headings and `alt` text as accessibility** are filed once, by `a11y-code-scan` / `a11y-scan`; the SEO row only asks whether a crawler can find the links (`precedents/ui.md` § 5, § 11).
5. **Robots directives aimed at AI crawlers** (`GPTBot` rules, `llms.txt`, `Content-Signal`): no crawler is obliged to honour them, so there is no conformance to prove.
6. **Duplicates.** One finding per root cause: a layout default or a wrapper fallback shared by N routes is one finding with N routes, fixed in the wrapper.

## Not a finding — titles, canonicals and social cards

7. **A title outside the 50–60 character band** is guidance, not a limit.
8. **A duplicate title between a layout and the one page that overrides it**, or a dynamic title the oracle shows unique across the route set. *Flips back:* `title-dup` prints for two indexable routes.
9. **A self-referencing canonical** is expected (Google recommends one).
10. **A relative canonical that the framework resolves**: Next resolves it against `metadataBase`, an SEO module against its site URL. *Must be true:* the server HTML shows the absolute URL (`canonical-relative` does not print).
11. **A print or AMP view whose canonical points at its article** is the intended `canonical-elsewhere`, not a defect.
12. **Trailing-slash, `www` and `http` variants** are one canonical plus one redirect target: at most one finding, never four.

## Not a finding — structured data and indexation

13. **FAQ, How-to and `SearchAction` markup left on the page** is Hardening (dead weight to keep), never a defect and never something to propose (§ 25).
14. **`Organization` on every page** is fine.
15. **`noindex` on staging, auth, thank-you, error and filter-permutation routes** is correct. *Flips back:* the environment gate is wrong, so the production build carries it on an `--expect-index` route.
16. **`Disallow` of `/api/` and `/admin/`** in robots.txt is correct; a `Disallow` of the asset folders the pages render with is not (§ 28).
17. **An `X-Robots-Tag: noindex` route rule for an auth segment** is correct.

## Not a finding — rendering and links

18. **An auth-gated SPA** has no route that must rank: the client-only-content class is `N/A (auth-gated)`.
19. **A stray `index.html` in a Nuxt or Next project** is never served by the framework: an empty shell there is Refuted on reading the router.
20. **`navigate(-1)` / `router.back()`** is not a link a crawler needs.
21. **A card that also holds a real link for the same target** passes through that link (`precedents/ui.md` § 17).

## Version and platform precedents — read at audit time

22. **Next.js `metadataBase`:** a relative URL in a metadata field with no `metadataBase` is a build error, so a relative canonical or `og:image` on a Next App Router route that builds is resolved; prove the opposite with the server HTML.
23. **Next.js streams `generateMetadata` output** into `<body>` for user agents it does not list as HTML-limited bots, and keeps it in `<head>` for those on `htmlLimitedBots` (Next.js docs, *generateMetadata*, 16.3.8, updated 2026-08-25). `meta-in-body` / `canonical-in-body` on a Next page is a candidate settled by URL Inspection, never a finding on one user agent's fetch.
24. **React 19 hoists `<title>`, and its children must be one string:** `<title>Results {n}</title>` is two children; `` <title>{`Results ${n}`}</title> `` is one (react.dev, *title*, read 2026-10-05).
25. **Rich results Google no longer shows.** The search gallery (updated 2026-06-15, read 2026-10-05) lists 25 features; FAQ, How-to and the sitelinks search box are not among them, nor the types retired in June 2025 (Book actions, Course info, Claim review, Estimated salary, Learning video, Special announcement, Vehicle listing). In 2023 Google limited FAQ results to well-known government and health sites and said unused structured data causes no problems (Search Central blog, 2023-08-08).
26. **A `noindex` in the first HTML may stop rendering**, so adding or removing it from JavaScript may not work (*JavaScript SEO basics*, updated 2026-03-04). A script that removes a server `noindex` is not a fix.
27. **`noindex` and `Disallow` conflict:** a page disallowed in robots.txt is never fetched, so its `noindex` is never read, and robots.txt alone does not keep a page out of the index (*Block indexing with noindex*, *Introduction to robots.txt*, both updated 2025-12-10).
28. **Sitemaps and robots.txt:** do not block resources whose absence makes a page harder to understand; a sitemap holds at most 50,000 URLs or 50 MB uncompressed and uses absolute URLs; its `<priority>` and `<changefreq>` are ignored, so their values are never a finding (*Introduction to robots.txt*; *Build and submit a sitemap*, updated 2026-07-08).
29. **hreflang:** a language code in ISO 639-1 with an optional ISO 3166-1 alpha-2 region, fully qualified URLs, each version listing itself and every other or the set is ignored, and `x-default` for unmatched languages (*Tell Google about localized versions*, updated 2026-09-21). A module that generates the set from each locale's `language` field (`@nuxtjs/i18n`) is correct only when that field is a valid code: read the config.

## Rationalizations to reject (SEO)

**Wrongly accepting:** "the title is 72 characters" · "every page should have FAQ markup" · "a
lint or SEO plugin flagged it" · "the browser tab shows the wrong title" (what does the server HTML
say?) · "Google can't render JavaScript" (it can; the question is what the first HTML says and who
else crawls) · "add `priority` to the sitemap".

**Wrongly dismissing:** "Google renders JavaScript, so the empty shell is fine" (social scrapers and
many crawlers do not, and a first-HTML `noindex` may stop rendering) · "the tab title is right" ·
"the layout sets a title" (the same one on 200 posts) · "it's only staging" (is the gate right for
production?) · "the canonical is set" (from the request URL, with `?utm_source=`?) · "the module
handles hreflang" (from which config field?) · "we submitted the sitemap" (does a sampled `<loc>`
answer 200?).

---

Sources: `seo-audit` (frontend pack) § False positives and § 1–§ 9, written 2026-10-05, moved here on
2026-10-10; the Google Search Central pages and the Next.js and React pages named in § 22–29, with the
updated dates that skill read on 2026-10-05. Paraphrased; no text reproduced beyond short quoted
identifiers.
