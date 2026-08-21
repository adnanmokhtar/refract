---
name: streaming-ssr
description: Make a chosen SSR render FAST — find routes that block TTFB on the slowest query and stream the shell first behind Suspense / await boundaries. Sibling to ssr-audit (which is correctness-only).
---

# streaming-ssr

## Premise

Slow SSR blocks TTFB on the slowest thing the page awaits. If a route `await`s a 600ms query before returning any HTML, the user stares at a white screen for 600ms even though the header, nav, and layout were ready instantly. The fix is almost never "make the query faster" first — it's **stream the shell now, stream the slow subtree later** behind a boundary, so above-the-fold paints immediately and the slow region fills in.

`ssr-audit` checks SSR *correctness* (hydration mismatches). This skill checks SSR *speed*: it turns the open question "is hydration streaming?" into a real detector + fix. `bundle-perf` *(performance pack, when co-installed)* is where that question is normally raised; when that pack is absent nothing else in the project asks it, which is precisely why this skill has its own TTFB trigger below rather than waiting to be handed a finding. Every finding cites the blocking call at `<file:line>` + its observed/measured latency + the proposed boundary + the expected TTFB delta. A streaming recommendation without the cited blocking call is a halt.

## Adapt to the codebase

Mirror the streaming primitive the project already has; never introduce a second one. Detect the framework + its render entry before proposing a boundary.

| Stack | Streaming boundary primitive | Segment-level shell | Un-awaited / deferred data |
|---|---|---|---|
| **Next (App Router)** | `<Suspense fallback>` around the slow subtree | `loading.tsx` beside the segment (auto-wraps in Suspense) | pass the un-awaited promise down; `use()` in the child |
| **Nuxt** | `<Suspense>` / `<NuxtIsland>` / `.server.vue` | `<NuxtLoadingIndicator>` + page-level fallback | `useLazyFetch` / `useFetch(url, { lazy: true })` |
| **SvelteKit** | `{#await}` in `+page.svelte` | `+layout.svelte` shell renders first | return an **un-awaited** promise from `load` |
| **Remix / React Router** | `<Await>` + `<Suspense>` | route-level `HydrateFallback` | un-awaited promise in the loader return |
| **Angular (SSR)** | `@defer` blocks / `@placeholder` | route-level shell component | `resource()` / deferred `HttpClient` call |
| **Astro** | `server:defer` island + slot fallback | static shell is the default | island resolves after the shell flushes |
| **Plain React SSR** | `<Suspense>` + `renderToPipeableStream` (`onShellReady`) | shell = everything outside the boundary | promise passed to a `use()` child |

If the render entry (`renderToString` vs `renderToPipeableStream` vs the framework's own server) is not extracted, halt: the fix differs per entry and a boundary added to a buffering renderer changes nothing.

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

### 5. Cache Components / partial-prerender candidate (Next 16+)

A route marked fully dynamic (`export const dynamic = 'force-dynamic'`) that has a large static header/footer is a partial-prerender candidate: the static shell prerenders + serves instantly, and only the dynamic holes (anything reading `cookies()` / `headers()` / `searchParams`) stream.

**Read the installed major before emitting anything — this skill runs against repos on both, and the enable line is not the same line:**

```
Next 16+ : cacheComponents: true in next.config.ts, then mark the cacheable shell with the
           "use cache" directive; wrap each dynamic hole in <Suspense>.
Next 15  : export const experimental_ppr = true (+ experimental: { ppr: 'incremental' }).
           BOTH were REMOVED in Next 16 — the config flag and the route-level export.
           Emitting either against a 16+ project produces a build failure, not a warning.
```

Source: the Next.js 16 release notes list `experimental.ppr` and `export const experimental_ppr` in the Removals table, replaced by the Cache Components model (nextjs.org/blog/next-16, published 2025-10-21).

Flag `dynamic = 'force-dynamic'` routes with a large static region as `report-flagged` — the enable is a config + boundary decision, not a mechanical edit.

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
- TTFB dominated by *backend endpoint latency* (the API itself is slow) is not a streaming problem — streaming hides server think-time of the page's own render, it doesn't speed up a slow upstream. Route it to `profile-perf` *(performance pack, when co-installed)*; absent that pack, hand the endpoint to the backend owner with the measured latency attached and record `upstream latency: routed out of scope` — do not propose a boundary that cannot help.

## When to run

- Any SSR route with TTFB > 200ms, or where one query measurably dominates the render.
- After `bundle-perf` / `web-vitals-field` *(performance pack, when co-installed)* attributes LCP to a high `timeToFirstByte` on an SSR route. Absent that pack, the trigger is the route's own measured TTFB above.
- When adding a slow data dependency (reviews, recommendations, related items) to an existing fast route.

## Halt conditions

- Halt on any streaming recommendation that doesn't cite the blocking call at `<file:line>` + its observed/measured latency.
- Halt if the proposed boundary would stream above-the-fold / LCP content (defers LCP) — re-scope to secondary regions.
- Halt if a redirect/auth gate sits behind the proposed streamed shell — resolve it before the flush.
- Halt if "enable partial prerendering / Cache Components" is proposed without naming which subtrees become the dynamic (Suspense-wrapped) holes.
- Halt if the enable line is emitted without reading the framework major from `package.json` — `experimental_ppr` against Next 16+ is a removed API, and a reference that emits a deleted API is worse than no reference.

## Related

- `ssr-audit` — the correctness sibling: it owns hydration mismatches, this skill owns TTFB. A route that streams a mismatched shell is that skill's finding, not this one's.
- `lcp-audit` — a streamed boundary must never contain the LCP element, and its fallback must reserve the box; hand LCP-priority findings there.
- `navigation-speed` — owns prefetch / bfcache / instant-loading on the *client* navigation path; this skill owns the server's first byte.
- `rendering-strategy.md` (ai-pattern) — decides whether the route is server-rendered at all; this skill only places the boundary inside a route that already is.
- `code-splitting.md` (ai-pattern) — the JS axis of the same page; a streamed region whose chunk is eagerly bundled still blocks the main thread.
- `.claude/rules/frontend-principles.md` — the "server-rendered routes MUST stream the shell" MUST this skill enforces.
- Cross-pack (`performance`, when co-installed): `web-vitals-field` measures whether the TTFB win actually reached users. Absent that pack, report the before/after server TTFB only and label it `lab only — field impact unmeasured`; never claim a user-visible win this skill could not observe.
