---
name: navigation-speed
description: Audit page-to-page navigation speed — link/router prefetch, Speculation Rules, bfcache eligibility, instant-loading UI, full-reload regressions, View Transitions. Most of a session is navigation, not first load.
---

# navigation-speed

A real session is dominated by page-to-page navigation, not the first cold load — that's where "the app feels slow" lives. Every finding cites `<file:line>` + the matched pattern + a concrete fix + a closure verb (`report-with-fix` / `report-flagged` / `dismiss`).

## Premise

A real session is dominated by page-to-page navigation, not the first cold load. The first paint is measured to death (Lighthouse, CWV); the 2nd → 50th navigation usually isn't measured at all, and that's where "the app feels slow" actually lives. This skill audits the levers that make the NEXT page appear instantly: prefetch the route before the click, serve from bfcache on back/forward, paint a layout-stable skeleton the instant a navigation starts, and never hard-reload when a soft navigation would do.

Every finding cites `<file:line>` + the matched pattern + a concrete fix + a closure verb. "Navigation feels sluggish" without a cited link / handler / missing boundary is not a finding. A scan that returns zero findings on a multi-route app without listing the patterns it grepped is a failed scan.

**Closure verbs (one per finding):**
- `report-with-fix` — pattern matched at `<file:line>` + the concrete prefetch / boundary / `router.push` / `pagehide` patch.
- `report-flagged` — measured-relevant but the fix is an architectural call (adopt Speculation Rules host-wide, restructure a layout) → surface for ADR.
- `dismiss` — pattern matched but the carve-out applies (auth-mutating link, logout prerender, pagination tail) → documented so the next scan doesn't re-flag it.

## Scans for

### 1. Internal links that don't prefetch

```
BAD:  <a href="/products/42">View</a>          // raw anchor — no prefetch, full reload
      <NuxtLink to="/x" :prefetch="false">     // prefetch off without a reason
GOOD: <Link href="/products/42">View</Link>    // Next: auto-prefetch in-viewport (prod)
      <a href="/x" data-sveltekit-preload-data="hover">  // SvelteKit
```

Grep: raw `<a href="/` to internal routes; `prefetch=\{?false`, `:prefetch="false"`, `data-sveltekit-preload-data="off"`.

### 2. No Speculation Rules on a content/MPA surface

```
<script type="speculationrules">
{ "prerender": [{ "where": { "href_matches": "/*" }, "eagerness": "moderate" }] }
</script>
```

`eagerness`: immediate / eager / moderate / conservative. Prefer `prefetch` when prerender is too aggressive. NEVER prerender side-effecting GETs (logout/delete).

### 3. bfcache breakers

```
BAD:  addEventListener('unload', ...) / addEventListener('beforeunload', ...)
GOOD: addEventListener('pagehide', ...) / addEventListener('visibilitychange', ...)
```

`unload`/`beforeunload` is the HARD disqualifier. `Cache-Control: no-store` on documents is a **warn** (Chrome bfcache-for-CCNS, 2025), not a hard fail. Close IndexedDB / WebSocket / BroadcastChannel on `pagehide`. Cite the real reason from a Lighthouse `bf-cache` audit.

### 4. Missing instant-loading UI

App-Router segment with no `loading.tsx`; router outlet with no pending/transition branch (`useNavigation().state` / SvelteKit `navigating` store). Skeleton MUST match final dimensions (no CLS).

### 5. Full reload where a soft nav belongs

```
BAD:  window.location.href = '/dashboard';
GOOD: router.push('/dashboard');   // navigate(...) in React Router
```

### 6/7. Scroll restoration + View Transitions

`history.scrollRestoration = 'manual'` with no restore logic → flag. View Transitions (`startViewTransition`, `@view-transition { navigation: auto }`, `view-transition-name`) are a perception layer, never a prefetch substitute; gate behind `prefers-reduced-motion`.

## Prefetch primitive per framework

| Framework | Primitive | Default | Tune |
|---|---|---|---|
| Next (App Router) | `<Link>` / `useRouter().prefetch()` | in-viewport (prod) | `prefetch={false}` |
| Nuxt | `<NuxtLink>` | in-viewport | `:prefetch="false"` / `prefetchOn="interaction"` |
| SvelteKit | `data-sveltekit-preload-data` | off until set | `hover` / `tap` / `off` (+ `-code`) |
| React Router | `<Link prefetch>` | `none` | `intent` / `render` / `viewport` |
| Angular | `PreloadingStrategy` | none | `PreloadAllModules` / quicklink |

## Output

```
Navigation-speed audit — <route set>

1. components/OrderRow.vue:18                  [report-with-fix]
   Raw <a href="/orders/{{id}}"> — no prefetch, full reload.
   Fix: <RouterLink :to=...> (vue-router doesn't auto-prefetch the chunk — warm import on hover).
2. app/products/  (segment)                    [report-with-fix]
   No loading.tsx beside a route awaiting a slow fetch. Fix: add a dimension-matched skeleton + <Suspense>.
3. lib/analytics.ts:44                          [report-with-fix]
   addEventListener('unload', flush) — HARD bfcache disqualifier. Fix: 'pagehide' + sendBeacon.
```

## Halt conditions

- Every prefetch / bfcache / reload / loading-UI finding cites `<file:line>` + matched pattern + fix.
- bfcache-ineligible claims need the grepped `unload` line OR a Lighthouse `bf-cache` reason.
- Speculation Rules proposals must exclude side-effecting GETs.
- Instant-loading fixes use a dimension-matched skeleton, not a spinner / unsized box.
