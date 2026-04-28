# Vue 3 + Pinia conventions

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
