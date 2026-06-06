---
name: render-discipline
description: Render Discipline (rebuild / re-render waste)
kind: rule
pack: mobile
---

# Render Discipline (rebuild / re-render waste)

> **Hard rule.** Build / render functions MUST be pure and cheap — no I/O, no state mutation, no allocation-heavy work inside `build()` / `render` / `body` / a Composable. State mutations MUST be scoped to the smallest subtree that displays them. Long lists MUST be virtualized. A rebuild-waste fix MUST ship with a before/after rebuild-count or frame-time measurement — "feels faster" is not evidence.

Prevents the failure that benchmark suites don't catch and code review skims past: **the code works, every test passes, and the UI rebuilds 40× more than it needs to.** Canonical incident shape (the one AI-generated code reproduces constantly): a fetch + `setState` written at screen root — works on first run, rebuilds the entire screen per keystroke, mixes data logic into the view, and handles no error state. Each of those is a separate detector below.

## The 8 detectors

Each detector is shape-based; the concrete fingerprint per framework is in the table that follows. `/optimize` (Performance class) and `/audit` (runtime-perf axis) route here when `PROJECT_KIND in mobile-*`; web frontends get the equivalent fingerprints from the frontend pack.

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

## Per-framework fingerprints

| Detector | Flutter | React Native | Jetpack Compose | SwiftUI |
|---|---|---|---|---|
| oversized-state-scope | `setState` in a `StatefulWidget` ≥ ~200 LOC or screen root; state displayed only by a leaf | `useState` in screen component passed N levels down; context value rebuilt per render | `mutableStateOf` hoisted above the lowest reader | `@State` / `@StateObject` on a container view feeding one leaf |
| side-effect-in-build | `fetch` / `Provider.of(listen:)` mutation / `Navigator.push` inside `build()` | fetch or `setState` call in render body (outside `useEffect`) | suspend call / mutation outside `LaunchedEffect` / `remember` | network call / mutation inside `body` |
| missing-stable-subtree | missing `const` constructors (`prefer_const_constructors`) | missing `React.memo` / `useMemo` on a pure hot child | unstable parameter types defeating skipping (Compose compiler metrics) | non-`Equatable` model forcing body re-eval |
| unstable-list-item-props | closure built per item in `itemBuilder` capturing parent state | inline `renderItem={() => …}` + inline style literals in `FlatList` | non-`remember`ed lambda per item in `LazyColumn` | per-row closure capturing the whole parent |
| unvirtualized-list | `ListView(children: […])` / `Column` + `map` for unbounded data → `ListView.builder` | `ScrollView` + `.map()` → `FlatList`/`SectionList` (+ `getItemLayout`, stable `keyExtractor`) | `Column` + `forEach` → `LazyColumn` | `VStack` + `ForEach` over unbounded data inside `ScrollView` → `List` / `LazyVStack` |
| animation-rebuilds-subtree | `AnimationController` + `setState` per tick → `AnimatedBuilder`/`AnimatedWidget` with scoped `child:` | JS-driven animation per frame → `useNativeDriver: true` / Reanimated worklet | animating via recomposition instead of `graphicsLayer` / `animate*AsState` | timer-driven `@State` per frame instead of `withAnimation` / `TimelineView` |
| store-overinvalidation | `ref.watch(provider)` for one field → `ref.watch(provider.select(…))`; `context.watch<T>()` for one getter | `useSelector(s => s)` / whole-context consumer → narrow selector | collecting a whole `StateFlow` object where `map`/`distinctUntilChanged` slice exists | observing a whole `ObservableObject` where one `@Published` field is read |
| logic-in-view | parsing/error-mapping/business rules in `build()` instead of the project's controller/notifier/bloc | same, instead of the hook/service layer | same, instead of the ViewModel | same, instead of the ViewModel/Store |

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

## Review checklist

- [ ] No fetch / mutation / navigation / subscription in any build/render body.
- [ ] New state declared at the lowest displaying widget/component, not the screen root.
- [ ] Static subtrees marked const / memo / stable per the framework column above.
- [ ] Lists over unbounded data use the lazy/recycling primitive; stable keys; no per-item inline closures or style literals.
- [ ] Animations drive a scoped child, not the whole tree.
- [ ] Store subscriptions use the narrowest selector available.
- [ ] Rebuild/recomposition count measured before + after for every fix in this class.
- [ ] Business logic stayed in (or moved to) the state layer — none added to the view.

## Enforcement

- **Flutter**: `flutter_lints` with `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, `avoid_unnecessary_containers`; DevTools rebuild stats in PR evidence for hot screens.
- **React Native**: `eslint-plugin-react-hooks` (exhaustive-deps), `eslint-plugin-react-perf` (`jsx-no-new-object-as-prop`, `jsx-no-new-function-as-prop`); React DevTools Profiler flamegraph for hot lists.
- **Compose**: Compose compiler metrics (`reportsDestination`) in CI — restartable/skippable ratio must not regress on touched files.
- **SwiftUI**: `Self._printChanges()` audit on hot views during review; Instruments "SwiftUI" template for frame-time evidence.
- `/optimize` + `/audit` dispatch these detectors under the Performance class when `PROJECT_KIND in mobile-*`; findings carry `<path:line>` evidence + measured baseline like every perf row.

## Cross-references

- `mobile-principles.md` — UI-thread blocking, low-end-device budgets (the runtime siblings of this rule).
- `references/flutter.md` / `references/react-native.md` — framework guidance these fingerprints were promoted from.
- `frontend/rules/frontend-principles.md` — web equivalent (render thrash / memoization fingerprints for `frontend-*`).
- `performance/rules/performance-principles.md` — the measure-before-optimize contract this rule inherits.
