---
name: code-splitting
description: Pattern — route- and component-level JS chunk splitting so the initial bundle ships only what first paint needs. Decides WHAT to split (routes, modals, below-fold, heavy deps) and HOW (dynamic import + Suspense/fallback + error boundary, manualChunks, deep imports, modulepreload). Framework-agnostic.
kind: ai-pattern
pack: frontend
---

# Pattern: Code Splitting

> **Hard rule:** The initial bundle ships ONLY what first paint needs. Every route is a split point, and any heavy dependency not needed above the fold (rich-text editor, chart/viz lib, map SDK, PDF/video player, date-picker with locale data) is lazy-loaded behind a dynamic import with a Suspense/fallback boundary. A single monolithic bundle, or an eager top-level import of a heavy below-the-fold dependency, is forbidden. Every claim cites `<file:line>` + the import + the fix — a split proposed without the cited eager import is a vibe, not a finding.

**Ownership boundary.** This pattern decides **WHAT** JS to split and **HOW** the chunk boundary is drawn. The `bundle-analyze` skill **MEASURES** chunk names + gzipped sizes and points at the import that anchors a heavy dep — it tells you *which* dep is heavy; this pattern tells you *where to cut it*. The cross-pack `lazy-loading` pattern (performance) owns the broader deferral of *non-JS* tiers (images, videos, third-party scripts, data, hydration scheduling); this pattern is the JS-code-splitting elaboration of the `frontend-principles` MUST "lazy-load routes + heavy deps." Do not re-derive image/script deferral here — hand off to those siblings.

**When to apply**
- A new route is added — it is a split point by default (meta-frameworks do this automatically; SPAs must do it explicitly).
- A heavy dependency is introduced that only some routes / interactions use (editor, chart, map, PDF, video, locale-heavy date-picker).
- A component is only reachable below the fold, inside a modal/drawer, an inactive tab, or an admin-only path.
- `bundle-analyze` / `lighthouse-ci` flags the entry chunk over its initial-JS budget with a named cause.

**When NOT to apply**
- Tiny deps where a chunk's request + HTTP overhead exceeds its weight (< ~5 KB gzipped) — over-splitting is its own anti-pattern; keep it in the shared chunk.
- The LCP-critical path itself — the above-the-fold hero / primary content component must NOT be lazy; a lazy chunk adds a network round-trip before it can paint. Cross-ref `lcp-audit`.
- Modules that load on every route anyway (shared shell, router, design-system core) — "splitting" them just multiplies requests.

**Halt conditions / mandatory cites**
- Any "lazy this" proposal MUST cite the eager import site at `<file:line>` AND name the chunk it moves out of the entry.
- Any split of a heavy dep MUST cite the measured gzipped size (from `bundle-analyze`) — lazy without measurement is a halt (mirror the `lazy-loading` measure-first rule).
- Every dynamic import MUST cite its Suspense/fallback boundary at `<file:line>` and its error boundary for chunk-load failure — a naked `lazy()`/`import()` with no fallback and no failure path is a bug, reject it.
- Any proposal to lazy a component in the LCP element's subtree is an anti-pattern — reject and hand off to `lcp-audit`.
- If the project's router + bundler (Vite/Rollup/webpack) aren't extracted, halt: mirror the existing route-split and `manualChunks`/`splitChunks` config, never impose a second mechanism.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when classifying a chunk boundary.

## Route-based splitting (the default win)

One split per route is the highest-leverage cut: a visitor on `/` never downloads the JS for `/settings`. Meta-frameworks (Next, Nuxt, SvelteKit, Remix, Angular route lazy) do this automatically from the file-system / route table — verify it's actually happening, don't re-implement it. A client-only SPA (React Router, Vue Router) must do it explicitly: the route's component is a dynamic import, not a static one.

## Component-based splitting

Below the route granularity, split components the user doesn't see at first paint: modal/drawer bodies, inactive tab panels, below-the-fold sections, and admin-only widgets. Each is a dynamic import triggered on the event that reveals it (open, tab-activate, in-view). The heavy dep travels *with* the component's chunk, so deferring the component defers the dep.

## The eager-vs-lazy tradeoff

