---
name: ssr-audit
description: Static scan for hydration-mismatch sources in SSR apps (Nuxt / Next / SvelteKit) — catches the bug before runtime. Run before merging an SSR-related PR and after adding a plugin or composable that touches browser APIs. Correctness only — `streaming-ssr` is the sibling that makes a correct SSR render fast.
---

# ssr-audit

## Premise

Find real hydration risks, not hand-waves. Every finding cites `<file:line>` + the offending pattern + the fix. "Might have hydration issues" is not a finding. A grep that returns zero hits in a non-trivial SSR codebase is suspicious — re-check the patterns. False positives are acceptable when flagged as "review"; silent skips are not.

A scan that produces zero output without proving the patterns matched is a failed scan.

## Adapt to the codebase

Detect the SSR framework and phrase every finding + fix in the server/client boundary primitive the project actually uses — never impose another framework's shape:

| Framework | Server / client boundary | Browser-only escape hatch |
|---|---|---|
| **Next.js (App Router)** | Server Components default; `'use client'` marks the client boundary; `cookies()` / `headers()` are server-only | `useEffect` / `typeof window !== 'undefined'` guard in a client component |
| **Nuxt 3** | `useAsyncData` / `useFetch` (SSR-safe); `.server.ts` / `.client.ts` plugin suffixes | `import.meta.client` guard; `onMounted` |
| **SvelteKit** | `+page.server.ts` load (server-only); `+page.ts` runs on both | `browser` from `$app/environment`; `onMount` |
| **Remix / React Router** | `loader` runs server-side | `useEffect`; `typeof document` guard |
| **Angular (SSR/Universal)** | `isPlatformServer` / `isPlatformBrowser(PLATFORM_ID)`; route resolvers run server-side | `afterNextRender()` / `afterRender()`; `TransferState` to avoid a double-fetch |

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

If multi-tenant, the tenant MUST come from the REQUEST (host header / server context), never from `localStorage` or a client-read cookie — on the server those are unavailable, so the wrong tenant (or a cross-tenant leak) renders.

```
BAD:  const tenant = localStorage.getItem('tenant')          // undefined on the server → wrong render
GOOD (Next):  const tenant = headers().get('host')           // request-derived, server-safe
GOOD (Nuxt):  const tenant = useRequestHeaders(['host']).host
```

Grep: `localStorage`, `sessionStorage`, `document.cookie` read in a file that also runs server-side (page / route / `loader` / `useAsyncData` / server component) to resolve a tenant / org / workspace identity. Flag any such value sourced from browser storage on an SSR path.

### Client-boundary cost (React Server Components)

React / Next App Router specific (the sections above are Nuxt-leaning). Every `"use client"` directive marks a hydration boundary — everything from that file down ships JS and hydrates. An unjustified directive is wasted client-JS.

```
BAD:
"use client";                         // file has no state/effect/event/browser API
export function Price({ amount }) { return <span>{format(amount)}</span>; }

GOOD:
export function Price({ amount }) { return <span>{format(amount)}</span>; }  // server component, ships 0 JS
```

Detectors:

- **Detector 1 — unjustified directive.** Among files starting with `"use client"`, `grep -L` for `useState|useEffect|useReducer|onClick|onChange|window\.|document\.|addEventListener`. Each `grep -L` hit = a boundary with no interactivity → candidate to DELETE the directive so the component renders on the server.
- **Detector 2 — boundary too high.** A `"use client"` file importing large server-safe children → push `"use client"` DOWN to the interactive leaf; pass the server-rendered subtree via the `children` prop/slot instead of importing it under the boundary.
- **Detector 3 — server-only leak (BLOCKER).** A server-only module (db client / `fs` / secret / env key) imported into a `"use client"` file → boundary-leak BLOCKER. The secret/server code is now in the client bundle.
- **False-positive:** a component consuming a client Context (`useContext` of a client context) still needs the directive — do NOT strip it just because Detector 1's grep missed `useState`/`useEffect`.
- **Halt:** never strip a directive without proving (grep) zero state/effect/event/browser usage. The verdict must show the `grep -L` that matched.

Output per finding: `file:line` of the directive + why it's unjustified + the demotion/push-down fix + estimated client-JS / hydration saved.

> bfcache note: `grep` for `addEventListener('unload'|'beforeunload')` → cite `<file:line>` + `bfcache-blocking; switch to pagehide`. See `navigation-speed.md` for the full prefetch / Speculation Rules / bfcache audit.

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

## Halt conditions

- Halt on hand-waves: every finding must cite `<file:line>` + the pattern matched + a concrete fix. "Might cause hydration issues" without a line is not a finding.
- Halt if a finding is dismissed without verification — `document.createElement` inside `onMounted` is fine, but the verdict must say so explicitly.
- Halt if the audit returns zero findings on a multi-page SSR app without listing the grep patterns actually executed.
- Halt if a fix relies on `import.meta.client` guards being added but the guard isn't shown in the suggested patch.
