---
name: render-discipline
description: Render Discipline (rebuild / re-render waste)
kind: rule
pack: mobile
severity: must
applies-to: mobile-track, every-code-writing-task-in-mobile
---

# Render Discipline (rebuild / re-render waste)

> **Hard rule.** Build / render functions MUST be pure and cheap — no I/O, no state mutation, no allocation-heavy work inside `build()` / `render` / `body` / a Composable. State mutations MUST be scoped to the smallest subtree that displays them. Long lists MUST be virtualized. A rebuild-waste fix MUST ship with a before/after rebuild-count or frame-time measurement — "feels faster" is not evidence.

Prevents the failure that benchmark suites don't catch and code review skims past: **the code works, every test passes, and the UI rebuilds 40× more than it needs to.** Canonical incident shape (the one AI-generated code reproduces constantly): a fetch + `setState` written at screen root — works on first run, rebuilds the entire screen per keystroke, mixes data logic into the view, and handles no error state. Each of those is a separate detector below.

## The 8 detectors

Each detector is shape-based; the concrete fingerprint per framework lives in that framework's reference (see below). `/optimize` (Performance class) and `/audit` (runtime-perf axis) route here when `PROJECT_KIND in mobile-*`; web frontends get the equivalent fingerprints from the frontend pack.

| # | Detector | Signal | Closure verb |
|---|---|---|---|
| 1 | **oversized-state-scope** | state mutation at screen/page root re-rendering the whole subtree when only a leaf displays the value | `scope-state-down` (move state to the lowest common displayer; split the widget/component) |
| 2 | **side-effect-in-build** | fetch / mutation / navigation / subscription started inside the build/render body (re-fires per rebuild) | `move-to-lifecycle` (move to the project's init/effect hook named in `_extracted-idioms.md`) |
| 3 | **missing-stable-subtree** | static subtree rebuilt because it isn't marked constant / memoized / stable | `extract-const-subtree` (const constructor / memo / stable annotation per stack) |
| 4 | **unstable-list-item-props** | new closure / style object / callback allocated per item per render in a list hot path | `memoize` (hoist or memoize the allocation; stable keys) |
| 5 | **unvirtualized-list** | unbounded children list built eagerly where a lazy/recycling primitive exists | `virtualize-list` |
| 6 | **animation-rebuilds-subtree** | animation ticker invalidating the full tree instead of a scoped animated child | `scope-animation` |
| 7 | **store-overinvalidation** | widget/component subscribes to a whole store/provider object but reads one field — every unrelated store write re-renders it | `select-store-slice` (use the store's selector/select primitive from `_extracted-idioms.md`) |
| 8 | **logic-in-view** | business rules / data transformation / error mapping written in the widget/screen body instead of the project's state/service layer | route to `/align` (layer violation) — this is an architecture finding wearing a perf costume |

## Where the fingerprint lives

The detectors above are shape-based on purpose: the *concrete* fingerprint is per-framework, and a
project is exactly one framework. Each framework's fingerprint table and its lint / profiler
enforcement live in that framework's reference, which `phase-4.2-apply.md` copies only for the
framework it detected:

`references/flutter.md` · `references/react-native.md` · `references/jetpack-compose.md` ·
`references/swiftui.md` — each § Render-discipline fingerprints, one row per detector above.

Cite the detector **number and name** from this rule; take the signal you match against from the
reference. A finding that names a framework API but no detector is not in this vocabulary.

## Must

- **Measure before and after.** Rebuild counts (Flutter DevTools "Track widget rebuilds"), re-render counts (React DevTools Profiler), recomposition counts (Compose compiler metrics / Layout Inspector), body re-evals (Instruments / `Self._printChanges()`). A render-waste fix without a measured delta is rejected — same rule as every other perf finding (baseline + post-fix in the commit).
- **Scope state to the smallest displayer.** Before adding state to a screen root, name the lowest widget/component that displays it; put the state there.
- **Keep build/render pure.** Data fetching, subscriptions, navigation, and mutations live in the project's lifecycle/effect primitive (named in `_extracted-idioms.md`), never in the build path.
- **Virtualize every unbounded list.** "It's only ~30 items today" is how 3-second jank ships at 300.
- **Stable identities in list hot paths.** Stable keys, hoisted callbacks, hoisted style objects — allocation per item per frame is the jank floor.
- **Route logic-in-view findings to the state layer.** The fix for detector #8 is architectural (move the logic), not memoization. Memoizing a component that shouldn't hold the logic preserves the layer violation.

## Must not

- **Memoize everything defensively.** Blanket `React.memo` / `useCallback` / `remember` on cold paths adds comparison cost + complexity with no measured win — over-memoization is itself a finding (`/optimize` over-abstraction class). Memoize where the profiler shows waste.
- **Treat "works at 60fps on the dev flagship" as proof.** Budget against the lowest-spec device in the install base (per `mobile-principles.md`).
- **Fix rebuild waste by caching incorrect state.** If the subtree rebuilds because the state model is wrong (detector #1/#7), restructure the state — don't paper over it with memo.
- **Ship a render fix that changes behaviour.** Scoping state down / memoizing must be observably identical (same UI states, same error/empty/loading paths). If the fix reveals a missing error state, that's a separate finding (`missing UI state` — align pack), fixed in its own commit.

## Enforcement

- The lint rules, compiler metrics and profiler template that enforce these detectors are per-framework and live in that framework's reference § Render-discipline fingerprints, beside the fingerprint they enforce.
- `/optimize` + `/audit` dispatch these detectors under the Performance class when `PROJECT_KIND in mobile-*`; findings carry `<path:line>` evidence + measured baseline like every perf row.

## Cross-references

- `mobile-principles.md` — UI-thread blocking, low-end-device budgets (the runtime siblings of this rule).
- `references/<framework>.md` § Render-discipline fingerprints — the concrete signal per detector, plus its lint / profiler enforcement.
- `frontend/rules/frontend-principles.md` — web equivalent (render thrash / memoization fingerprints for `frontend-*`).
- `performance/rules/performance-principles.md` — the measure-before-optimize contract this rule inherits.
