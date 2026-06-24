# Nuxt SSR rules

> **Framework**: Nuxt 3.10+ (Nitro 2.9+) on Node 20+ • Vue 3.4+
> **Official docs**: https://nuxt.com/docs
> **Version-specific gotchas**: Nuxt 3.10+ ships server components (`.server.vue` files); auto-imports include `useNuxtData`, `useRequestEvent`; Nuxt 4 (preview) restructures `app/` directory (opt-in via `compatibilityVersion: 4`); `useFetch` SSR hydration changed in 3.7 — pass `key` for dynamic URLs.
> **Substitution markers**: Replace project-specific composable / API endpoint names per `_extracted-idioms.md`.

## Data fetching

- Use `useFetch` / `useAsyncData` for data. They're cache-aware, SSR-friendly, and dedupe.
- NEVER call `fetch()` / `$fetch()` in a component setup block — SSR cache misses.
- `useFetch` in `setup()` only; in event handlers, use `$fetch`.
- Explicit `key` on `useAsyncData` when the URL is dynamic — prevents cache collisions.

## SSR safety

- `window`, `document`, `localStorage` are client-only. Guard with `import.meta.client` or wrap in `<ClientOnly>`.
- Plugins ending in `.server.ts` run on server only; `.client.ts` on client only.
- Avoid module-scope side-effects — they run on every request.

## SEO

- Every public indexed route has `useSeoMeta({ title, description, ogImage })`.
- Dynamic routes set meta inside `useAsyncData` callback to fire with data.

## State

- `useState('key', () => default)` for SSR-safe reactive state.
- Pinia stores auto-hydrate — no manual state injection needed.

## i18n

- Never hardcode user-facing strings.
- For multi-locale: `nuxt-i18n` module, same key across locales.

## Multi-theme (if applicable)

- Themes are runtime variants. Single component tree, themed via CSS variables or a Vue provide/inject token.
- NEVER fork pages / composables / stores per theme.

## Navigation & streaming

- `<NuxtLink>` for ALL internal nav — prefetches in-viewport links by default. `:prefetch="false"` disables it; `prefetchOn="interaction"` defers to hover/focus instead of viewport. (Sibling audit: `frontend/skills/navigation-speed.md`.)
- `useFetch(url, { lazy: true })` / `useLazyFetch` to NOT block navigation — the route renders immediately and data fills in. Use `{ server: false }` for client-only data that needn't be in the SSR payload.
- Payload extraction: `experimental: { payloadExtraction: true }` emits a static `_payload.json` per prerendered route, so navigations hydrate from a flat file instead of re-running fetches.
- Islands / server components: `.server.vue` + `<NuxtIsland>` render server-only HTML with no client JS — zero hydration cost for static-ish regions.

## Core Web Vitals levers

- Images: `<NuxtImg>` / `<NuxtPicture>` (`@nuxt/image`) with explicit `width`/`height` + `sizes` + `format="avif"` — fixed dimensions prevent CLS, responsive `sizes` cuts bytes. (Sibling audit: `frontend/skills/lcp-audit.md`.)
- LCP image: set `preload` and `:loading="'eager'"` (default is `lazy`) — NEVER lazy-load the hero / above-the-fold LCP image. Reinforce with `useHead({ link: [{ rel: 'preload', as: 'image', href }] })` when the LCP source isn't statically discoverable.
- Fonts: `@nuxt/fonts` for self-hosted + `font-display` + preload, avoiding layout shift from late web-font swaps.
- INP: keep main-thread work off the interaction path — field INP (good = 200ms at p75) is measured in the field, not in lab (sibling: `performance/skills/web-vitals-field.md`, `performance/ai-patterns/inp-responsiveness.md`).

## Anti-patterns

- Raw `<a>` / `<router-link>` for internal nav — skips `<NuxtLink>` prefetch + client-side routing → full reloads.
- Blocking `useFetch` on slow, non-critical data instead of `{ lazy: true }` — the whole route waits on data the user doesn't need yet.
