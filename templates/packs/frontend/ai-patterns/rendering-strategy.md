---
name: rendering-strategy
description: Pattern: Rendering Strategy
kind: ai-pattern
pack: frontend
---

# Pattern: Rendering Strategy

> **Hard rule:** Every route **declares its rendering contract** — which regions are static, which are dynamic, where the streaming boundary sits — and documents why. An *undeclared* mix is forbidden; a *declared* one is now the mainstream shape (a static shell with dynamic holes behind Suspense is what partial prerendering ships). Changing a route's contract without measuring the TTFB / LCP impact is forbidden either way.

**When to apply**
- A new route is being added and the choice (SSG vs SSR vs CSR vs streaming) materially changes performance, SEO, or freshness guarantees.
- An existing route's Core Web Vitals regress and the cause is rendering choice (e.g., CSR for an SEO page).
- Adding a personalized section to a previously static page — the whole route's strategy must be reconsidered.

**When NOT to apply**
- Internal admin tools behind auth with no SEO and no perf SLO — CSR is fine, document and move on.
- A short-lived experiment where measuring rendering tradeoffs costs more than shipping.

**Halt conditions / mandatory cites**
- The chosen strategy MUST cite the route file at `<path:line>` AND the metric (LCP, TTFB, freshness window) it optimizes.
- Any "ISR with revalidate=N" choice MUST cite the staleness tolerance from product, not a guess.
- A doc proposing strategy change without before/after Core Web Vitals numbers is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when classifying a route.
- If the framework's actual rendering primitive (App Router vs Pages, Nuxt 3 mode, etc.) isn't extracted, halt.

Declare the contract per route. Mixing *without declaring it* is what breaks — an undeclared mix means nobody knows which regions are cacheable, so the cache invalidation, the SEO claim, and the freshness guarantee are all unowned.

## Where the static/dynamic seam goes (the decision the SSG-vs-SSR question turned into)

