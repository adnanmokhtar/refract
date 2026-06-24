---
name: streaming-ssr
description: Make a chosen SSR render FAST — find routes that block TTFB on the slowest query and stream the shell first behind Suspense / await boundaries. Sibling to ssr-audit (which is correctness-only).
---

# streaming-ssr

## Premise

Slow SSR blocks TTFB on the slowest thing the page awaits. If a route `await`s a 600ms query before returning any HTML, the user stares at a white screen for 600ms even though the header, nav, and layout were ready instantly. The fix is almost never "make the query faster" first — it's **stream the shell now, stream the slow subtree later** behind a boundary, so above-the-fold paints immediately and the slow region fills in.

`ssr-audit` checks SSR *correctness* (hydration mismatches). This skill checks SSR *speed* — it turns `bundle-perf`'s open question "is hydration streaming?" into a real detector + fix. Every finding cites the blocking call at `<file:line>` + its observed/measured latency + the proposed boundary + the expected TTFB delta. A streaming recommendation without the cited blocking call is a halt.

## Scans for

### 1. Whole-page await before first byte

A page/route that awaits a slow call at the top, with nothing streamed, blocks the entire document.

```
BAD (Next App Router):
export default async function Page() {
  const reviews = await getReviews(id);   // 600ms — blocks the whole shell
  return <><Header/><Product/><Reviews data={reviews}/></>;
}

GOOD:
export default async function Page() {
  return <><Header/><Product/>
    <Suspense fallback={<ReviewsSkeleton/>}>
      <Reviews id={id} />     {/* awaits inside; streams in when ready */}
    </Suspense></>;
}
```

Grep: a top-level `await` on a `fetch(`/`db.`/known-slow call inside a `page.tsx` / `+page.server` `load` / route component, with **no** `<Suspense>` (React/Vue) / `{#await}` (Svelte) / `<Await>` (Remix/RR) wrapping the slow subtree.

### 2. Missing `loading.tsx` on a slow App-Router segment

Next App Router auto-wraps a segment in `<Suspense>` when a sibling `loading.tsx` exists — instant streamed fallback for free.

```
BAD:  app/products/page.tsx awaits a slow fetch, no app/products/loading.tsx
GOOD: app/products/loading.tsx → streamed skeleton; page streams in behind it
```

Flag route dirs with a slow server fetch and no `loading.tsx`.

### 3. Awaited-everything in SvelteKit / Nuxt loaders

```
BAD (SvelteKit load):  return { post: await getPost(), comments: await getComments() };
GOOD:                   return { post: await getPost(), comments: getComments() };  // un-awaited → streamed
                        // consume in +page.svelte: {#await data.comments}…{:then c}…{/await}
```

For Nuxt: a static-but-slow subtree that ships client JS unnecessarily → render it as a server component (`.server.vue` / `<NuxtIsland>`); non-critical data → `useLazyFetch` / `useFetch(url, { lazy: true })` so it doesn't block navigation.

### 4. Blocking `renderToString` in a custom SSR server

```
BAD:   const html = renderToString(<App/>);  res.send(html);   // buffers entire tree
GOOD (Node):  renderToPipeableStream(<App/>, { onShellReady() { res.statusCode=200; pipe(res); } });
GOOD (edge/web): renderToReadableStream(<App/>, { … });        // returns a stream
```

`renderToString` is the blocking baseline — flag it in any hand-rolled SSR entry; propose the streaming variant (`onShellReady` flushes the shell, `onAllReady` for crawlers/SSG).

### 5. Partial Prerendering candidate (Next 15)

A route marked fully dynamic (`export const dynamic = 'force-dynamic'`) that has a large static header/footer is a PPR candidate: the static shell prerenders + serves instantly, and only the dynamic holes (anything reading `cookies()` / `headers()` / `searchParams`) stream.

```
Enable: export const experimental_ppr = true;   // + experimental: { ppr: 'incremental' } in next.config
Wrap each dynamic hole in <Suspense>.
```

Flag `dynamic = 'force-dynamic'` routes with a large static region as `report-flagged` (PPR is a config + boundary decision).

## Output

```
streaming-ssr audit — <route set>

Findings: 2

1. app/products/[id]/page.tsx:6                        TTFB ~640ms
   Top-level `await getReviews(id)` blocks the shell on a 600ms query.
   Boundary: wrap <Reviews/> in <Suspense fallback={<ReviewsSkeleton/>}>;
             add app/products/[id]/loading.tsx for the segment shell.
   Expected: TTFB 640ms → ~90ms (shell), reviews stream in at ~640ms.

2. src/routes/feed/+page.server.ts:12                  TTFB ~480ms
   `comments: await getComments()` awaited alongside critical `post`.
   Boundary: return un-awaited `comments: getComments()`; consume via {#await}.
   Expected: TTFB blocked on getPost() only (~120ms); comments stream.
```

## False positives / gotchas

- **Above-the-fold critical data stays in the shell.** Streaming the hero/LCP content defers LCP — only stream below-the-fold / secondary regions.
- **Auth + redirect decisions must resolve before the shell flushes.** You cannot stream a 200 shell and then decide the user should have been redirected — resolve auth synchronously first.
- Streaming adds boundary overhead; a route whose slowest call is <100ms or whose data is all above-the-fold gains little → `dismiss`.
- A streamed boundary needs a layout-stable fallback (reserve dimensions) or you trade TTFB for CLS — coordinate with `lcp-audit` / `navigation-speed`.
- TTFB dominated by *backend endpoint latency* (the API itself is slow) is a `profile-perf` problem, not a streaming one — streaming hides server think-time of the page's own render, it doesn't speed up a slow upstream.

## When to run

- Any SSR route with TTFB > 200ms, or where one query measurably dominates the render.
- After `bundle-perf` / `web-vitals-field` attributes LCP to a high `timeToFirstByte` on an SSR route.
- When adding a slow data dependency (reviews, recommendations, related items) to an existing fast route.

## Halt conditions

- Halt on any streaming recommendation that doesn't cite the blocking call at `<file:line>` + its observed/measured latency.
- Halt if the proposed boundary would stream above-the-fold / LCP content (defers LCP) — re-scope to secondary regions.
- Halt if a redirect/auth gate sits behind the proposed streamed shell — resolve it before the flush.
- Halt if "enable PPR" is proposed without naming which subtrees become the dynamic (Suspense-wrapped) holes.
