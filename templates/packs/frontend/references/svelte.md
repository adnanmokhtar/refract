# Svelte / SvelteKit reference (Svelte 5, runes)

> **Framework**: Svelte 5.0+ • SvelteKit 2.5+ • Vite 5+
> **Official docs**: https://svelte.dev/docs/svelte/overview • https://kit.svelte.dev/docs/
> **Version-specific gotchas**: Svelte 5 introduced runes (`$state`, `$derived`, `$effect`, `$props`) — replaces `let` reactive declarations + `$:` syntax; component instantiation API changed (no more `new Component()`); slot syntax replaced by snippets (`{#snippet}`); `<svelte:component this={X}>` deprecated in favor of dynamic component as variable.
> **Substitution markers**: Replace `<name>` / route paths with the project's actual entries.

## Machine-readable docs (check these before trusting this file)

Svelte ships **no documentation inside the installed package** — verified against `svelte@5.56.10`, whose
published tarball carries 390 files and no docs directory. The hosted docs track *latest*, not what is in your
`package.json`; reconcile the two before you trust an API. Svelte's distinctive move is that it publishes the
**same docs at several compression levels**, so you pick by context budget rather than truncating blindly:

- **Index**: `https://svelte.dev/llms.txt` (~1.7 KB) — just a listing of the files below. Always the first read.
- **By budget**: `llms-small.txt` (~53 KB, abridged) → `llms-medium.txt` (~830 KB) → `llms-full.txt` (~1.2 MB,
  Svelte + SvelteKit + CLI). Only the small tier is realistically pasteable.
- **By package**: `https://svelte.dev/docs/svelte/llms.txt` and `https://svelte.dev/docs/kit/llms.txt` (plus
  `/docs/cli/llms.txt`, and `-small` variants). Despite the `llms.txt` name these are full documentation
  **bodies** (~476 KB and ~589 KB), not indexes — fetch the one runtime you actually need.
- **No per-page Markdown.** Appending `.md` to a docs URL 404s; the tiered files above are the whole mechanism.

Same rule as everywhere in this directory: hosted docs are the **API surface**, this file is the **house
opinion** (runes over `$:`, stream non-critical `load` data, no secrets in `+page.ts`). Where the two disagree
about an API, the docs win and this file is stale — say so rather than emitting the older call. Where the
network is unavailable, this file is what you have; it does not halt.

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

- **Link preloading**: `data-sveltekit-preload-data="hover|tap|off"` preloads the destination's `load` data; `data-sveltekit-preload-code="eager|viewport|hover|tap"` preloads its code (tunable separately, e.g. eager code + hover data). Set a default on `<body>` in `app.html` and override per-link. See `frontend/skills/navigation-speed/SKILL.md`.
- **Streamed promises**: in `load`, `await` only critical data and return un-awaited promises for the rest — `return { post, comments: getComments() }` — so the page renders before the slow query resolves. Consume with `{#await data.comments}` in `+page.svelte`. See `frontend/skills/streaming-ssr/SKILL.md`.
- **Page options**: `export const prerender = true` (build to static HTML) / `ssr = false` (skip server render) / `csr = false` (ship no JS).
- **Forms**: `use:enhance` on `<form>` for client-side progressive enhancement of actions without a full reload.
- **CWV**: use `enhanced:img` for responsive/optimized images; add `<link rel="preconnect">` for cross-origin asset/font hosts in `+layout.svelte`. For LCP priority hints see `frontend/skills/lcp-audit/SKILL.md`.

Anti-patterns:

- `await`-ing all data in `load` — blocks the response on the slowest query; stream non-critical data via un-awaited promises instead.
- No `preload-data` on primary navigation links — first click pays full data-load latency with no warm-up.

## Stores

- Simple reactive values → `$state` in lib modules.
- Cross-component global → writable/readable stores from `svelte/store` OR runes in a module scope.

## SEO

- Set metadata in `<svelte:head>` in `+page.svelte`, driven by `+page.ts` / `+page.server.ts` `load` data — unique title + description, canonical, OG/Twitter, and JSON-LD (`<script type="application/ld+json">{@html …}</script>`). Prerender indexable static routes (`export const prerender = true`) so the head reaches crawlers.
- One mechanism only. See `frontend/skills/seo-audit/SKILL.md` + `@technical-seo`.

## Fonts

- Self-host via **`@fontsource/*`** (or Fontaine for `size-adjust` fallbacks) — no remote Google Fonts `<link>`. `font-display: swap`; preload the critical font in `app.html` (`<link rel="preload" as="font" crossorigin>`); variable font over ≥3 weights. See `frontend/skills/font-optimization/SKILL.md`.

## Styling

- Scoped `<style>` by default.
- Global styles in `app.css`.
- Use CSS custom properties for theme tokens.

## Anti-patterns

- Using old `$:` syntax in Svelte 5 — use runes
- Using Svelte stores for what could be `$state`
- Putting server secrets in `+page.ts` (runs on client) — use `+page.server.ts`