A lazy chunk is a network round-trip deferred to the moment of need — good when "need" is later, bad when "need" is now. Never lazy the thing the user sees immediately (LCP subtree, first-tab content): the round-trip delays paint. Conversely, for a route the user is *likely* to visit next, prefetch its chunk on link-hover or during idle so the eventual click resolves from cache and feels instant — the prefetch is owned by `navigation-speed`; this pattern just marks which chunk is prefetch-worthy.

## Over-splitting is its own anti-pattern

Too many tiny chunks turn into a request waterfall: each `import()` is a round-trip, and HTTP overhead per request swamps a 3 KB payload. Group vendor code and co-used modules into deliberate chunks via the bundler's knob — Rollup/Vite `manualChunks` (function or object form), webpack `optimizationSplitChunks`. A common baseline: one `vendor` chunk for stable third-party code (long-cache), plus per-route chunks. Cite the measured chunk count + sizes before merging or splitting further.

```js
// vite.config -> build.rollupOptions.output
manualChunks(id) {
  if (id.includes('node_modules')) return 'vendor';  // one long-cache vendor chunk
  // per-route/component chunks stay automatic from their import() calls
}
```

## The barrel-file trap

`import { thing } from 'huge-lib'` against a barrel `index` re-export often pulls the *whole* library into the chunk because the barrel isn't tree-shakeable. Prefer deep/subpath imports (`import thing from 'huge-lib/thing'`, `lodash-es/get`) or the framework's package-import optimizer (Next `experimental.optimizePackageImports`) that rewrites barrel imports to deep ones at build time.

## Fallback + failure are mandatory

A dynamic import can fail (offline, a redeployed hashed chunk 404s). Every lazy boundary MUST pair with (1) a Suspense/fallback that preserves layout while the chunk loads, and (2) an **error boundary** that catches the chunk-load rejection and offers retry/reload — a rejected `import()` with no catch leaves the UI stuck. Use the framework's error-boundary primitive (React Error Boundary, Vue `errorCaptured`, SvelteKit `+error`, Angular `ErrorHandler`). The complete boundary — layout-stable fallback outside, error boundary outside that:

```tsx
const Editor = lazy(() => import('./Editor'));      // heavy dep travels in this chunk

<ChunkErrorBoundary onRetry={reloadChunk}>          // catches the import() rejection
  <Suspense fallback={<EditorSkeleton />}>          // reserves the same box -> no CLS
    <Editor />
  </Suspense>
</ChunkErrorBoundary>
```

## Cacheability + preloading

