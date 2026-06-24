---
name: frontend-principles
description: Frontend Principles
kind: rule
pack: frontend
severity: must
applies-to: frontend-track, every-code-writing-task-in-frontend
---

# Frontend Principles

> **Hard rule.** Components MUST have typed props + events (no `any`); data fetching MUST live in a hook / composable / service (never in a component body); every user-facing string MUST go through i18n with a key in every declared locale; semantic HTML + `<label>` + visible focus ring are mandatory. Hardcoded strings, untyped event handlers, and `fetch` / `axios` inside `.vue` / `.tsx` / `.svelte` bodies are forbidden.

Stack-agnostic. Framework specifics in `references/<framework>.md` (react, vue, nuxt, svelte, angular).

Prevents the failures that ship: untyped props, business logic in templates, fetch in components, hardcoded strings, accessibility regressions, runaway bundles.

## Must

- Components small and focused. Split when a component file passes ~150 LOC or has more than one reason to change.
- Container vs presentational split: containers own data fetching + state; presentational receive props + emit events. Presentational components are pure and easy to test.
- Props, emits / events, slots typed end-to-end. No `any`, no untyped event handlers.
- Data fetching lives in a service / composable / hook / store — never `fetch` / `axios` / `$fetch` called directly inside a component template or render function.
- Generated types from OpenAPI / GraphQL schema where the API exposes one (`openapi-typescript`, `graphql-codegen`, `orval`). Hand-typed DTOs drift.
- Every user-facing string has an i18n key. Every key exists in every declared locale. Cross-frontend workspaces: same concept = same key (translators write once).
- Semantic HTML first: `<button>` not `<div onclick>`. `<a>` for navigation, `<button>` for actions. `<form>` with `<label>` for inputs.
- Every input has a `<label>` (visible or `aria-label`). Icon-only buttons have `aria-label`. Focus visible (`:focus-visible` ring).
- Lazy-load routes (`React.lazy` + `Suspense`, `defineAsyncComponent`, Nuxt's automatic route splitting, SvelteKit's dynamic imports).
- Virtualize lists > 100 items (`react-window`, `vue-virtual-scroller`, `svelte-virtual-list`, `@tanstack/virtual`).
- Navigation speed: primary in-viewport navigation links MUST be prefetched via the framework primitive (Next `<Link>` default-on; Nuxt `<NuxtLink>` / `prefetchOn`; SvelteKit `data-sveltekit-preload-data="hover"` — accepts `hover` / `tap` / `off`, do not flag an intentional `=off`; React Router `<Link prefetch="intent">`). Raw-HTML / MPA surfaces ship a `<script type="speculationrules">` document rule with `eagerness:"moderate"`. Disabling a default prefetch requires a documented reason. See `navigation-speed.md`.
- Streaming: a server-rendered route whose above-the-fold content does NOT depend on a slow query MUST stream — render the shell immediately and stream slow regions behind a Suspense / await boundary (Next `loading.tsx` + `<Suspense>` + `use()`; Nuxt lazy components; SvelteKit streamed promises; Remix / RR `defer` + `<Await>`). Blocking TTFB on a below-the-fold query is forbidden when the shell could paint first. See `references/rendering-strategy.md` and `streaming-ssr.md`.
- Instant loading state: every data-dependent route MUST paint an instant layout-stable skeleton (matching final dimensions, no CLS) on navigation — not a spinner, not a blank screen. Use the framework route-level loading convention (Next `loading.tsx`; SvelteKit `navigating` store; React Router `useNavigation().state`; Vue Router `<router-view>` + `Suspense` fallback). For plain React-Router / Vue-Router routes with no route-level convention, the detector looks for an in-component `Suspense` fallback / router pending UI. See `navigation-speed.md`.

## Must not

