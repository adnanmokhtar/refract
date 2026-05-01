---
name: frontend-principles
kind: example
pack: frontend
---

# Frontend Principles

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

## Should

- Local state stays local (`useState` / `ref` / `signal`). Promote to a global store only when ≥ 2 unrelated components need it.
- Domain-focused stores: `useOrderStore`, `useCartStore`. Never one mega-store.
- Memoize expensive selectors (`useMemo`, `computed`, `derived`, `reselect`).
- Image optimization: framework-native (`next/image`, `nuxt/image`, `Image` from `astro:assets`) with `width`, `height`, `loading="lazy"`, `srcset`.
- Bundle audit: `vite-bundle-visualizer` / `webpack-bundle-analyzer` / `source-map-explorer` reviewed before release. Lazy-load heavy deps (charts, editors, PDF viewers).
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

## Enforcement

- ESLint with framework plugin (`eslint-plugin-react`, `eslint-plugin-vue`, `eslint-plugin-svelte`).
- `eslint-plugin-jsx-a11y` (React) / `eslint-plugin-vuejs-accessibility` / equivalents.
- TypeScript strict mode (`strict: true`) — no `any` slips silently.
- `i18next-parser` / `vue-i18n-extract` / `nuxt/i18n` checks for missing keys per locale in CI.
- `size-limit` / `bundlesize` budget gates PRs.
- Lighthouse CI on key routes; visual regression via Playwright / Chromatic.
