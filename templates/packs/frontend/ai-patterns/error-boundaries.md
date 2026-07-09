---
name: error-boundaries
description: "Pattern: client-side error boundaries — contain a component/subtree failure with fallback UI, retry/reset, and error reporting so one broken widget can't white-screen the whole app"
kind: ai-pattern
pack: frontend
---

# Pattern: Error Boundaries

> **Hard rule:** Every route root AND every independently-failing feature subtree (a widget, a lazy-loaded island, a third-party embed) is wrapped by an error boundary that renders a real fallback UI and calls a report hook. An unbounded subtree whose throw white-screens the entire app is forbidden. A boundary claim without the cited wrapping component + fallback + report call at `<path:line>` is a vibe, not a finding.

**When to apply**
- A new route root is added — it needs a last-resort boundary so a render throw degrades to a page-level fallback, never a blank document.
- A feature subtree can fail on its own: a dashboard widget, a lazy-loaded island, a chart, a third-party embed (maps, payments, analytics widgets), or any subtree fed by an independent query.
- A hydration mismatch or a lazy-chunk load failure is white-screening the app instead of degrading locally.

**When NOT to apply**
- A throwaway prototype or an internal admin tool where a crash-to-blank is acceptable and reporting is out of scope — document and move on.
- A leaf that has no independent failure surface (pure presentational markup, no data, no third-party code) — wrapping every `<div>` is boundary noise; wrap at the failure seam, not below it.

**Halt conditions / mandatory cites**
- Any "this subtree is covered" claim MUST cite the boundary component + its `fallback`/error UI + the report call at `<path:line>`. No citation → not covered.
- Any fallback MUST cite its recover action (retry/reset handler) at `<path:line>`; a fallback that is a dead end is a bug — reject.
- Any boundary that catches and returns without reporting MUST cite where the error reaches the project's error sink, or halt — a swallowed error is worse than a crash.
- A doc that relies on a render boundary to catch an async error (promise rejection, `fetch().catch`, event handler, `setTimeout`) is a bug — reject; cite the async catch surface instead.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when classifying what a subtree is protected by — re-enumerate each boundary.
- If the project's boundary primitive and error sink aren't extracted, halt — mirror what exists; never impose a second boundary library or a second reporting SDK.

## The catch surface (the nuance that breaks people)

**A render boundary only catches errors thrown during the render/reconciliation phase of its descendants.** These escape it and must be handled where they happen:

- Rejected promises / `fetch().catch` — surface the error into render state so the boundary (or an inline error branch) can see it.
- Event handlers (`onClick`, `onSubmit`) — throws here never reach a render boundary; handle inline or re-throw into state.
- `setTimeout` / `requestAnimationFrame` / microtasks — detached from the render tree entirely.
- Errors thrown by the boundary's own fallback — most implementations do not self-catch; keep fallbacks trivial and side-effect-free.

Each framework's boundary has a **different catch surface** — state it per framework (see Adapt). The async gap is closed globally by `window.onerror` + `window.onunhandledrejection`, which is the net, not the boundary.

## Granularity — where the seam goes

- **App-root boundary** = last resort. It should almost never be the fallback the user sees; if it fires, one small failure took the whole page.
- **Per-route boundary** = the page shell degrades but the app chrome (nav, header) survives.
- **Per-widget boundary** = the failing widget shows its own fallback and the rest of the route keeps working.

A boundary placed **too high** turns a one-widget failure into a whole-page fallback. A boundary placed at every leaf is noise. Wrap at the independent-failure seam: the smallest subtree that can fail without the rest needing to fail.

## Fallback UX

- Show a **recover action** — a retry/reset that re-mounts the subtree and re-runs its data fetch, not a static "Something went wrong."
- **Preserve the surrounding UI** — a widget fallback must not blank sibling widgets or the route chrome.
- **Don't trap the user** — offer a way forward (retry, go back, reload the section). A dead-end fallback is a defect.
- Keep the fallback dependency-light — it renders precisely when the normal path is broken.

