# Vue 3 + Pinia conventions

> **Framework**: Vue 3.4+ • Pinia 2.1+ • Vite 5+ • TypeScript 5+
> **Official docs**: https://vuejs.org/guide/ • https://pinia.vuejs.org/
> **Version-specific gotchas**: Vue 3.4 brought `defineModel()` macro (replaces manual prop+emit for v-model); 3.3+ supports generic components (`<script setup lang="ts" generic="T">`); 3.5 added `useTemplateRef()`; Pinia 2.1 stable, do NOT mix Options API stores in a setup-API codebase.
> **Substitution markers**: Replace component / composable / store names with the project's actual entries from `_extracted-idioms.md`.

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
- Prefetch: vue-router `<router-link>` does NOT auto-prefetch the route's dynamic-import chunk (unlike NuxtLink / Next.js `<Link>`). Warm the import manually on hover/viewport (`@mouseenter="() => import('./views/Heavy.vue')"`) or adopt a quicklink-style strategy. See `frontend/skills/navigation-speed.md`.
- Image / CWV: plain Vue has no image component. On the LCP `<img>` set `fetchpriority="high"` + explicit `width`/`height` (reserve space, no CLS); use `loading="lazy"` below-fold. See `frontend/skills/lcp-audit.md`.

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

## Tests

- Vitest + @vue/test-utils.
- Unit test composables with pure imports.
- Component tests render + interact + assert, don't snapshot the whole tree.
