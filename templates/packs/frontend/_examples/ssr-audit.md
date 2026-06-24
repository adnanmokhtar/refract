---
name: ssr-audit
description: Static scan for hydration mismatch sources in SSR apps (Nuxt / Next / SvelteKit). Catches bugs before runtime.
---

# ssr-audit

## Scans for

### Browser-only APIs at module scope

```
BAD:
const width = window.innerWidth;

GOOD:
onMounted(() => { const width = window.innerWidth; });
```

Grep patterns: `window\.`, `document\.`, `localStorage\.`, `sessionStorage\.`, `navigator\.`.

### Unkeyed / misused data fetching

```
BAD:
const data = await $fetch('/api/x');    // duplicates on client

GOOD:
const { data } = await useFetch('/api/x', { key: 'products-list' });
```

### Non-deterministic values in render

```
BAD:
<div>{{ Math.random() }}</div>
<div>{{ new Date().toLocaleTimeString() }}</div>

GOOD:
<div>{{ stableId }}</div>   // computed once, via useState
```

### Plugin side-effects at module scope

```
BAD:
window.addEventListener('resize', ...);  // at module top

GOOD:
export default defineNuxtPlugin(() => {
  if (import.meta.client) window.addEventListener(...);
});
```

### Tenant identity written from browser state during SSR

If multi-tenant — tenant must come from the REQUEST (host header), not from browser localStorage or cookies read on client.

### Client-boundary cost (React Server Components)

React / Next App Router specific. Every `"use client"` directive ships JS + hydrates from that file down.

- **Unjustified directive** — among `"use client"` files, `grep -L 'useState|useEffect|useReducer|onClick|onChange|window\.|document\.|addEventListener'` → each hit can DELETE the directive (renders server-side, 0 JS). False-positive: a `useContext`-of-client-context consumer still needs it.
- **Boundary too high** — a `"use client"` file importing large server-safe children → push the directive down to the interactive leaf; pass the subtree via the `children` prop.
- **Server-only leak (BLOCKER)** — a db/`fs`/secret module imported into a `"use client"` file → that code is now in the client bundle.

Halt: never strip a directive without the `grep -L` proving zero state/effect/event/browser usage.

## Output

```
SSR audit — <route or full scan>

Findings: 3

1. composables/useAnalytics.ts:8
   Module-scope `window.location.pathname`.
   Fix: move inside a function called from onMounted().

2. pages/products.vue:24
   Unkeyed useAsyncData — will collide across tenants.
   Fix: add explicit `key: \`products-\${tenantId}\``.

3. plugins/theme.ts:4
   Module-scope `document.body.classList.add`.
   Fix: wrap in defineNuxtPlugin + import.meta.client guard.
```

## Rules

- Static only — doesn't run the app. Fast, complete in seconds.
- Some false positives possible (e.g., `document.createElement` inside `onMounted`). Review findings, don't blindly fix.
- Pair with runtime Playwright hydration check for ground truth.

## When to run

- Before every SSR-related PR merge.
- Weekly via CI scheduled job.
- After adding a plugin / composable that touches browser APIs.
