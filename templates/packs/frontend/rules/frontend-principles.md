---
name: frontend-principles
description: Frontend Principles
kind: rule
pack: frontend
severity: must
applies-to: frontend-track, every-code-writing-task-in-frontend
---

# Frontend Principles

> **Hard rule.** Components MUST have typed props + events (no `any`); data fetching MUST live in a hook / composable / service (never in a component body); every user-facing string MUST go through i18n with a key in every declared locale; semantic HTML + `<label>` + visible focus ring are mandatory. The LCP image MUST be prioritized (never `loading="lazy"`); web fonts MUST set `font-display`; public/indexable routes MUST ship unique metadata + canonical and be server-rendered, not a CSR shell. Hardcoded strings, untyped event handlers, and `fetch` / `axios` inside `.vue` / `.tsx` / `.svelte` bodies are forbidden.

Stack-agnostic. Framework specifics in `references/<framework>.md` (react, vue, nuxt, svelte, angular).

Prevents the failures that ship: untyped props, business logic in templates, fetch in components, hardcoded strings, accessibility regressions, runaway bundles.

## Must

- Components small and focused. The test is **more than one reason to change**; ~150 LOC is a smell threshold that says *look*, not a rule that says *split*.
- Separate the component that OWNS data from those that RENDER it — the owner holds fetch + state, the rest take props and emit events (pure, testable). Where the framework has a server/client boundary, that is the split that matters: keep the client boundary as low in the tree as possible.
- Props, emits / events, slots typed end-to-end. No `any`, no untyped event handlers.
- Data fetching lives in a service / composable / hook / store — never `fetch` / `axios` / `$fetch` called directly inside a component template or render function.
- Server state (remote data) goes through a caching layer with declared staleness, in-flight de-duplication, and invalidation-on-mutation — the project's query lib (TanStack Query / SWR / RTK Query / Apollo / urql) or an equivalent. A component that fetches with no cache/dedup, and a mutation that does not invalidate the affected cache keys, are forbidden. Cancel in-flight requests on unmount / param change. See `data-fetching.md` (ai-pattern).
- Generated types from OpenAPI / GraphQL schema where the API exposes one (`openapi-typescript`, `graphql-codegen`, `orval`). Hand-typed DTOs drift.
- Every user-facing string has an i18n key. Every key exists in every declared locale. Cross-frontend workspaces: same concept = same key (translators write once).
- Semantic HTML first: `<button>` not `<div onclick>`. `<a>` for navigation, `<button>` for actions. `<form>` with `<label>` for inputs.
- Every input has a `<label>` (visible or `aria-label`). Icon-only buttons have `aria-label`. Focus visible (`:focus-visible` ring).
- Lazy-load routes (`React.lazy` + `Suspense`, `defineAsyncComponent`, Nuxt's automatic route splitting, SvelteKit's dynamic imports).
- Virtualize lists > 100 items (`react-window`, `vue-virtual-scroller`, `svelte-virtual-list`, `@tanstack/virtual`). See `list-virtualization.md` (ai-pattern).
- Resilience: every route root and independently-failing feature subtree (a lazy island, a third-party embed, a heavy widget) is wrapped by an error boundary with a real fallback UI + a retry/reset that re-mounts and refetches, and reports to the project's error sink. A subtree whose throw white-screens the whole app is forbidden. Render boundaries do NOT catch async errors (promise rejections, event handlers) — a global `onunhandledrejection` / `window.onerror` net is required alongside them. See `error-boundaries.md` (ai-pattern).
- Navigation speed: primary in-viewport navigation links MUST be prefetched via the framework primitive (Next `<Link>` default-on; Nuxt `<NuxtLink>` / `prefetchOn`; SvelteKit `data-sveltekit-preload-data="hover"` — accepts `hover` / `tap` / `off`, do not flag an intentional `=off`; React Router `<Link prefetch="intent">`). Raw-HTML / MPA surfaces ship a `<script type="speculationrules">` document rule with `eagerness:"moderate"`. Disabling a default prefetch requires a documented reason. See the `navigation-speed` skill.
- Streaming: a server-rendered route whose above-the-fold content does NOT depend on a slow query MUST stream — render the shell immediately and stream slow regions behind a Suspense / await boundary (Next `loading.tsx` + `<Suspense>` + `use()`; Nuxt lazy components; SvelteKit streamed promises; Remix / RR `defer` + `<Await>`). Blocking TTFB on a below-the-fold query is forbidden when the shell could paint first. See `rendering-strategy.md` (ai-pattern) + the `streaming-ssr` skill.
- Instant loading state: every data-dependent route MUST paint an instant layout-stable skeleton (matching final dimensions, no CLS) on navigation — not a spinner, not a blank screen. Use the framework route-level loading convention (Next `loading.tsx`; SvelteKit `navigating` store; React Router `useNavigation().state`; Vue Router `<router-view>` + `Suspense` fallback). For plain React-Router / Vue-Router routes with no route-level convention, the detector looks for an in-component `Suspense` fallback / router pending UI. See the `navigation-speed` skill.
- INP (interaction responsiveness): high-frequency or expensive handlers — typing, filtering a large list, drag — MUST keep per-interaction main-thread work bounded: break a long task at a yield point, and defer non-urgent updates through the framework's transition / deferred-value primitive instead of blocking the interaction. Authoritative INP is **field**-measured; a lab figure reported as a field number is forbidden — say `UNKNOWN` instead. Deep measurement is the `web-vitals-field` skill *(performance pack, when co-installed)*; absent → the levers in this bullet are the whole floor and the number stays `UNKNOWN`, never a lab proxy relabelled.
- LCP & images: the Largest Contentful Paint image MUST be eager + prioritized (`fetchpriority="high"` / `<Image priority>` / `NgOptimizedImage priority`) and MUST NOT carry `loading="lazy"` — exactly one high-priority element per view. Every other content image: modern format (AVIF/WebP, or a CDN `format=auto`), responsive `srcset`/`sizes`, explicit `width`/`height` (or CSS `aspect-ratio`) to prevent CLS, and `loading="lazy"` **below the fold only**, via the framework image component where one exists. See the `lcp-audit` skill (priority) + the `image-optimization` skill (format / dimensions / loading).
- Fonts: web fonts MUST set `font-display` (`swap`, or a deliberate `optional`); self-host via the framework primitive (`next/font`, `@nuxt/fonts`, Fontsource) — no render-blocking remote Google Fonts `<link>`; preload the one critical above-the-fold font with `crossorigin`; provide a size-adjusted fallback face (`size-adjust` / `ascent-override`) to kill swap-CLS; woff2-first; prefer a variable font over ≥3 static weights. See the `font-optimization` skill.
- SEO (public / indexable routes): each MUST declare a unique `<title>` + meta description, a self-referencing canonical, Open Graph + Twitter tags, and page-appropriate JSON-LD describing **only visible content**; localized routes carry reciprocal `hreflang` + `x-default`; SEO-critical routes are SSR / SSG / prerendered, never CSR-only (a CSR shell is empty to crawlers). Non-public routes get `noindex`; the site ships `sitemap.xml` + `robots.txt`. All via the project's own metadata primitive (`generateMetadata` / `useSeoMeta` / `<svelte:head>` / `Title`+`Meta` / `react-helmet`) — never a second mechanism. See the `seo-audit` skill + `@technical-seo`.

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
- bfcache safety: no unconditional `unload` / `beforeunload` listener (evicts from bfcache — use `pagehide` / `visibilitychange`). Close IndexedDB / BroadcastChannel / WebSocket on `pagehide`. (`Cache-Control: no-store` on documents is a warn / review, not a hard disqualifier.)