## Reset / retry semantics

A boundary latches into its error state and stays there until reset. Two reset mechanisms:

- **Explicit reset** — the fallback's action calls the boundary's `reset` (re-mount the subtree, then re-fetch).
- **Reset keys** — the boundary auto-resets when a declared key changes (route param, query id), so navigating away clears a stale error without a manual click.

Reset alone re-mounts; it does not re-run a fetch unless the subtree refetches on mount — pair the reset with the data layer's refetch/invalidate.

## Reporting — never swallow

Every boundary reports to the project's **existing** error-tracking sink (Sentry, Rollbar, Bugsnag, a custom logger) with **component + route context** (which boundary, which route, the component stack / error info). A boundary that catches and renders a fallback without reporting hides a real defect from telemetry — that is worse than the crash, because now nobody knows. Mirror the one sink the project already wires; do not add a second SDK.

## Boundary vs inline error (ownership)

A failed data query can surface two ways — decide ownership explicitly:

- **Inline error state** — the component owns `{ loading, error, data }` and renders an in-place error branch (retry button inside the card). Use when the failure is expected and local (a search returned an error) and the surrounding widget should stay intact.
- **Throw to boundary** — the query throws (or the component re-throws its `error`) and the nearest boundary renders the fallback. Use for unexpected failures where the whole subtree is meaningless without the data.

Pick one per subtree. A subtree that both renders an inline error AND is caught by a boundary double-reports. Data-flow ownership is refereed by **@data-flow-auditor**.

## Pairing with Suspense

