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

## Stores

- Simple reactive values → `$state` in lib modules.
- Cross-component global → writable/readable stores from `svelte/store` OR runes in a module scope.

## Styling

- Scoped `<style>` by default.
- Global styles in `app.css`.
- Use CSS custom properties for theme tokens.

## Anti-patterns

- Using old `$:` syntax in Svelte 5 — use runes
- Using Svelte stores for what could be `$state`
- Putting server secrets in `+page.ts` (runs on client) — use `+page.server.ts`
