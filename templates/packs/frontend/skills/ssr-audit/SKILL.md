---
name: ssr-audit
description: Static scan for hydration-mismatch sources in SSR apps (Nuxt / Next / SvelteKit) — catches the bug before runtime. Run before merging an SSR-related PR and after adding a plugin or composable that touches browser APIs. Correctness only — `streaming-ssr` is the sibling that makes a correct SSR render fast.
allowed-tools: [Read, Grep, Glob, Bash]
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

React / Next App Router specific — the detectors above this point are Nuxt-leaning, which is a real coverage gap and is enumerated in § Detector coverage per framework below rather than left implicit. Every `"use client"` directive marks a hydration boundary — everything from that file down ships JS and hydrates. An unjustified directive is wasted client-JS.

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

## Detector coverage per framework (read before reporting a clean run)

The detectors above are **not uniformly deep across the Adapt table**, and a clean run means different things per stack. The generic browser-API grep (`window.` / `document.` / `localStorage.` / `navigator.`) is framework-independent and applies everywhere; everything else needs the stack's own shape. This table is the coverage claim the run must print — a scan that reports zero findings without it is asserting a pass it cannot back.

| Stack | Boundary-specific detector | The pattern that actually finds it | Coverage |
|---|---|---|---|
| **Nuxt 3** | Unkeyed `useAsyncData`; plugin module-scope side effects | `rg -n 'useAsyncData\(\s*(\(|async\|function)'` (first arg is the fetcher, not a key); `rg -n 'addEventListener' plugins/` outside `defineNuxtPlugin` + `import.meta.client` | **full** |
| **Next (App Router)** | `"use client"` boundary cost, push-down, server-only leak | the three `grep -L` detectors above | **full** |
| **SvelteKit** | Universal-vs-server load. `+page.ts` runs on **both** sides; `+page.server.ts` does not. A browser API or a per-request secret in `+page.ts` is the mismatch, and the generic grep cannot tell the two files apart. | `rg -n 'window\.\|document\.\|localStorage' 'src/routes/**/+page.ts' 'src/routes/**/+layout.ts'` — hits here are findings; the same hits in `+page.server.ts` are not, and in `onMount` are `dismiss` | **partial — this row only** |
| **Remix / React Router** | Route-module body vs `loader`. The `loader` is server-only; the module body and the default export run on both. | `rg -n 'window\.\|document\.' app/routes/` then classify by position: inside `loader`/`action` = server-only (different bug, a browser API there throws); inside the component body = the mismatch; inside `useEffect` = `dismiss` | **partial — this row only** |
| **Angular (SSR)** | Double-fetch with no `TransferState`; DOM access outside `afterNextRender`. | `rg -n 'document\.\|window\.' src/app/` filtered to files without `isPlatformBrowser\|afterNextRender`; and `rg -L 'TransferState' ` over resolvers/services that fetch on init | **partial — this row only** |
| **Astro, Solid Start, Qwik, anything else** | none written | generic grep only | **generic only** |

**Print the row you ran.** A SvelteKit scan that finds nothing reports `coverage: generic grep + SvelteKit universal-load row; no RSC/plugin detectors apply` — not "clean". The § Halt conditions already require listing the patterns executed; this table is what makes that list interpretable rather than a wall of regexes.

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

## False positives / gotchas

- **Static only — this scan never runs the app.** It is fast and complete in seconds, and it can only see what the source says, not what the runtime does. A clean scan is not a hydration guarantee; pair it with a real render (`visual-check` / a Playwright hydration check) for ground truth.
- **Browser API inside a client-only lifecycle is correct, not a finding** — `document.createElement` inside a Vue / Nuxt `onMounted`, a React `useEffect`, or an Angular `afterNextRender` runs only on the client by construction. Flagging it re-teaches the author a rule they already followed; the verdict must say why it was dismissed.
- **A guard outside render is the fix, a guard inside render is the bug.** `typeof window !== 'undefined'` in an effect or an event handler is fine. The same expression branching the returned markup produces two different trees and is exactly the mismatch this scan hunts.
- **Deliberate mismatch suppression exists.** A timestamp or locale-formatted value annotated with the framework's suppression primitive is a decision, not a defect — but only where the value is genuinely unknowable on one side. Suppression used to silence a real divergence is a finding, not a carve-out.
- **Static export changes the rules** — when the "server" is the build, per-request values (cookies, headers, geo) are not available at all, and the correct fix is a different one. Extract the rendering mode before grading.

## When to run

- Before every SSR-related PR merge.
- Weekly via CI scheduled job.
- After adding a plugin / composable that touches browser APIs.

## Halt conditions

- Halt on hand-waves: every finding must cite `<file:line>` + the pattern matched + a concrete fix. "Might cause hydration issues" without a line is not a finding.
- Halt if a finding is dismissed without verification — `document.createElement` inside `onMounted` is fine, but the verdict must say so explicitly.
- Halt if the audit returns zero findings on a multi-page SSR app without listing the grep patterns actually executed **and the § Detector coverage row for the detected stack**. A clean generic-only run on a stack with no boundary-specific detector is not a pass — it is an unaudited axis, and it must say so in those words.
- Halt if a fix relies on `import.meta.client` guards being added but the guard isn't shown in the suggested patch.

## Related

- `streaming-ssr` — the speed sibling. This skill asks "does the server render match the client?"; that one asks "why is the first byte late?". A route can pass one and fail the other.
- `ssr-safety.md` (ai-pattern) — the depth behind these greps: the per-framework client-guard primitive, the detector list, and the closure verbs. Fix wording comes from there; this skill is the sweep.
- `visual-check` — the runtime counterpart: a hydration failure that this static scan cannot see usually shows up as a blank or duplicated region in a real render.
- `navigation-speed` — owns the bfcache / `unload` half of the note above; hand those findings there rather than restating them.
- `error-boundaries.md` (ai-pattern) — a hydration throw surfaces through a boundary; the boundary contains it, it never fixes the cause.
- `.claude/rules/frontend-principles.md` — the SSR-safety MUSTs this scan enforces.
