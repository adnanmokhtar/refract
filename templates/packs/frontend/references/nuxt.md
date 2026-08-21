# Nuxt SSR rules

> **Framework**: Nuxt 3.10+ (Nitro 2.9+) on Node 20+ • Vue 3.4+
> **Official docs**: https://nuxt.com/docs
> **Version-specific gotchas**: Nuxt 3.10+ ships server components (`.server.vue` files); auto-imports include `useNuxtData`, `useRequestEvent`; Nuxt 4 (preview) restructures `app/` directory (opt-in via `compatibilityVersion: 4`); `useFetch` SSR hydration changed in 3.7 — pass `key` for dynamic URLs.
> **Substitution markers**: Replace project-specific composable / API endpoint names per `_extracted-idioms.md`.

## Machine-readable docs (check these before trusting this file)

Nuxt ships **no documentation inside the installed package** — verified against `nuxt@4.5.2`, whose published
tarball carries 302 files and no docs directory. But Nuxt gets closer to version-matching than the other hosted
docs here, because its doc URLs are **segmented by major**: `.../docs/4.x/...`. Read the major from
`package.json` and request that segment rather than the unversioned path.

- **Index**: `https://nuxt.com/llms.txt` (~57 KB) — large for an index, because it lists every page as a
  ready-to-fetch Markdown URL.
- **Per-page Markdown**: a `/raw/` **prefix**, not an appended suffix — the page at `nuxt.com/docs/4.x/<path>`
  is fetched as `nuxt.com/raw/docs/4.x/<path>.md`, served as `text/markdown`. Appending `.md` to the ordinary
  page URL instead returns a **404 JSON body**. Getting this shape wrong looks like the docs are missing when
  they are not.
- **Full text**: `https://nuxt.com/llms-full.txt` exists but is ~4.4 MB — far past any sane context budget.
  Grep it if you must; otherwise use the index plus the one page you need.

Same rule as everywhere in this directory: hosted docs are the **API surface**, this file is the **house
opinion** (never `$fetch` in setup, explicit `key` on dynamic `useAsyncData`, one metadata mechanism). Where the
two disagree about an API, the docs win and this file is stale — say so rather than emitting the older call.
Where the network is unavailable, this file is what you have; it does not halt.

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

- Every public indexed route sets `useSeoMeta({ title, description, ogTitle, ogDescription, ogImage, twitterCard: 'summary_large_image' })`; dynamic routes set it inside the `useAsyncData` callback so it fires with data.
- **Canonical + hreflang**: `useHead({ link: [{ rel: 'canonical', href }, …hreflang alternates] })` — `@nuxtjs/i18n` can emit hreflang automatically.
- **JSON-LD**: `useHead({ script: [{ type: 'application/ld+json', innerHTML: … }] })`, or `nuxt-schema-org` / the Nuxt SEO module for typed Article / Product / Breadcrumb.
- **Sitemap + robots**: `@nuxtjs/sitemap` (must include dynamic routes) + `@nuxtjs/robots` (point at the sitemap).
- One metadata mechanism only. See `frontend/skills/seo-audit/SKILL.md` + `@technical-seo`.

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

- `<NuxtLink>` for ALL internal nav — prefetches in-viewport links by default. `:prefetch="false"` disables it; `prefetchOn="interaction"` defers to hover/focus instead of viewport. (Sibling audit: `frontend/skills/navigation-speed/SKILL.md`.)
- `useFetch(url, { lazy: true })` / `useLazyFetch` to NOT block navigation — the route renders immediately and data fills in. Use `{ server: false }` for client-only data that needn't be in the SSR payload.
- Payload extraction: `experimental: { payloadExtraction: true }` emits a static `_payload.json` per prerendered route, so navigations hydrate from a flat file instead of re-running fetches.
- Islands / server components: `.server.vue` + `<NuxtIsland>` render server-only HTML with no client JS — zero hydration cost for static-ish regions.

## Core Web Vitals levers

- Images: `<NuxtImg>` / `<NuxtPicture>` (`@nuxt/image`) with explicit `width`/`height` + `sizes` + `format="avif"` — fixed dimensions prevent CLS, responsive `sizes` cuts bytes. (Sibling audit: `frontend/skills/lcp-audit/SKILL.md`.)
- LCP image: set `preload` and `:loading="'eager'"` (default is `lazy`) — NEVER lazy-load the hero / above-the-fold LCP image. Reinforce with `useHead({ link: [{ rel: 'preload', as: 'image', href }] })` when the LCP source isn't statically discoverable.
- Fonts: `@nuxt/fonts` for self-hosted + `font-display` + preload, avoiding layout shift from late web-font swaps.
- INP: keep main-thread work off the interaction path — field INP (good = 200ms at p75) is measured in the field, not in lab (sibling: `performance/skills/web-vitals-field/SKILL.md`, `performance/ai-patterns/inp-responsiveness.md`).

## Anti-patterns

- Raw `<a>` / `<router-link>` for internal nav — skips `<NuxtLink>` prefetch + client-side routing → full reloads.
- Blocking `useFetch` on slow, non-critical data instead of `{ lazy: true }` — the whole route waits on data the user doesn't need yet.
