---
name: frontend-principles
kind: example
pack: frontend
---

# Frontend Principles

Stack-agnostic. Framework specifics in `references/<framework>.md` (react, vue, nuxt, svelte, angular).

Prevents the failures that ship: untyped props, business logic in templates, fetch in components, hardcoded strings, accessibility regressions, runaway bundles.

> **Hard rule.** Components MUST have typed props + events (no `any`); data fetching MUST live in a hook / composable / service (never in a component body); every user-facing string MUST go through i18n with a key in every declared locale; semantic HTML + `<label>` + visible focus ring are mandatory. The LCP image MUST be prioritized (never `loading="lazy"`); web fonts MUST set `font-display`; public/indexable routes MUST ship unique metadata + canonical and be server-rendered, not a CSR shell. Hardcoded strings, untyped event handlers, and `fetch` / `axios` inside `.vue` / `.tsx` / `.svelte` bodies are forbidden.

## Must

- Components small and focused. The test is **more than one reason to change**; ~150 LOC is a smell threshold that says *look*, not a rule that says *split*.
- Separate the component that OWNS data from those that RENDER it — the owner holds fetch + state, the rest take props and emit events (pure, testable). Where the framework has a server/client boundary, that is the split that matters: keep the client boundary as low in the tree as possible.
- Props, emits / events, slots typed end-to-end. No `any`, no untyped event handlers.
- Data fetching lives in a service / composable / hook / store — never `fetch` / `axios` / `$fetch` called directly inside a component template or render function.
- Generated types from OpenAPI / GraphQL schema where the API exposes one (`openapi-typescript`, `graphql-codegen`, `orval`). Hand-typed DTOs drift.
- Every user-facing string has an i18n key. Every key exists in every declared locale. Cross-frontend workspaces: same concept = same key (translators write once).
- Semantic HTML first: `<button>` not `<div onclick>`. `<a>` for navigation, `<button>` for actions. `<form>` with `<label>` for inputs.
- Every input has a `<label>` (visible or `aria-label`). Icon-only buttons have `aria-label`. Focus visible (`:focus-visible` ring).
- Lazy-load routes (`React.lazy` + `Suspense`, `defineAsyncComponent`, Nuxt's automatic route splitting, SvelteKit's dynamic imports).
- Virtualize lists > 100 items (`react-window`, `vue-virtual-scroller`, `svelte-virtual-list`, `@tanstack/virtual`).
- INP (interaction responsiveness): high-frequency or expensive handlers (typing, filtering a large list, drag) keep per-interaction main-thread work bounded — break long tasks at a yield point, defer non-urgent updates through the framework's transition / deferred-value primitive. Any INP figure quoted is field-measured or reported `UNKNOWN`, never a lab proxy relabelled.
- Sensitive values — a credential, a payment instrument, a government / tax identifier, a health or biometric record, a third-party access token — are held **by reference, never by value**: captured through the provider's hosted / tokenised primitive, stored as a token, and never rendered as a table column, a filter, a fixture value, a log line, or an analytics property. An input bound to the repo's own validation schema for such a field is forbidden. See `/add-crud-page` § Data-sensitivity gate.

## Must not

- `fetch` / `axios` / `$fetch` inside `.vue` / `.tsx` / `.svelte` component bodies. Wrap in a hook / composable / service.
- Business logic in templates: `{{ items.filter(...).reduce(...) }}` is a `computed` / `useMemo` waiting to happen.
- Hardcoded user-facing strings: `<button>Save</button>` (use `t('common.save')`).
- `any` in props, state, store, or service types. `unknown` is allowed **only** at a parse boundary (`await res.json()` → schema-parse) and must be narrowed before use; an `unknown` that reaches a prop or a render is a finding. (`strict: true` types every `catch` binding as `unknown` — that is correct, not a violation.)
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
- [ ] New high-frequency / expensive handler bounds its per-interaction main-thread work.
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