The loading axis (Suspense / async boundary) and the error axis are siblings, not the same thing: Suspense shows the pending fallback, the error boundary shows the failed fallback. A lazy subtree needs **both** — a Suspense fallback for the chunk loading and an error boundary for the chunk **failing to load** (offline, deploy skew, 404'd hashed chunk). A lazy import with a Suspense fallback but no error boundary white-screens on a chunk-load rejection.

## SSR / hydration errors are a distinct class

A hydration mismatch is not a normal render throw — the server HTML and first client render disagree, and frameworks may discard the mismatched subtree or throw during hydration. A render boundary catches the client-side throw, but the root cause is upstream (non-deterministic render, browser API in render). Fix the mismatch at the source; the boundary is the containment, not the cure. See **ssr-safety.md**.

## Adapt to the codebase

Detect the project's boundary primitive and error sink first; route every fix through them. Catch surface and reset differ per framework:

| Stack | Boundary primitive | Catches async? | Reset mechanism |
|---|---|---|---|
| **React** | `class ErrorBoundary` (`getDerivedStateFromError` + `componentDidCatch`) or `react-error-boundary` `<ErrorBoundary fallbackRender onReset resetKeys>` | No — render phase only | `reset()` from `onReset`, or `resetKeys` change |
| **Vue** | `onErrorCaptured(hook)` in an ancestor + app-level `app.config.errorHandler` + router error pages | Captures descendant render + some lifecycle errors; not detached async | Re-render via a reactive key / `v-if` toggle |
| **SvelteKit** | `+error.svelte` (route-level) / Svelte 5 `<svelte:boundary onerror>` | No — render/effect phase | Re-navigate / `invalidate`, or boundary re-render |
| **Angular** | `ErrorHandler` provider (global) + per-route/component handling | `ErrorHandler` also catches many async errors via Zone.js | Re-navigate / re-instantiate the component |
| **SolidJS** | `<ErrorBoundary fallback={(err, reset) => …}>` | No — render phase only | `reset()` passed to the fallback |
| **Global net (all)** | `window.onerror` + `window.onunhandledrejection` → forward to the error sink | Yes — this is the async gap closer | N/A (last-resort logging, not UI reset) |

## Detectors (cite-or-halt)

1. **Route/app root with no boundary.**
   - BAD: a route component / root layout mounts children directly with no boundary wrapper anywhere above them.
   - GOOD: the route root is wrapped in the project's boundary with a fallback + report hook.
   - grep: `rg -n "createRoot|<RouterProvider|export default function.*Layout|\+layout\.|app\.mount" src` then verify a boundary sits above each root.

2. **Lazy / Suspense subtree or third-party embed with no boundary.**
   - BAD: `const Chart = lazy(() => import('./Chart'))` rendered under `<Suspense>` but with no error boundary; or a `<script>`-backed embed / iframe widget with no wrapper.
   - GOOD: the lazy/embed subtree is wrapped in a boundary (chunk-load failure → local fallback).
   - grep: `rg -n "lazy\(|defineAsyncComponent|import\(|dangerouslySetInnerHTML|<iframe" src` then check for an enclosing boundary.

3. **Fallback with no retry/reset (dead end).**
   - BAD: `fallback={<p>Something went wrong</p>}` — static, no way forward.
   - GOOD: `fallbackRender={({ resetErrorBoundary }) => <Error onRetry={resetErrorBoundary} />}`.
   - grep: `rg -n "fallback=|\+error\.svelte|Something went wrong" src` then confirm a reset/retry handler is wired.

4. **Boundary that swallows without reporting.**
   - BAD: `componentDidCatch() {}` / `onErrorCaptured(() => false)` with no call to the error sink.
   - GOOD: the catch calls `captureException(error, { extra: { componentStack, route } })` (project's sink).
   - grep: `rg -n "componentDidCatch|onErrorCaptured|onError=|errorHandler" src` then confirm each reaches the sink.

5. **Render boundary relied on to catch an async error (the classic mistake).**
   - BAD: an `onClick`/`fetch().then` throw expected to be caught by an ancestor `<ErrorBoundary>`.
   - GOOD: async failure is caught locally and surfaced into render state (or re-thrown on the next render) so the boundary can see it.
   - grep: `rg -n "onClick=|onSubmit=|setTimeout\(|\.then\(|await fetch" src` in files whose only error handling is an ancestor boundary.

6. **No global `onunhandledrejection` handler.**
   - BAD: no `window.addEventListener('unhandledrejection', …)` and no framework-global error handler forwarding to the sink.
   - GOOD: a global net forwards `error` + `unhandledrejection` to the same sink.
   - grep: `rg -n "unhandledrejection|window.onerror|addEventListener\(['\"]error" src`.

7. **Boundary placed too high (whole page fallback for one widget).**
   - BAD: a single app-root boundary is the only boundary; any widget throw blanks the whole page.
   - GOOD: per-widget/per-route boundaries contain the failure to its subtree; the root boundary is last resort only.
   - grep: count boundaries vs independent-failure seams — `rg -c "ErrorBoundary|onErrorCaptured|svelte:boundary" src`; a single hit across a multi-widget app is the smell.

## Closure verbs

- `report-with-fix` — cite the unbounded subtree at `<path:line>` and the boundary + fallback + report call to add, in the project's own primitive and sink.
- `halt-handoff` — when the project's boundary primitive or error sink isn't identified, or when the fix is an async/hydration root cause owned elsewhere, halt and hand off by name.

## Related

- `ssr-safety.md` — hydration mismatch is a distinct error class; fix at source, boundary contains.
- `data-fetching.md` — ownership split: a thrown query error surfaces to this boundary; an inline `{error}` branch stays in the component. Pick one per subtree.
- `code-splitting.md` — a lazy chunk-load failure (offline / deploy skew / 404'd hashed chunk) is caught here; every dynamic import pairs a Suspense fallback with this boundary.
- `bundle-analyze.md` / `navigation-speed.md` — lazy chunk-load failures that a boundary must catch.
- `@data-flow-auditor` — referees query-error ownership (throw-to-boundary vs inline error state).
- cross-pack `observability` / error-tracking — the single error sink every boundary reports to; mirror it, never add a second.
