---
name: rendering-strategy
description: Pattern: Rendering Strategy
kind: ai-pattern
pack: frontend
---

# Pattern: Rendering Strategy

> **Hard rule:** Pick ONE rendering strategy per route (SSG, SSR, ISR, CSR, streaming) and document why. Mixing strategies in a single route or silently changing one without measuring TTFB / LCP impact is forbidden.

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

Pick ONE per route. Mixing without understanding = slow, broken, or unshippable.

## The options

| Strategy | Where HTML comes from | When |
|---|---|---|
| **CSR** (client-side render) | Client fetches + renders at runtime | Admin panels, dashboards behind auth, highly interactive apps |
| **SSR** (server-side render) | Server renders per request | Content personalized per user / request, SEO matters |
| **SSG** (static site gen) | Built at deploy time, served as HTML | Marketing, docs, blog — content that rarely changes |
| **ISR** (incremental static regen) | Built at deploy + regenerated on demand | Mostly-static content with occasional updates (product pages, listings) |
| **Streaming SSR** | Server streams HTML as it's ready | Large pages where above-the-fold is fast, rest can stream |
| **Islands / Partial Hydration** | Static HTML + hydrate only interactive bits | Marketing + some interactive widgets (Astro, Fresh, Qwik) |
| **Edge SSR** | SSR at the CDN edge, near the user | Global audience, personalized content, low-latency needs |

## Decision tree

```
Is the content personalized per request (user-specific, localized at request time)?
├─ YES → SSR (or Edge SSR if global audience)
└─ NO
   ├─ Does the content update frequently (< 1h)?
   │  ├─ YES → ISR with short revalidate, OR SSR with aggressive caching
   │  └─ NO → SSG
   ├─ Is SEO required for this page?
   │  ├─ YES → SSR / SSG (NOT CSR)
   │  └─ NO → CSR is fine
   └─ Is the page behind auth?
      └─ YES → CSR or SSR-with-auth (SSG can't personalize)
```

## Per-route, not per-app

Modern frameworks (Next App Router, Nuxt, SvelteKit, Remix) let you pick strategy per route. Use it:

- `/` landing → SSG (rebuild nightly)
- `/products` listing → ISR (revalidate every 60s)
- `/products/[slug]` detail → ISR with on-demand revalidation on product update
- `/cart`, `/account` → CSR or SSR with auth (personal, non-cacheable)
- `/docs/*` → SSG
- `/admin/*` → CSR (auth'd, interactive dashboard)

This pattern owns the **initial-render** axis (first paint of a route). The **page-to-page navigation** axis (prefetch, bfcache, instant-loading, View Transitions) is owned by the **navigation-speed.md** skill — keep the two in sync so a route's strategy choice and its navigation behavior don't drift.

## SSR pitfalls

- **Hydration mismatch** — server HTML ≠ client HTML on first render. Fix: deterministic render, no `Date.now()` / `Math.random()` / `window` in render.
- **Cascading API calls** in server render — waterfalls. Use parallel fetch (Promise.all, React `use()`, Nuxt `useFetch`).
- **Memory leaks** in long-lived server processes — serializing huge data structures to HTML repeatedly.
- **Auth cost** — checking auth on every SSR = every request hits auth service. Cache where safe.

## SSG pitfalls

- Build time scales with page count. 10k products = long builds. Use ISR.
- Can't personalize without client-side hydration.
- Full rebuild on content change = slow. Prefer incremental (ISR, on-demand revalidation).

## CSR pitfalls

- Initial blank screen (loading state). Show skeleton, not spinner.
- SEO impossible (crawlers vary in JS execution).
- Bundle size = time-to-interactive.
- Auth flash — user sees "not logged in" briefly before check completes. Use middleware / cookie check before render.

## ISR pitfalls

- First visitor after deploy sees stale cache, triggers regeneration. Budget it.
- On-demand revalidation needs a secure webhook.
- Cache misses under load = thundering herd. Use stale-while-revalidate semantics.

## Caching layers with SSR/ISR

```
Browser cache (via HTTP headers: Cache-Control, ETag)
   ↓
CDN (Cloudflare / Fastly / CloudFront) — per-URL, often per-country
   ↓
Framework cache (Next data cache, Nuxt payload, SvelteKit load cache)
   ↓
Application cache (Redis)
   ↓
Database
```

Invalidate upward when a cached item changes: DB write → app cache evict → framework revalidate → CDN purge (via tag).

## TTFB levers (ranked)

When TTFB is the bottleneck (server slow to first byte, blocking LCP), apply in this order. Each lever cites the metric it moves — `<file:line>` where the lever lives + the metric, per the cite-or-halt rule:

1. **Parallelize data** (`Promise.all` / React `use()` / `Nuxt useFetch` parallel) — collapse the server-render waterfall. Moves **TTFB** (server stops blocking on serial awaits). Cite the serial-await site at `<route-or-loader:line>`.
2. **Edge render** — move SSR to the CDN edge (see Edge SSR specifics), cutting the client→origin RTT. Moves **TTFB** (origin distance drops, <50ms typical). Cite the render runtime at `<config:line>`.
3. **`Cache-Control: stale-while-revalidate`** — serve the cached document instantly while regenerating in the background. Moves **TTFB** (cache hit, no render on the hot path). Cite the header value at `<response-or-config:line>`.
4. **103 Early Hints** — a HOST/CDN feature (Vercel, Cloudflare) that emits a `Link: rel=preload` / `rel=preconnect` header *before* the `200`, so the browser starts critical-resource fetches during server think-time. Moves **LCP** (resource discovery overlaps TTFB), not TTFB itself. This is DISTINCT from a framework injecting `<link rel=preload>` tags into the HTML `<head>` — 103 is a transport-level interim response from the host, not a `next.config` / framework emission. Cite the host config enabling it at `<host-config:line>`.

For streaming-boundary placement (which shell flushes first, where Suspense splits the stream), see the **streaming-ssr.md** skill.

## Edge SSR specifics

- Runs in V8 isolates (Cloudflare Workers, Vercel Edge, Deno Deploy).
- NO Node APIs — different runtime (Web Standard only).
- Cold start <5ms typically.
- DB access: edge-compatible driver (Neon Serverless, Planetscale, Turso).
- Latency: close to user (<50ms typical).

Good for: personalized SSR at global scale. Bad for: long-running computation, heavy DB queries.

## When to change strategy

- SSG → ISR — content outgrew build-time (too many pages OR content changes too fast).
- ISR → SSR — content became personalized or stale window unacceptable.
- CSR → SSR — SEO needs, or TTFB got worse as the client bundle grew.
- SSR → SSG — traffic exploded, personalization wasn't actually used.

Route-level means you can change ONE route without touching others.

## Forbidden

- Mixing strategies without a route-level declaration (ambiguity = bugs).
- CSR for SEO-critical pages. *(When a route must rank, server-render/prerender it, then run the `seo-audit` skill / `@technical-seo` agent on the head + body the crawler now receives.)*
- SSR for content that never personalizes (waste of server cost).
- ISR without a cache invalidation path (content goes stale forever).
- Client-side fetching on server-rendered pages (defeats the point).
- Hardcoded dates / random values in SSR output.
