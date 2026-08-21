# React reference (19+, function components + hooks)

> **Framework**: React 19+ • TypeScript 5+ • bundler: Vite 5+ / Next 15 / Remix 2
> **Official docs**: https://react.dev/
> **Version-specific gotchas**: React 19 introduced `use()` for promises in components, `useActionState`, `useFormStatus`, `useOptimistic`; `forwardRef` no longer needed (refs as props); document metadata + stylesheets hoisting; `<Context>` (not `<Context.Provider>`) shorthand; the `act()` API is asynchronous in tests.
> **Substitution markers**: Replace `<name>` with the project's actual feature names.

## Machine-readable docs (check these before trusting this file)

React ships **no documentation inside the installed package** — verified against `react@19.2.8`, whose published
tarball carries 27 files and no docs directory. There is therefore no version-matched local copy to read, and the
hosted docs below track *latest*, not what is in your `package.json`. Reconcile the two before you trust an API.

- **Index**: `https://react.dev/llms.txt` (~14 KB) — a link list of every docs page, already pointing at the
  `.md` URLs below. This is the cheap first read.
- **Per-page Markdown**: append `.md` to a page URL (`https://react.dev/learn.md`). Caveat worth knowing before
  you parse it: the response is served as `text/plain` and the body is the raw **MDX source**, so it still
  contains authoring components such as `<Intro>` and `<Note>`. Readable, but not clean prose.
- **No `llms-full.txt`.** `https://react.dev/llms-full.txt` returns 404 — unlike Vue, Nuxt, Svelte and Angular,
  React publishes no single-file bundle. Use the index plus the pages you need.

Same rule as everywhere in this directory: hosted docs are the **API surface**, this file is the **house
opinion** (the anti-patterns list, the INP transition rule, the fetch-in-a-hook boundary). Where the two
disagree about an API, the docs win and this file is stale — say so rather than emitting the older call. Where
the network is unavailable, this file is what you have; it does not halt.

## Structure

```
src/
├── app/                      # App root, router
├── features/
│   └── <name>/
│       ├── pages/
│       ├── components/
│       ├── hooks/
│       ├── services/         # API clients (typed)
│       ├── store/            # Zustand / Redux Toolkit / Jotai
│       └── types.ts
├── shared/
│   ├── components/
│   ├── hooks/
│   └── lib/
└── index.tsx
```

## Rules

- Function components only. No class components.
- Hooks for state (`useState`, `useReducer`, `useSyncExternalStore`).
- `useMemo` / `useCallback` only when profiler shows waste — not by default.
- Effects sparingly — many use cases don't need them.
- Suspense boundaries for async UI.
- React 19: use `use()` for promises in components; form actions for mutations.

## State

- Local state: `useState` / `useReducer`.
- Cross-component / feature-wide: Zustand / Jotai / Redux Toolkit — match the repo.
- Server state: TanStack Query (React Query) / SWR.

## Data fetching

- NEVER bare `fetch` in a component. Wrap in a hook (`useUsers()`) via TanStack Query / SWR.
- Typed responses via generated OpenAPI client or hand-written service.

## Code-splitting & streaming

- Plain React (Vite/CRA) route/widget splits: `React.lazy(() => import('./Heavy'))` rendered inside a `<Suspense fallback={<Skeleton/>}>`.
- Streaming SSR: `renderToPipeableStream` (Node) / `renderToReadableStream` (web/edge) so `<Suspense>` boundaries flush progressively + selectively hydrate. `renderToString` is the blocking baseline — flag it.
- `use(promise)` reads a promise and suspends — always pair with a `<Suspense>` ancestor.
- `startTransition` / `useTransition` mark nav-triggered updates non-urgent so the shell stays interactive while the next view streams in.
- See `frontend/skills/streaming-ssr/SKILL.md` (streaming-boundary scanner) and `frontend/skills/navigation-speed/SKILL.md` (prefetch / bfcache / View Transitions).

```tsx
const Heavy = React.lazy(() => import('./Heavy'));
// route element
<Suspense fallback={<Skeleton/>}>
  <Heavy/>
</Suspense>
```

### Anti-patterns

- `React.lazy` without a `<Suspense>` fallback ancestor (throws on first render).
- Awaiting all data before render (`renderToString` + top-level await) instead of streaming `<Suspense>` boundaries.

## Interaction responsiveness (INP)

- INP good threshold = 200ms at p75; it replaced FID as a Core Web Vital in March 2024. Authoritative INP comes from the field (CrUX / RUM `web-vitals` `onINP`) — lab tools only give a synthetic proxy.
- `useTransition` / `startTransition` — keep input urgent, defer the expensive re-render.
- `useDeferredValue` — render a lagging copy of an expensive value off the urgent path.
- Rule: filtering/sorting a big list inside an `onChange` handler MUST be wrapped in a transition (or fed through `useDeferredValue`), or the keystroke blocks the main thread and tanks INP.
- See `performance/skills/web-vitals-field/SKILL.md` (field INP/LCP/CLS attribution) and `performance/ai-patterns/inp-responsiveness.md` (INP main-thread-cost pattern).

```tsx
const [isPending, startTransition] = useTransition();
function onChange(e) {
  setQuery(e.target.value);                 // urgent
  startTransition(() => setResults(filter(e.target.value))); // deferred
}
```

## Core Web Vitals levers

- `fetchpriority="high"` on the LCP hero image (and skip lazy-loading it) — see `frontend/skills/lcp-audit/SKILL.md`.
- Meta-framework field reporting: `useReportWebVitals` (Next) to ship `web-vitals` metrics (INP / LCP / CLS) to your RUM endpoint.

## SEO

- A plain Vite/CRA SPA renders an empty `<div id="root">` to crawlers — indexable content needs **SSR/SSG or a prerender step** (Next, Remix / React-Router framework mode). `react-helmet-async` tags set client-side run after JS; social/LLM scrapers won't see them.
- Manage `<head>` with **`react-helmet-async`** (`<HelmetProvider>` + `<Helmet>`) or the framework route `meta` export (Remix / React Router `MetaFunction`). Emit unique title + description, canonical, OG/Twitter, and page-appropriate JSON-LD (`<script type="application/ld+json">`). One mechanism only. See `frontend/skills/seo-audit/SKILL.md` + `@technical-seo`.

## Fonts

- No framework font primitive — self-host via **`@fontsource/*`** (or Fontaine / `unplugin-fontaine` for auto `size-adjust` fallbacks). Never a render-blocking Google Fonts `<link>`.
- `font-display: swap`; preload the one critical above-the-fold font (`<link rel="preload" as="font" crossorigin>`); size-adjusted fallback to kill swap-CLS; variable font over ≥3 weights. See `frontend/skills/font-optimization/SKILL.md`.

## Styling

- Follow the repo's system: Tailwind / CSS Modules / styled-components / Emotion. Don't mix.
- No inline `style={}` except for dynamic values.

## Forms

- React Hook Form + Zod resolver is the modern default.
- Typed form values.

## Testing

- Vitest or Jest + React Testing Library.
- Test interactions, not implementation.

## Anti-patterns

- Class components
- `useEffect` for things that can be derived synchronously
- Prop drilling past 3 levels — use context or store
- `dangerouslySetInnerHTML` with unsanitized content
- Stale closures in effects (missing deps)
