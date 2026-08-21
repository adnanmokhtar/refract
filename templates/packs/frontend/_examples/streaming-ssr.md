---
name: streaming-ssr
description: Make a chosen SSR render FAST — find routes that block TTFB on the slowest query and stream the shell first behind Suspense / await boundaries. Sibling to ssr-audit (which is correctness-only).
---

# streaming-ssr

Slow SSR blocks TTFB on the slowest thing the page awaits. Stream the shell now, stream the slow subtree later. Every finding cites the blocking call at `<file:line>` + its latency + the proposed boundary + the expected TTFB delta.

## Premise

Slow SSR blocks TTFB on the slowest thing the page awaits. If a route `await`s a 600ms query before returning any HTML, the user stares at a white screen for 600ms even though the header, nav, and layout were ready instantly. The fix is almost never "make the query faster" first — it's **stream the shell now, stream the slow subtree later** behind a boundary, so above-the-fold paints immediately and the slow region fills in.

`ssr-audit` checks SSR *correctness* (hydration mismatches). This skill checks SSR *speed*: it turns the open question "is hydration streaming?" into a real detector + fix. `bundle-perf` *(performance pack, when co-installed)* is where that question is normally raised; when that pack is absent nothing else in the project asks it, which is precisely why this skill has its own TTFB trigger below rather than waiting to be handed a finding. Every finding cites the blocking call at `<file:line>` + its observed/measured latency + the proposed boundary + the expected TTFB delta. A streaming recommendation without the cited blocking call is a halt.

## Scans for

### 1. Whole-page await before first byte

```
BAD:  const reviews = await getReviews(id);          // 600ms blocks the shell
      return <><Header/><Product/><Reviews data={reviews}/></>;
GOOD: return <><Header/><Product/>
        <Suspense fallback={<ReviewsSkeleton/>}><Reviews id={id}/></Suspense></>;
```

Grep a top-level `await` on a slow `fetch(`/`db.` call with no `<Suspense>` / `{#await}` / `<Await>` wrapping the slow subtree.

### 2. Missing `loading.tsx` on a slow App-Router segment

Next auto-wraps a segment in `<Suspense>` when a sibling `loading.tsx` exists. Flag route dirs with a slow server fetch and none.

### 3. Awaited-everything in SvelteKit / Nuxt loaders

```
BAD:  return { post: await getPost(), comments: await getComments() };
GOOD: return { post: await getPost(), comments: getComments() };  // un-awaited → streamed; consume via {#await}
```

Nuxt: static-but-slow subtree → `.server.vue` / `<NuxtIsland>`; non-critical data → `useLazyFetch`.

### 4. Blocking `renderToString` in a custom SSR server

`renderToString` buffers the whole tree → switch to `renderToPipeableStream` (Node, `onShellReady`) / `renderToReadableStream` (edge/web).

### 5. Cache Components / partial-prerender candidate (version-gated)

`export const dynamic = 'force-dynamic'` route with a large static header/footer → partial prerender; wrap dynamic holes (`cookies()`/`headers()`/`searchParams`) in `<Suspense>`. `report-flagged`.

Read the installed major first: **Next 16+** → `cacheComponents: true` + the `"use cache"` directive. **Next 15** → `export const experimental_ppr = true` (+ `experimental: { ppr: 'incremental' }`) — both REMOVED in 16, emitting them against a 16+ project fails the build (nextjs.org/blog/next-16 removals table).

## Output

```
streaming-ssr audit — <route set>

1. app/products/[id]/page.tsx:6                 TTFB ~640ms
   Top-level `await getReviews(id)` blocks the shell on a 600ms query.
   Boundary: wrap <Reviews/> in <Suspense>; add loading.tsx.  Expected: TTFB 640ms → ~90ms.
2. src/routes/feed/+page.server.ts:12           TTFB ~480ms
   `comments: await getComments()` awaited with critical `post`.
   Boundary: return un-awaited `comments`; consume via {#await}.  Expected: blocked on getPost() only.
```

## False positives / gotchas

- Above-the-fold critical / LCP data stays in the shell — don't stream it (defers LCP).
- Auth + redirect decisions must resolve before the shell flushes.
- TTFB dominated by *backend endpoint latency* is not a streaming problem. Route it to `profile-perf` *(performance pack, when co-installed)*; absent that pack, hand the endpoint to the backend owner with the measured latency and record `upstream latency: routed out of scope`.

## Halt conditions

- No streaming recommendation without the blocking call at `<file:line>` + its latency.
- Don't stream above-the-fold / LCP content.
- Resolve auth/redirect before the proposed shell flush.
- "Enable PPR" must name which subtrees become the Suspense-wrapped dynamic holes.