- `fetch` / `axios` / `$fetch` inside `.vue` / `.tsx` / `.svelte` component bodies. Wrap in a hook / composable / service.
- Business logic in templates: `{{ items.filter(...).reduce(...) }}` is a `computed` / `useMemo` waiting to happen.
- Hardcoded user-facing strings: `<button>Save</button>` (use `t('common.save')`).
- `any` / `unknown` in props, state, store, or service return types. Type or stop.
- Mutating store state from outside an action / mutation / setter. Stores are encapsulated.
- Mixing styling systems (Tailwind + CSS Modules + scoped SCSS) without a documented reason. Pick one per repo.
- Magic spacing/colors (`margin: 13px`, `color: #abcdef`). Use design tokens from a declared source (Tailwind config, design system tokens, CSS custom properties).
- Side-effects in render / template / setup top-level: `localStorage.setItem` during render. Move to lifecycle / event handler.
- `console.log` / `console.debug` left in committed code.
- Dangerously inserting HTML (`v-html`, `dangerouslySetInnerHTML`) without sanitization (`DOMPurify`) — XSS vector.
- bfcache safety: no unconditional `unload` / `beforeunload` listener (evicts from bfcache — use `pagehide` / `visibilitychange`). Close IndexedDB / BroadcastChannel / WebSocket on `pagehide`. (`Cache-Control: no-store` on documents is a warn / review, not a hard disqualifier.)

## Should

- Keep local state local (`useState` / `ref` / `signal`). Promote to a global store only when ≥ 2 unrelated components need it.
- Use domain-focused stores: `useOrderStore`, `useCartStore`. One mega-store is forbidden.
- Memoize expensive selectors (`useMemo`, `computed`, `derived`, `reselect`).
- Optimize images via the framework-native helper (`next/image`, `nuxt/image`, `Image` from `astro:assets`) with `width`, `height`, `loading="lazy"`, `srcset`.
- Audit the bundle (`vite-bundle-visualizer` / `webpack-bundle-analyzer` / `source-map-explorer`) before every release. Lazy-load heavy deps (charts, editors, PDF viewers).
- Route-level code splitting plus chunk-level splitting for heavy modal flows.

## Review checklist

- [ ] Props + events typed; no `any`.
- [ ] No `fetch` / `axios` in component body.
- [ ] No hardcoded strings; new keys added to all locales.
- [ ] No `console.log` left in.
- [ ] New images use the framework's image component.
- [ ] New large list uses virtualization.
- [ ] Keyboard tab order verified on the new screen.
- [ ] Lighthouse / axe-core: no new a11y regressions.
- [ ] Bundle size delta acceptable (size-limit / bundlesize).
- [ ] In-viewport nav links prefetch via the framework primitive (or a documented `=off`); MPA surfaces ship a `speculationrules` document rule.
- [ ] Server route with a fast shell streams slow regions behind a Suspense / await boundary (no TTFB blocked on a below-the-fold query).
- [ ] Data-dependent route paints a layout-stable skeleton on navigation (no spinner / blank, no CLS).
- [ ] No `unload` / `beforeunload` listener; IndexedDB / BroadcastChannel / WebSocket closed on `pagehide`.

## Enforcement

- ESLint with framework plugin (`eslint-plugin-react`, `eslint-plugin-vue`, `eslint-plugin-svelte`).
- `eslint-plugin-jsx-a11y` (React) / `eslint-plugin-vuejs-accessibility` / equivalents.
- TypeScript strict mode (`strict: true`) — no `any` slips silently.
- `i18next-parser` / `vue-i18n-extract` / `nuxt/i18n` checks for missing keys per locale in CI.
- `size-limit` / `bundlesize` budget gates PRs.
- Lighthouse CI on key routes; visual regression via Playwright / Chromatic.
- Navigation / streaming / instant-loading / bfcache checks via `navigation-speed.md` + `streaming-ssr.md`; bfcache verified in DevTools Application → Back/forward cache (no `unload` / `beforeunload` evictors).
