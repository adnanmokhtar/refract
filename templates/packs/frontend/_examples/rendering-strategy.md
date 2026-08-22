---
name: rendering-strategy
kind: example
pack: frontend
---

# Pattern: Rendering Strategy

> **Hard rule:** Every route **declares its rendering contract** — which regions are static, which are dynamic, where the streaming boundary sits — and documents why. An *undeclared* mix is forbidden; a *declared* one is now the mainstream shape (a static shell with dynamic holes behind Suspense is what partial prerendering ships). Changing a route's contract without measuring the TTFB / LCP impact is forbidden either way.

**Halt conditions / mandatory cites**
- The chosen strategy MUST cite the route file at `<path:line>` AND the metric (LCP, TTFB, freshness window) it optimizes.
- Any "ISR with revalidate=N" choice MUST cite the staleness tolerance from product, not a guess.
- A doc proposing strategy change without before/after Core Web Vitals numbers is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when classifying a route.
- If the framework's actual rendering primitive (App Router vs Pages, Nuxt 3 mode, etc.) isn't extracted, halt.

## Where the static/dynamic seam goes (the decision the SSG-vs-SSR question turned into)

Picking a label per route used to be the decision. It stopped being one once a route could be **both** — a prerendered shell served from cache with per-request holes rendered on demand (Next Cache Components / partial prerendering, Astro server islands, Nuxt islands). The label is now nearly free; **where the seam falls inside the route is the part that is still hard and still wrong in most codebases.**

This pattern owns *which regions are dynamic and why*. The `streaming-ssr` skill owns *where the boundary physically goes and whether the route blocks TTFB*.

**Rule 1 — the seam is drawn by what a subtree READS, not by how often it changes.** A region is dynamic if it reads a per-request input: the session, `cookies()` / `headers()`, `searchParams`, IP/geo, the clock at request granularity. It is transitive: a header that is 99% logo-and-nav becomes fully dynamic the moment it renders a cart badge. The fix is to make the *badge* the hole, not the header.

**Rule 2 — the two errors are not symmetric.** A seam drawn **too high** swallows the static region: nothing prerenders, the route pays a full per-request render, and **you never find out** — the page is correct and only the TTFB that never improved gives it away. A seam drawn **too low** costs extra boundaries and fallback markup, and shows up immediately as flicker in review. Draw it low and merge upward on evidence.

**Rule 3 — per-request is not per-user, and only one needs a hole.** A stock count or hourly price that changes per request but is identical for everyone needs a shorter revalidation window, not a dynamic hole. Cutting a hole there buys per-request render cost for freshness revalidation already supplies.

**Rule 4 — every hole declares its fallback's dimensions**, or the route traded TTFB for CLS.

**Rule 5 — the contract is declared per route, in the route**, naming what per-request input each hole reads. Otherwise the next personalised widget lands above the seam.

A route with no per-request input anywhere, or one where every region reads one, has no seam — say which, and move on.

## Scope

Owns the **initial-render** axis and the seam above. Page-to-page navigation (prefetch, bfcache, instant-loading) belongs to `navigation-speed`; boundary mechanics to `streaming-ssr`; hydration correctness to `ssr-safety.md`. Findings on those three are handed over, not restated.

## TTFB levers (ranked)

Each lever cites where it lives at `<file:line>` + the metric it moves.

1. **Parallelize data** (`Promise.all` / React `use()` / parallel `useFetch`) — collapses the server-render waterfall. Moves **TTFB**.
2. **Edge render** — cuts the client→origin RTT. Moves **TTFB**. Available only if the render touches no Node API and no non-edge DB driver; check that first, because this lever is refused more often than applied.
3. **`Cache-Control: stale-while-revalidate`** — serves the cached document instantly while regenerating. Moves **TTFB**.
4. **103 Early Hints** — a HOST/CDN interim response emitting `Link: rel=preload` before the `200`, so resource fetches overlap server think-time. Moves **LCP**, not TTFB — and it is distinct from a framework injecting `<link rel=preload>` into the `<head>`.

## Forbidden

- Mixing strategies without a route-level declaration (ambiguity = bugs) — a declared static shell + dynamic holes is not this.
- CSR for SEO-critical pages.
- SSR for content that never personalizes (waste of server cost).
- ISR without a cache invalidation path (content goes stale forever).
- Re-fetching on mount what the server already rendered (defeats the point). Revalidation on focus/interval/mutation is required, not forbidden.
- Hardcoded dates / random values in SSR output.

## Detectors (cite-or-halt)

1. **Undeclared strategy** — a route file with no mode export, comment, or config row. Grep every route file, subtract those carrying the framework's declaration (`export const dynamic`/`revalidate`/`prerender`, `definePageMeta`, `server:defer`). `report-flagged`.
2. **Whole route forced dynamic for one per-request read** — `force-dynamic` on a route whose only per-request input is a greeting or cart badge. `report-with-fix`; boundary placement goes to `streaming-ssr`.
3. **A hole cut for per-request-but-not-per-user data** (Rule 3) — the hole reads no per-request input, it just changes often. `report-with-fix`.
4. **Hole with an unsized fallback** (Rule 4) — no reserved width/height or `aspect-ratio`. `report-with-fix`.
5. **CSR-only on a crawl-critical route** — empty server HTML body on a public content route. `seo-audit` detector 8 hands it here; never answer it with more `<head>` tags.
6. **Re-fetch on mount of server-rendered data** — an effect/`onMounted` fetch whose key matches data already in the server payload. `report-with-fix`; revalidation on focus/interval/mutation is `dismiss`.
7. **Strategy change proposed with no before/after numbers** — `[self-policed]`; fires on the proposal, not the codebase. `halt-missing-cite`.

## Closure verbs

Exactly one verb per finding. Emits `report-with-fix`, `report-flagged`, `dismiss`, `halt-handoff` (boundary → `streaming-ssr`; hydration → `ssr-safety.md`; navigation → `navigation-speed`; tags → `seo-audit`), `halt-missing-cite`.
