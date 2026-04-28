# Nuxt SSR rules

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