The strategy menu used to be the decision: one label per route, and the label picked itself once you knew whether the page was personalised. It stopped being the decision once frameworks let one route be **both** — a prerendered shell served from cache with per-request holes rendered on demand (Next's Cache Components / partial prerendering, Astro server islands, Nuxt islands). The label is now nearly free to pick; **where the seam falls inside the route is the part that is still hard, still wrong in most codebases, and still not written down anywhere.**

This pattern owns *which regions are dynamic and why*. The `streaming-ssr` skill owns *where the boundary physically goes and whether the route is blocking TTFB* — the same split as `code-splitting` (decides the cut) and `bundle-analyze` (measures it). Do not re-derive its boundary mechanics here.

**Rule 1 — the seam is drawn by what a subtree READS, not by how often it changes.** A region is dynamic if it reads a per-request input: the session, `cookies()` / `headers()`, `searchParams`, client IP or geo, the clock at request granularity. This is transitive, and it is the part that surprises people: a header that is 99% static logo-and-nav becomes fully dynamic the moment it renders a cart badge, because the badge reads the session and the badge is inside the header. The fix is not to make the header dynamic — it is to make the *badge* the hole.

**Rule 2 — the two errors are not symmetric, so default toward the one that is visible.**

| Seam drawn | What it costs | How you find out |
|---|---|---|
| **Too high** (the hole swallows a large static region) | Nothing prerenders. The route pays a full per-request render and the cache never serves it. | **You don't.** The page is correct, and fast enough in dev. The only symptom is a TTFB that never improved after the migration — which is exactly why this is the common failure. |
| **Too low** (many small holes) | More boundaries, each needing a dimension-reserving fallback; more CLS surface; more fallback markup to maintain. | Immediately — the page flickers in review. |

Draw it low and merge upward on evidence. A too-high seam is a silent no-op wearing the shape of a completed migration.

**Rule 3 — per-request is not the same as per-user, and only one of them needs a hole.** A value that changes per request but is identical for everyone — a stock count, an hourly price, a live total — does not need a dynamic hole; it needs a shorter revalidation window on the static shell. Reaching for a hole there buys per-request render cost for freshness revalidation already supplies. Ask which of the two it is before cutting, and record the answer: this is the most common over-cut.

**Rule 4 — every hole declares its fallback's dimensions.** A hole with an unsized fallback trades TTFB for CLS, which is not a win — it is a different failed metric. The fallback is part of the seam decision, not a detail of it.

**Rule 5 — the contract is declared per route, in the route.** This is the hard rule at the top, enforced: the route states which regions are static, which are holes, and what per-request input each hole reads. An undeclared mix means nobody knows which regions are cacheable, so cache invalidation, the SEO claim and the freshness guarantee are all unowned — and the next person to add a personalised widget will add it above the seam.

**When the route has no seam at all** — no per-request input anywhere, or every region reads one — the route is plainly static or plainly dynamic, and this section does not apply. Say which and move on. Manufacturing a seam on a fully-personalised dashboard is ceremony.

## Scope

This pattern owns the **initial-render** axis (the first paint of a route) and, within it, the seam above. Strategy is per route, never per app — every framework in this pack's set (Next App Router, Nuxt, SvelteKit, Remix, Astro) supports per-route choice, so "the app is SSR" describes a default, not a decision. The **page-to-page navigation** axis (prefetch, bfcache, instant-loading, View Transitions) belongs to the `navigation-speed` skill; the **boundary mechanics** to `streaming-ssr`; **hydration correctness** to `ssr-safety.md`. A finding on any of those three is handed over, not restated.

## TTFB levers (ranked)

When TTFB is the bottleneck (server slow to first byte, blocking LCP), apply in this order. Each lever cites the metric it moves — `<file:line>` where the lever lives + the metric, per the cite-or-halt rule:

1. **Parallelize data** (`Promise.all` / React `use()` / `Nuxt useFetch` parallel) — collapse the server-render waterfall. Moves **TTFB** (server stops blocking on serial awaits). Cite the serial-await site at `<route-or-loader:line>`.
2. **Edge render** — move SSR to the CDN edge, cutting the client→origin RTT. Moves **TTFB** (origin distance drops). Cite the render runtime at `<config:line>`. The constraint that decides whether the lever is available at all: edge runtimes are Web-Standard-only, so a route whose render touches a Node API or a non-edge DB driver cannot move without changing both. Check that first — this lever is refused more often than it is applied.
3. **`Cache-Control: stale-while-revalidate`** — serve the cached document instantly while regenerating in the background. Moves **TTFB** (cache hit, no render on the hot path). Cite the header value at `<response-or-config:line>`.
4. **103 Early Hints** — a HOST/CDN feature (Vercel, Cloudflare) that emits a `Link: rel=preload` / `rel=preconnect` header *before* the `200`, so the browser starts critical-resource fetches during server think-time. Moves **LCP** (resource discovery overlaps TTFB), not TTFB itself. This is DISTINCT from a framework injecting `<link rel=preload>` tags into the HTML `<head>` — 103 is a transport-level interim response from the host, not a `next.config` / framework emission. Cite the host config enabling it at `<host-config:line>`.

For streaming-boundary placement (which shell flushes first, where Suspense splits the stream), see the **streaming-ssr.md** skill.

## Forbidden

- Mixing strategies without a route-level declaration (ambiguity = bugs). A declared static-shell-plus-dynamic-holes contract is not this — it is the shape the framework ships (see the Next.js 16 notes on Cache Components completing the partial-prerendering story).
- CSR for SEO-critical pages. *(When a route must rank, server-render/prerender it, then run the `seo-audit` skill / `@technical-seo` agent on the head + body the crawler now receives.)*
- SSR for content that never personalizes (waste of server cost).
- ISR without a cache invalidation path (content goes stale forever).
- **Re-fetching on mount data the server already rendered** (defeats the point — the user pays for the same bytes twice and sees a flash). Revalidation on focus / interval / mutation is *required*, not forbidden: hydrate from the server payload, then let the query cache own staleness after hydration per `data-fetching.md`. The distinction is initial-read vs revalidation, and only the first belongs to the server.
- Hardcoded dates / random values in SSR output.

## Detectors (cite-or-halt)

Each finding cites the route file at `<path:line>` + the matched pattern + the fix. A strategy claim with no cited route is a vibe, not a finding.

1. **Undeclared strategy.** BAD: a route file with no mode export, no comment, no config row — whatever the framework defaults to is what ships. GOOD: the mode is declared at the route, with the per-request input each hole reads. Grep: list every route file, subtract those carrying the framework's declaration (`export const dynamic`/`revalidate`/`prerender`, `definePageMeta`, `export const prerender`, `server:defer`); the remainder are undeclared. `report-flagged` — the fix is a declaration, and only the route's owner can make it.
2. **Whole route forced dynamic for one per-request read.** BAD: `dynamic = 'force-dynamic'` (or the stack's equivalent) on a route whose only per-request input is a greeting, a cart badge, or a locale banner. GOOD: the shell prerenders and that one region is the hole. Grep: force-dynamic routes, then count subtrees that actually read a per-request input — exactly one is this finding. `report-with-fix`; hand the boundary placement to `streaming-ssr`.
3. **A hole cut for per-request-but-not-per-user data** (Rule 3). BAD: a dynamic hole around a stock count identical for every visitor. GOOD: a shorter revalidation window on the static region. Grep: for each declared hole, name the per-request input it reads; a hole whose answer is "none, it just changes often" is this finding. `report-with-fix`.
4. **Hole with an unsized fallback** (Rule 4). Grep: each boundary's fallback for a reserved width/height or `aspect-ratio`; absent → the route traded TTFB for CLS. `report-with-fix`.
5. **CSR-only on a crawl-critical route.** BAD: a public content route whose server HTML body is empty. GOOD: server-rendered or prerendered, and only then do the tags matter. The `seo-audit` skill's detector 8 finds this and hands it here; this pattern owns the fix. Never answer it with more `<head>` tags.
6. **Re-fetch on mount of server-rendered data.** BAD: a component that server-renders a list and then fetches the same list in an effect on mount — the user pays for the same bytes twice and sees a flash. GOOD: hydrate from the payload; let the query cache own staleness *after* hydration, per `data-fetching.md`. Grep: an effect / `onMounted` fetch whose key matches data already in the route's server payload. `report-with-fix` — and revalidation on focus / interval / mutation is correct, so it is `dismiss`, not a finding. The distinction is initial-read vs revalidation, and only the first belongs to the server.
7. **Strategy change proposed with no before/after numbers.** `[self-policed]` — it fires on the proposal, not the codebase, and no grep can decide it. A migration doc with no measured TTFB/LCP on either side is `halt-missing-cite`.

## Closure verbs

Exactly one verb per finding. This pattern emits `report-with-fix`, `report-flagged` (an undeclared contract, or a strategy change whose staleness tolerance is a product decision), `dismiss` (a documented CSR admin route, a revalidation refetch, a route with no seam), `halt-handoff` (boundary mechanics → `streaming-ssr`; hydration → `ssr-safety.md`; navigation → `navigation-speed`; tag findings → `seo-audit`), and `halt-missing-cite`.

## Related

- `data-fetching.md` — owns client-side refetch/dedup/staleness after hydration; don't client-fetch what this route already server-rendered.
- `list-virtualization.md` — when a crawlable/SEO list can't be windowed, server-paginate + server-render it here instead.
- `code-splitting.md` — a route's rendering strategy and its code-split boundaries must stay consistent (initial-render axis vs JS-chunk axis).
