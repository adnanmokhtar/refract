---
name: ssr-safety
kind: example
pack: frontend
---

# Pattern: SSR Safety

SSR renders on the server, hydrates on the client. The server-rendered **DOM tree** must match the first client render (tree, not bytes — attribute order and whitespace differ routinely). Anything else that differs is a hydration mismatch.

## Scope

Applies to Nuxt, Next (App Router), SvelteKit, Remix — any framework that does SSR.

## Browser-only APIs

Guard `window`, `document`, `localStorage`, `sessionStorage`, `navigator`:

```ts
// Option 1: client lifecycle — the default. Runs after mount, never during render.
onMounted(() => { window.addEventListener(...); });   // Vue / Nuxt; useEffect(..., []) in React

// Option 2: client-only component wrapper — the subtree never renders on the server.
<ClientOnly>
  <ComponentUsingWindow />
</ClientOnly>

// Option 3: an environment check INSIDE a non-render function (handler / util called
// from an effect). Legitimate here; the SAME check branching the returned markup is
// the bug this pattern exists to reject.
function persistTheme(t) {
  if (import.meta.client /* Nuxt */ || typeof window !== 'undefined') localStorage.setItem('theme', t);
}
```

## Non-deterministic values

Anything that differs between server + client breaks hydration:

- `new Date()` — server and client clocks differ
- `Math.random()` / `crypto.randomUUID()` — different values
- User-agent branches — different results

Fix, in order: (1) generate on one side and pass via `useState` / props / loader data; (2) use the framework's SSR-stable id API (`useId()`) for a11y wiring instead of a counter; (3) suppress deliberately on the ONE leaf that legitimately differs (a clock reading), never on a container.

## Data fetching

Use the framework's SSR-aware fetcher:

- Nuxt: `useFetch` / `useAsyncData` with explicit `key`
- Next (App Router): `await fetch()` inside an **async Server Component** is the documented primitive — Server Components do not re-run on the client, so there is no double fetch, and identical requests are memoized per request
- SvelteKit: `load` functions

NEVER a bare `fetch()` in a **client** component body (a `setup()` block, a hydrating function-component body) — SSR runs it, the client re-runs it, and the two results race. Grade by component kind, not by the word `fetch`.

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
- Unkeyed `useAsyncData` / fetch — same key collides across pages (across tenants, a data leak)
- Conditional rendering based on `typeof window !== 'undefined'` — two trees by construction
- Formatting dates / numbers without an explicit locale + timeZone — container locale is not the user's
- Mismatch suppression on a container instead of the differing leaf — hides the cause
- An external store read during SSR with no server snapshot — empty on the server, full on the client

## Auditing

Run the `ssr-audit` skill (in-pack) — it grep-scans for these anti-patterns before they ship. Static only: a clean scan is a floor, not a hydration guarantee.

## Forbidden

- Module-scope `window` / `document` access.
- A bare `fetch()` in a client component body (use SSR-aware fetchers, or `use()` on a server-passed promise).
- Non-deterministic values in render output with no transfer and no scoped suppression.
- An environment check that changes the returned markup.
- Reading tenant from browser state during SSR.
