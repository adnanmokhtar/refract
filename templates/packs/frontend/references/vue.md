# Vue 3 + Pinia conventions

> **Framework**: Vue 3.4+ • Pinia 2.1+ • Vite 5+ • TypeScript 5+
> **Official docs**: https://vuejs.org/guide/ • https://pinia.vuejs.org/
> **Version-specific gotchas**: Vue 3.4 brought `defineModel()` macro (replaces manual prop+emit for v-model); 3.3+ supports generic components (`<script setup lang="ts" generic="T">`); 3.5 added `useTemplateRef()`; Pinia 2.1 stable, do NOT mix Options API stores in a setup-API codebase.
> **Substitution markers**: Replace component / composable / store names with the project's actual entries from `_extracted-idioms.md`.

## Machine-readable docs (check these before trusting this file)

Vue ships **no documentation inside the installed package** — verified against `vue@3.5.41`, whose published
tarball carries 37 files and no docs directory. There is therefore no version-matched local copy to read, and the
hosted docs below track *latest*, not what is in your `package.json`. Reconcile the two before you trust an API.

- **Index**: `https://vuejs.org/llms.txt` (~7 KB) — the cheap first read.
- **Per-page Markdown**: append `.md` to a page URL (`https://vuejs.org/guide/introduction.md`), served as
  `text/markdown`. This is the clean path — prefer it over scraping the rendered page.
- **Full text**: `https://vuejs.org/llms-full.txt` exists (~950 KB). Treat it as a file to grep, not to read into
  context; the index plus one page is almost always the right call.

Same rule as everywhere in this directory: hosted docs are the **API surface**, this file is the **house
opinion** (`<script setup>` mandatory, no Options API, no `fetch` in a component, one styling system). Where the
two disagree about an API, the docs win and this file is stale — say so rather than emitting the older call.
Where the network is unavailable, this file is what you have; it does not halt.

## Components

- `<script setup lang="ts">` mandatory. No Options API.
- Props via `defineProps<Props>()` — typed interface.
- Emits via `defineEmits<{ (e: 'x', val: T): void }>()`.
- Single-file components: `<template>` → `<script setup>` → `<style scoped>`.
- Component names are PascalCase files (`UserCard.vue`).

## Composables

- Named `use<Thing>()` in `composables/`.
- Return an object, never a tuple.
- No side-effects on import — only on call.

## Stores (Pinia)

- Setup syntax preferred: `defineStore('name', () => { ... })`.
- Match existing repo style — don't mix Options and setup-syntax stores.
- Actions are async functions returning domain objects.
- Never mutate state from outside the store.

## Routing

- Route-level components in `views/` or `pages/`.
- Lazy-load all routes: `component: () => import('./...')`.
- Route meta declares auth/permissions.

## Async components & streaming

- Lazy heavy components: `defineAsyncComponent(() => import('./Heavy.vue'))`. Configure the fallback explicitly — `{ loadingComponent, errorComponent, delay, timeout }` (without `loadingComponent` there is NO loading UI; without `errorComponent` a load failure renders nothing).
- `<Suspense>` orchestrates async setup with a fallback slot — `<template #default>` / `<template #fallback>`. NOTE: still **experimental**; API may change.
  ```vue
  <Suspense>
    <template #default><AsyncDashboard /></template>
    <template #fallback><Spinner /></template>
  </Suspense>
  ```
- Prefetch: vue-router `<router-link>` does NOT auto-prefetch the route's dynamic-import chunk (unlike NuxtLink / Next.js `<Link>`). Warm the import manually on hover/viewport (`@mouseenter="() => import('./views/Heavy.vue')"`) or adopt a quicklink-style strategy. See `frontend/skills/navigation-speed/SKILL.md`.
- Image / CWV: plain Vue has no image component. On the LCP `<img>` set `fetchpriority="high"` + explicit `width`/`height` (reserve space, no CLS); use `loading="lazy"` below-fold. See `frontend/skills/lcp-audit/SKILL.md`.

**Anti-patterns**

- Top-level static `import` of a heavy editor / chart (e.g. `import Editor from 'tiptap'`) — ships it in the initial bundle. Use `defineAsyncComponent`.
- Assuming `<router-link>` prefetches the route chunk — it does not; the chunk loads only on navigation unless you warm it.

## API

- NEVER call `fetch` / `axios` from a component.
- Use `services/<entity>.service.ts` wrapping a typed API client.
- DTOs live in a shared types file or package.

## Styling

- Scoped styles by default.
- Use the repo's declared CSS system (Tailwind / PrimeVue / SCSS). Don't mix.

## i18n

- NEVER hardcode user-facing strings in templates.
- Every visible string has a key in BOTH locales.
- Use same key for same concept across sibling frontends when a workspace exists.

## SEO

- SPA Vue renders an empty root to crawlers — indexable content needs SSR (Nuxt) or a prerender step; client-set meta won't reach scrapers.
- Manage `<head>` with **`@unhead/vue`** (`useHead` / `useSeoMeta`) — unique title + description, canonical `link`, OG/Twitter, and JSON-LD via `useHead({ script: [{ type: 'application/ld+json', children: … }] })`. One mechanism only. See `frontend/skills/seo-audit/SKILL.md` + `@technical-seo`.

## Fonts

- Self-host via **`@fontsource/*`** / Fontaine (no remote Google Fonts `<link>`); `font-display: swap`; preload the critical font (`crossorigin`); size-adjusted fallback (swap-CLS); variable font over ≥3 weights. See `frontend/skills/font-optimization/SKILL.md`.

## Tests

- Vitest + @vue/test-utils.
- Unit test composables with pure imports.
- Component tests render + interact + assert, don't snapshot the whole tree.
