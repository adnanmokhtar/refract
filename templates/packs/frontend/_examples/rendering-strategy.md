---
name: rendering-strategy
kind: example
pack: frontend
---

# Pattern: Rendering Strategy

Declare the rendering contract per route — which regions are static, which are dynamic, where the streaming boundary sits. An *undeclared* mix is what breaks; a declared static-shell-plus-dynamic-holes route is the shape frameworks now ship.

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
- Bundle size drives main-thread parse/exec — measure it as TBT in the lab, INP in the field (TTI was dropped from the Lighthouse 10 scored set).
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

- Mixing strategies without a route-level declaration (ambiguity = bugs) — a declared static shell + dynamic holes is not this.
- CSR for SEO-critical pages.
- SSR for content that never personalizes (waste of server cost).
- ISR without a cache invalidation path (content goes stale forever).
- Re-fetching on mount what the server already rendered (defeats the point). Revalidation on focus/interval/mutation is required, not forbidden.
- Hardcoded dates / random values in SSR output.
