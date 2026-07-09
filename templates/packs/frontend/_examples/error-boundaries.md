---
name: error-boundaries
kind: example
pack: frontend
---

# Pattern: Error Boundaries

> **Hard rule:** Every route root AND every independently-failing feature subtree (a widget, a lazy island, a third-party embed) is wrapped by an error boundary that renders a real fallback UI and calls a report hook. An unbounded subtree whose throw white-screens the whole app is forbidden. A boundary claim without the cited wrapping component + fallback + report call at `<path:line>` is a vibe, not a finding.

## The catch surface (the nuance that breaks people)

**A render boundary only catches errors thrown during render/reconciliation of its descendants.** These escape it and must be handled where they happen: rejected promises / `fetch().catch`, event handlers (`onClick`/`onSubmit`), `setTimeout`/rAF/microtasks, and throws in the boundary's own fallback. Surface async failures into render state so the boundary (or an inline branch) can see them. The async gap is closed globally by `window.onerror` + `window.onunhandledrejection` — that is the net, not the boundary.

## Granularity, fallback, reset, reporting

- **Seam placement** — app-root boundary = last resort; per-route = page shell degrades, chrome survives; per-widget = the failing widget shows its own fallback. Wrap at the smallest subtree that can fail without the rest failing. Too high = one widget blanks the page; every leaf = noise.
- **Fallback** — must offer a recover action (retry/reset that re-mounts + refetches), preserve surrounding UI, never dead-end.
- **Reset** — explicit `reset()` or `resetKeys` that auto-reset on a route/id change; reset re-mounts but doesn't refetch unless the subtree refetches on mount.
- **Reporting** — every catch reaches the project's existing error sink with component + route context. Catch-and-swallow-without-report hides a defect from telemetry — worse than the crash.

## Adapt to the codebase

Detect the boundary primitive + error sink first; catch surface and reset differ per framework.

| Stack | Boundary primitive | Catches async? | Reset |
|---|---|---|---|
| **React** | `class ErrorBoundary` / `react-error-boundary` | No — render phase only | `reset()` / `resetKeys` |
| **Vue** | `onErrorCaptured` + `app.config.errorHandler` | descendant render + some lifecycle | reactive key / `v-if` |
| **SvelteKit** | `+error.svelte` / `<svelte:boundary onerror>` | No — render/effect | re-navigate / `invalidate` |
| **Angular** | `ErrorHandler` provider | many async via Zone.js | re-navigate |
| **Global net (all)** | `window.onerror` + `onunhandledrejection` → sink | Yes — the async gap closer | N/A |

## Detectors (cite-or-halt)

1. **Route/app root with no boundary** — a render throw white-screens the document.
2. **Lazy/Suspense subtree or third-party embed with no boundary** — chunk-load failure → white screen.
3. **Fallback with no retry/reset (dead end)** — static "Something went wrong".
4. **Boundary that swallows without reporting** — no call to the error sink.
5. **Render boundary relied on to catch an async error** (the classic mistake) — `onClick`/`fetch().then` throw won't reach it.

## Related

- `ssr-safety.md` — hydration mismatch is a distinct error class; fix at source, boundary contains.
- `data-fetching.md` — ownership split: a thrown query error surfaces here vs an inline `{error}` branch. Pick one per subtree.
- `code-splitting.md` — a lazy chunk-load failure is caught here; every dynamic import pairs a Suspense fallback with this boundary.
- `@data-flow-auditor` — referees query-error ownership (throw-to-boundary vs inline).
- cross-pack `observability` / error-tracking — the single sink every boundary reports to; never add a second.
