---
name: ssr-audit
description: Static scan for hydration-mismatch sources in SSR apps (Nuxt / Next / SvelteKit) — catches the bug before runtime. Run before merging an SSR-related PR and after adding a plugin or composable that touches browser APIs. Correctness only — `streaming-ssr` is the sibling that makes a correct SSR render fast.
---

# ssr-audit

## Premise

Find real hydration risks, not hand-waves. Every finding cites `<file:line>` + the offending pattern + the fix. "Might have hydration issues" is not a finding. A grep that returns zero hits in a non-trivial SSR codebase is suspicious — re-check the patterns. False positives are acceptable when flagged as "review"; silent skips are not.

A scan that produces zero output without proving the patterns matched is a failed scan.

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

React / Next App Router specific — the detectors above are Nuxt-leaning, which is a real coverage gap, enumerated in § Detector coverage per framework below rather than left implicit. Every `"use client"` directive ships JS + hydrates from that file down.

- **Unjustified directive** — among `"use client"` files, `grep -L 'useState|useEffect|useReducer|onClick|onChange|window\.|document\.|addEventListener'` → each hit can DELETE the directive (renders server-side, 0 JS). False-positive: a `useContext`-of-client-context consumer still needs it.
- **Boundary too high** — a `"use client"` file importing large server-safe children → push the directive down to the interactive leaf; pass the subtree via the `children` prop.
- **Server-only leak (BLOCKER)** — a db/`fs`/secret module imported into a `"use client"` file → that code is now in the client bundle.

Halt: never strip a directive without the `grep -L` proving zero state/effect/event/browser usage.

## Detector coverage per framework (read before reporting a clean run)

The detectors above are **not uniformly deep across stacks**, and a clean run means different things per stack. The generic browser-API grep (`window.` / `document.` / `localStorage.` / `navigator.`) is framework-independent; everything else needs the stack's own shape. This table is the coverage claim the run must print — a scan reporting zero findings without it is asserting a pass it cannot back.

| Stack | Boundary-specific detector | The pattern that actually finds it | Coverage |
|---|---|---|---|
| **Nuxt 3** | Unkeyed `useAsyncData`; plugin module-scope side effects | `rg -n 'useAsyncData\(\s*(\(|async|function)'` (first arg is the fetcher, not a key); `rg -n 'addEventListener' plugins/` outside `defineNuxtPlugin` + `import.meta.client` | **full** |
| **Next (App Router)** | `"use client"` boundary cost, push-down, server-only leak | the three `grep -L` detectors above | **full** |
| **SvelteKit** | Universal-vs-server load. `+page.ts` runs on **both** sides; `+page.server.ts` does not — the generic grep cannot tell the two files apart. | `rg -n 'window\.|document\.|localStorage' 'src/routes/**/+page.ts' 'src/routes/**/+layout.ts'` — hits here are findings; the same hits in `+page.server.ts` are not, and in `onMount` are `dismiss` | **partial — this row only** |
| **Remix / React Router** | Route-module body vs `loader`. The `loader` is server-only; the module body and default export run on both. | `rg -n 'window\.|document\.' app/routes/` then classify by position: inside `loader`/`action` = server-only (a different bug — a browser API there throws); in the component body = the mismatch; in `useEffect` = `dismiss` | **partial — this row only** |
| **Angular (SSR)** | Double-fetch with no `TransferState`; DOM access outside `afterNextRender`. | `rg -n 'document\.|window\.' src/app/` filtered to files without `isPlatformBrowser|afterNextRender`; and `rg -L 'TransferState'` over resolvers/services that fetch on init | **partial — this row only** |
| **Astro, Solid Start, Qwik, anything else** | none written | generic grep only | **generic only** |

**Print the row you ran.** A SvelteKit scan that finds nothing reports `coverage: generic grep + SvelteKit universal-load row; no RSC/plugin detectors apply` — not "clean".

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
- Halt if the audit returns zero findings on a multi-page SSR app without listing the grep patterns actually executed **and the § Detector coverage row for the detected stack**. A clean generic-only run on a stack with no boundary-specific detector is not a pass — it is an unaudited axis, and it must say so in those words.
- Halt if a fix relies on `import.meta.client` guards being added but the guard isn't shown in the suggested patch.
