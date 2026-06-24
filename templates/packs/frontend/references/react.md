# React reference (19+, function components + hooks)

> **Framework**: React 19+ • TypeScript 5+ • bundler: Vite 5+ / Next 15 / Remix 2
> **Official docs**: https://react.dev/
> **Version-specific gotchas**: React 19 introduced `use()` for promises in components, `useActionState`, `useFormStatus`, `useOptimistic`; `forwardRef` no longer needed (refs as props); document metadata + stylesheets hoisting; `<Context>` (not `<Context.Provider>`) shorthand; the `act()` API is asynchronous in tests.
> **Substitution markers**: Replace `<name>` with the project's actual feature names.

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
- See `frontend/skills/streaming-ssr.md` (streaming-boundary scanner) and `frontend/skills/navigation-speed.md` (prefetch / bfcache / View Transitions).

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
- See `performance/skills/web-vitals-field.md` (field INP/LCP/CLS attribution) and `performance/ai-patterns/inp-responsiveness.md` (INP main-thread-cost pattern).

```tsx
const [isPending, startTransition] = useTransition();
function onChange(e) {
  setQuery(e.target.value);                 // urgent
  startTransition(() => setResults(filter(e.target.value))); // deferred
}
```

## Core Web Vitals levers

- `fetchpriority="high"` on the LCP hero image (and skip lazy-loading it) — see `frontend/skills/lcp-audit.md`.
- Meta-framework field reporting: `useReportWebVitals` (Next) to ship `web-vitals` metrics (INP / LCP / CLS) to your RUM endpoint.

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