## Should

- Keep local state local (`useState` / `ref` / `signal`). Promote to a global store only when ≥ 2 unrelated components need it.
- Use domain-focused stores: `useOrderStore`, `useCartStore`. One mega-store is forbidden.
- Memoize expensive selectors (`useMemo`, `computed`, `derived`, `reselect`).
- Large hero / card images use an LQIP / blur / dominant-color placeholder where the framework offers one (`next/image placeholder="blur"`, `<NuxtImg placeholder>`). (Core image discipline — format / dimensions / lazy-below-fold / LCP-priority — is a Must above, see the `image-optimization` skill.)
- Audit the bundle (`vite-bundle-visualizer` / `webpack-bundle-analyzer` / `source-map-explorer`) before every release. Lazy-load heavy deps (charts, editors, PDF viewers).
- Route-level code splitting plus chunk-level splitting for heavy modal flows. Lazy MUST pair with a Suspense/fallback + an error boundary for chunk-load failure; never lazy the LCP-critical path. See `code-splitting.md` (ai-pattern).
- Realtime connections (WebSocket / SSE) have an explicit lifecycle — reconnect with exponential backoff + jitter, heartbeat to detect a half-open socket, re-auth on reconnect, and teardown on unmount — and dedup inbound messages by id/sequence, reconciling them into the query cache rather than a parallel local copy. A bare `new WebSocket(url)` with no reconnection or cleanup is forbidden. See `realtime-client.md` (ai-pattern).

## Review checklist

- [ ] Props + events typed; no `any`.
- [ ] No `fetch` / `axios` in component body.
- [ ] No hardcoded strings; new keys added to all locales.
- [ ] No `console.log` left in.
- [ ] New images: framework image component, modern format, explicit `width`/`height` (no CLS); the LCP/hero image is prioritized and NOT `loading="lazy"`.
- [ ] New / changed web font sets `font-display`, is self-hosted, and has a size-adjusted fallback (no swap-CLS).
- [ ] Public / indexable route ships unique title + description, canonical, OG/Twitter, page-appropriate JSON-LD; localized routes carry hreflang; SEO route is SSR/SSG/prerendered (not CSR-only).
- [ ] New high-frequency / expensive handler bounds its per-interaction main-thread work; any INP figure quoted is field-measured or reported `UNKNOWN`.
- [ ] New large list uses virtualization.
- [ ] New remote read goes through the query cache (staleness + dedup); its mutation invalidates the affected keys; in-flight requests cancel on unmount / param change.
- [ ] New route root / failing subtree wrapped by an error boundary with retry + error-sink report; a global `onunhandledrejection` net exists for async errors.
- [ ] New lazy chunk pairs with a Suspense fallback + a chunk-load error boundary; the LCP path is not lazy.
- [ ] New realtime connection reconnects with backoff, heartbeats, re-auths on reconnect, tears down on unmount, and dedups inbound messages.
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
- Navigation / streaming / instant-loading / bfcache checks via the `navigation-speed` + `streaming-ssr` skills; bfcache verified in DevTools Application → Back/forward cache (no `unload` / `beforeunload` evictors).
- LCP / image / font / SEO checks via the `lcp-audit` · `image-optimization` · `font-optimization` · `seo-audit` skills (and the `@technical-seo` reviewer); Lighthouse CI **SEO + best-practices** categories on public routes, in addition to the perf category.
