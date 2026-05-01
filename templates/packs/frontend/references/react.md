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
