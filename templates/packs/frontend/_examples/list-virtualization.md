---
name: list-virtualization
kind: example
pack: frontend
---

# Pattern: List Virtualization

> **Hard rule:** Any list, table, or grid whose row count can exceed ~100 renders only the visible window plus a small overscan — never the whole array. An unbounded `.map()` over server-driven data with no windowing (or a `<table>` mounting every row) is forbidden. This is the elaboration of the `frontend-principles` MUST "virtualize lists >100"; a violation is a bug, not a preference.

Every finding cites the render site at `<file:line>` + the matched pattern + the fix routed through the codebase's own virtualizer.

## The windowing concept

A virtualizer renders only the rows intersecting the viewport plus an **overscan**; the full collection stays in memory as data, only the visible slice becomes DOM nodes. A sized spacer reserves total scroll height so the scrollbar reflects the whole list.

- **Fixed height** — offsets by multiplication; cheapest, jank-free. Prefer it.
- **Variable height** — needs an up-front estimate then `measureElement`/`ResizeObserver` correction, or the scrollbar and scroll-to-index land wrong.
- **Infinite scroll + windowing are complementary** — infinite scroll bounds network, windowing bounds the DOM; do both. Trigger the next fetch from the virtualizer's rendered range, not a raw scroll listener.
- **Stable keys** — key by domain id, never array index; windowing shifts the mounted set constantly.

## The SEO / find-in-page tradeoff

Rows outside the window aren't in the DOM, so `Ctrl+F`/`⌘F`, select-all-copy, and crawlers see only the mounted slice. For public indexable content, server-paginate + server-render (→ `rendering-strategy.md`) or ship a non-virtualized print/export path — don't silently make content undiscoverable.

## Adapt to the codebase

Mirror whichever virtualizer the project imports; never wire a second.

| Primitive | Frameworks | Height |
|---|---|---|
| **TanStack Virtual** | React/Vue/Svelte/Solid | both (`estimateSize` + `measureElement`) |
| **react-window** | React | fixed; variable via `VariableSizeList` |
| **`vue-virtual-scroller`** | Vue | `RecycleScroller` fixed / `DynamicScroller` variable |
| **Angular CDK** `cdk-virtual-scroll-viewport` | Angular | fixed via `itemSize`; variable via strategy |
| **CSS `content-visibility: auto`** | any | no-library baseline — keeps rows in DOM (crawlable) but skips off-screen render |

## Detectors (cite-or-halt)

1. **Unbounded `.map()` over server data, no virtualizer** — flag when max length is unbounded.
2. **`<table>`/data-grid mounting every row** — 5k `<tr>` in the DOM.
3. **Infinite scroll appending to the DOM with no windowing** — DOM + memory grow forever.
4. **Index-as-key on virtualized rows** — shifting window reuses wrong node ↔ wrong data.
5. **No reserved height → CLS on load**; and a11y loss (`aria-rowcount` = mounted count, focus lost on unmount).

## Related

- `rendering-strategy.md` — owns per-route initial-render + when to server-paginate crawlable content instead of windowing.
- `data-fetching.md` — the paginated/infinite backing array comes from the query cache; the virtualizer just windows it.
- `navigation-speed.md` (skill) — restore a windowed list by index, not pixel offset, on back/forward.
- `@accessibility-auditor` — reviews `aria-rowcount`/`aria-setsize`, keyboard reach, focus survival.
