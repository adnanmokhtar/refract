---
name: ssr-safety
description: Pattern: SSR Safety
kind: ai-pattern
pack: frontend
---

# Pattern: SSR Safety

SSR renders on the server, hydrates on the client. Anything that differs between the two = hydration mismatch = broken page.

## Scope

Applies to Nuxt, Next (App Router), SvelteKit, Remix — any framework that does SSR.

## Browser-only APIs

Guard `window`, `document`, `localStorage`, `sessionStorage`, `navigator`:

```ts
// Option 1: runtime guard
if (import.meta.client /* Nuxt */ || typeof window !== 'undefined') {
  localStorage.setItem('x', 'y');
}

// Option 2: client-only component wrapper
<ClientOnly>
  <ComponentUsingWindow />
</ClientOnly>

// Option 3: lifecycle hook that only fires client-side
onMounted(() => { window.addEventListener(...); });
```

## Non-deterministic values

Anything that differs between server + client breaks hydration:

- `new Date()` — server and client clocks differ
- `Math.random()` / `crypto.randomUUID()` — different values
- User-agent branches — different results

Fix: generate on one side, pass via `useState` / props / data hydration.

## Data fetching

Use the framework's SSR-aware fetcher:

- Nuxt: `useFetch` / `useAsyncData` with explicit `key`
- Next: `fetch()` in Server Components or `revalidateTag`
- SvelteKit: `load` functions

NEVER plain `fetch()` in a component setup block — SSR runs it, client re-runs it, duplicate calls and cache misses.

## Multi-tenant SSR

Tenant must be resolved from the REQUEST on the server, not from browser state:

```
1. Server receives request (Host header = tenant domain)
2. Resolve tenant synchronously before rendering
3. Inject tenant into AsyncLocalStorage for the request lifetime
4. Render with tenant-scoped data
5. Hydrate on client with the SAME tenant (passed via server → client state)
```

One-writer rule: the server writes tenant identity ONCE at request start. No downstream code may overwrite it.

## Common mismatch sources

- Module-scope DOM access (`const width = window.innerWidth`) — runs on both, differs
- Unkeyed `useAsyncData` / fetch — same key collides across pages
- Conditional rendering based on `typeof window !== 'undefined'` — template differs
- Formatting dates / numbers without explicit locale — browser vs server locale differ

## Auditing

Run `/ssr-audit` or the skill equivalent — it grep-scans for these anti-patterns before they ship.

## Forbidden

- Module-scope `window` / `document` access.
- `fetch()` in component setup (use SSR-aware fetchers).
- Non-deterministic values in render output.
- Different markup between server and client render.
- Reading tenant from browser state during SSR.
