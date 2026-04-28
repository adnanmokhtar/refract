# Svelte / SvelteKit reference (Svelte 5, runes)

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
