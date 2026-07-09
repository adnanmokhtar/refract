# Svelte / SvelteKit reference (Svelte 5, runes)

> **Framework**: Svelte 5.0+ • SvelteKit 2.5+ • Vite 5+
> **Official docs**: https://svelte.dev/docs/svelte/overview • https://kit.svelte.dev/docs/
> **Version-specific gotchas**: Svelte 5 introduced runes (`$state`, `$derived`, `$effect`, `$props`) — replaces `let` reactive declarations + `$:` syntax; component instantiation API changed (no more `new Component()`); slot syntax replaced by snippets (`{#snippet}`); `<svelte:component this={X}>` deprecated in favor of dynamic component as variable.
> **Substitution markers**: Replace `<name>` / route paths with the project's actual entries.

## Structure (SvelteKit)

```
src/
├── routes/
│   ├── +layout.svelte
│   ├── +page.svelte
│   ├── +page.server.ts        # server-only loader / actions
│   └── api/<name>/+server.ts
├── lib/
│   ├── components/
│   ├── stores/
│   └── server/                 # server-only code
└── app.html
```

## Svelte 5 (runes)

- Use `$state` / `$derived` / `$effect` runes — NOT the old `$:` syntax.
- `$props()` replaces `export let`.
- `$state` is deep-reactive; mutations trigger updates.

## Data

- Load in `+page.server.ts` or `+page.ts` `load` function.
- Use form actions for mutations (`+page.server.ts` with `actions: { default: ... }`).
- Progressive enhancement by default.

## Navigation & streaming

- **Link preloading**: `data-sveltekit-preload-data="hover|tap|off"` preloads the destination's `load` data; `data-sveltekit-preload-code="eager|viewport|hover|tap"` preloads its code (tunable separately, e.g. eager code + hover data). Set a default on `<body>` in `app.html` and override per-link. See `frontend/skills/navigation-speed.md`.
- **Streamed promises**: in `load`, `await` only critical data and return un-awaited promises for the rest — `return { post, comments: getComments() }` — so the page renders before the slow query resolves. Consume with `{#await data.comments}` in `+page.svelte`. See `frontend/skills/streaming-ssr.md`.
- **Page options**: `export const prerender = true` (build to static HTML) / `ssr = false` (skip server render) / `csr = false` (ship no JS).
- **Forms**: `use:enhance` on `<form>` for client-side progressive enhancement of actions without a full reload.
- **CWV**: use `enhanced:img` for responsive/optimized images; add `<link rel="preconnect">` for cross-origin asset/font hosts in `+layout.svelte`. For LCP priority hints see `frontend/skills/lcp-audit.md`.

Anti-patterns:

- `await`-ing all data in `load` — blocks the response on the slowest query; stream non-critical data via un-awaited promises instead.
- No `preload-data` on primary navigation links — first click pays full data-load latency with no warm-up.

## Stores

- Simple reactive values → `$state` in lib modules.
- Cross-component global → writable/readable stores from `svelte/store` OR runes in a module scope.

## SEO

- Set metadata in `<svelte:head>` in `+page.svelte`, driven by `+page.ts` / `+page.server.ts` `load` data — unique title + description, canonical, OG/Twitter, and JSON-LD (`<script type="application/ld+json">{@html …}</script>`). Prerender indexable static routes (`export const prerender = true`) so the head reaches crawlers.
- One mechanism only. See `frontend/skills/seo-audit.md` + `@technical-seo`.

## Fonts

- Self-host via **`@fontsource/*`** (or Fontaine for `size-adjust` fallbacks) — no remote Google Fonts `<link>`. `font-display: swap`; preload the critical font in `app.html` (`<link rel="preload" as="font" crossorigin>`); variable font over ≥3 weights. See `frontend/skills/font-optimization.md`.

## Styling

- Scoped `<style>` by default.
- Global styles in `app.css`.
- Use CSS custom properties for theme tokens.

## Anti-patterns

- Using old `$:` syntax in Svelte 5 — use runes
- Using Svelte stores for what could be `$state`
- Putting server secrets in `+page.ts` (runs on client) — use `+page.server.ts`