Prefer **named** chunks (stable, content-hashed filenames via the bundler's `chunkFileNames` / magic-comment names) over anonymous ones so a chunk that didn't change keeps its cache entry across deploys. For the ONE critical async chunk the first interaction needs, emit `<link rel="modulepreload">` so its fetch overlaps parse of the entry — distinct from over-eager prefetching of everything.

## Adapt to the codebase

Mirror the router + bundler already in the repo; never introduce a second splitting mechanism.

| Stack | Lazy primitive | Route auto-split? | Manual chunking knob |
|---|---|---|---|
| **React (SPA)** | `lazy(() => import('./X'))` + `<Suspense fallback>` | No — split routes explicitly | via bundler (Vite/webpack) |
| **Next.js** | `next/dynamic` (opt `loading`; `ssr:false` **only inside a Client Component** — it is not allowed in a Server Component and errors the build) | Yes — per-page/segment automatic | `experimental.optimizePackageImports`; webpack `splitChunks` |
| **Vue (SPA)** | `defineAsyncComponent(() => import('./X'))` | No — async route components in the router | via Vite/Rollup |
| **Nuxt** | auto async components; `defineAsyncComponent` | Yes — automatic per-page | `nitro`/Vite `build.rollupOptions.output.manualChunks` |
| **SvelteKit** | route auto-split + `import()` for components | Yes — automatic per route | Vite `manualChunks` |
| **Angular** | `loadComponent` / `loadChildren` on routes | Yes — via lazy route config | webpack/esbuild builder budgets + `namedChunks` |
| **Bundler (Vite/Rollup)** | native `import()` code-split | — | `build.rollupOptions.output.manualChunks` |
| **Bundler (webpack)** | `import(/* webpackChunkName */)` | — | `optimization.splitChunks` |

## Detectors (cite-or-halt)

1. **Heavy dep imported eagerly at module top, used only below fold / in a modal.** BAD: `import Editor from 'quill'` at the top of a component whose editor only shows on click. GOOD: `const Editor = lazy(() => import('quill-wrapper'))` behind the open handler. Grep: `rg -n "^import .* from ['\"](chart\.js|echarts|monaco-editor|codemirror|quill|tinymce|mapbox-gl|leaflet|pdfjs-dist|three|moment)" src` then confirm the usage site is below the fold.
2. **Routes not split — every page in the entry chunk.** BAD: `import Settings from './Settings'` in the route table. GOOD: `{ path: '/settings', component: () => import('./Settings') }`. Grep the router file for static component imports; in a meta-framework, confirm `bundle-analyze` shows per-route chunks, not one giant entry.
3. **`lazy`/`dynamic` with no Suspense/fallback.** BAD: `lazy(() => import('./X'))` rendered with no `<Suspense>` ancestor. GOOD: wrapped in `<Suspense fallback={<Skeleton/>}>`. Grep: `rg -n "lazy\(|defineAsyncComponent\(|next/dynamic"` and check each has a fallback/loading boundary.
4. **Lazy import with no error boundary for chunk-load failure.** BAD: dynamic import whose rejection is uncaught → UI stuck on a stale skeleton. GOOD: an error boundary around the lazy subtree offering retry/reload. Grep: for each `import(` split point, confirm an enclosing error-boundary primitive exists.
5. **Barrel import pulling a whole lib.** BAD: `import { debounce } from 'lodash'`. GOOD: `import debounce from 'lodash-es/debounce'` (or `optimizePackageImports`). Grep: `rg -n "from ['\"](lodash|@mui/material|@mui/icons-material|date-fns|rxjs)['\"]"` (barrel root, no subpath).
6. **Over-splitting — dozens of tiny chunks.** BAD: `bundle-analyze` shows 40+ chunks under 5 KB gzipped → request waterfall. GOOD: co-used + vendor code grouped via `manualChunks`. Cite the chunk count + sizes from the analyzer run; propose the `manualChunks`/`splitChunks` grouping.
7. **LCP-critical component lazy-loaded (anti-pattern).** BAD: the above-the-fold hero/primary component behind `lazy()` → extra round-trip before paint. GOOD: eager import; lazy only its below-fold neighbours. Do not fix here — hand off to `lcp-audit` (LCP element must never be lazy).

## Closure verbs

- `split-route` — convert a statically-imported route to a dynamic import (or verify the meta-framework already does).
- `defer-dep` — move a heavy below-fold dependency behind a component-level dynamic import.
- `merge-chunks` — collapse over-split tiny chunks via `manualChunks`/`splitChunks` and cite the new count.
- `deep-import` — rewrite a barrel import to a subpath / enable the package-import optimizer.
- `guard-lazy` — add the missing Suspense/fallback + error boundary to a naked dynamic import.
- `halt-handoff` — LCP-subtree or non-JS-tier finding handed to `lcp-audit` / `lazy-loading` by name.

## Related

- `bundle-analyze.md` — the measurement sibling (skill): it names the heavy chunk + gzipped size; this pattern decides where to cut it. Split proposals cite its output.
- `lcp-audit.md` — the LCP-critical path must never be lazy; hand off detector 7 here.
- `navigation-speed.md` — owns prefetching the likely-next route's chunk on hover/idle so the split click feels instant.
- `rendering-strategy.md` — the initial-render axis; a route's rendering strategy and its code-split boundaries must stay consistent.
- `error-boundaries.md` — the boundary that catches a lazy chunk-load failure (detector 4's mandatory failure path); mirror the project's boundary primitive.
- Chunk-load failure is caught by the framework's error-boundary primitive (React Error Boundary / Vue `errorCaptured` / SvelteKit `+error`) — see detector 4.
- Cross-pack (`performance`, when co-installed): `lazy-loading` (broad non-JS deferral tiers), `inp-responsiveness` (splitting reduces main-thread parse/exec), `web-vitals-field` (measures the initial-JS impact in the field).
