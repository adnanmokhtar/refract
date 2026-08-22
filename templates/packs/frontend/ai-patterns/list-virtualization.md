---
name: list-virtualization
description: "Pattern: List Virtualization — render only the visible window (+overscan) of any collection that can exceed ~100 rows; forbids unbounded .map() over server data, with a per-framework virtualizer Adapt table and cite-or-halt detectors for CLS, keys, and a11y of windowed rows."
kind: ai-pattern
pack: frontend
---

# Pattern: List Virtualization

> **Hard rule:** Any list, table, or grid whose row count can exceed ~100 renders only the visible window plus a small overscan — never the whole array. An unbounded `.map()` over server-driven data with no windowing (or a `<table>` that mounts every row) is forbidden. This is the elaboration of the `frontend-principles` MUST "virtualize lists >100"; a violation is a bug, not a preference.

Every finding cites the offending render site at `<file:line>` + the matched pattern + the fix routed through the codebase's own virtualizer. "This list is slow" without the cited element is a vibe, not a finding.

**When to apply**
- A collection is server-driven or user-generated and its length is unbounded or can realistically exceed ~100 (feeds, search results, log/table views, message threads, autocomplete result sets).
- A `<table>`/data-grid renders every fetched row into the DOM.
- An infinite-scroll surface appends rows without ever unmounting the ones scrolled past (DOM + memory grow without bound).
- A `.map()` DOM node count is the cause of a measured INP/scroll-jank or long-task regression.

**When NOT to apply**
- A bounded small list (<~100 rows) whose max length is guaranteed by the data shape — virtualizing it adds a library, scroll math, and a11y surface for no paint win. Do not impose it.
- A server-paginated view that already ships a small page (e.g. 20–50 rows) per request — the page IS the window; add virtualization only if a single page can still blow past ~100.
- Content that MUST be fully in the DOM: SEO/crawler-indexable lists, printable documents, or anything the user finds with in-page Ctrl-F/⌘-F. State this carve-out honestly — **virtualized rows outside the window do not exist in the DOM, so they are invisible to browser find-in-page, to `Ctrl+A`/copy-all, and to crawlers.** If those matter, prefer server pagination + SSR/SSG (→ `rendering-strategy.md`) over windowing, or provide a non-virtualized print/index path.

**Halt conditions / mandatory cites**
- Halt on any virtualization finding without the render site cited at `<file:line>` + the matched pattern + the fix.
- Halt before importing a second virtualizer: if the project already uses one (TanStack Virtual, react-window, `vue-virtual-scroller`, CDK, …), route the fix through it. Detect the existing primitive first; never impose a rival library.
- A fix that windows an SEO-indexable or find-in-page-critical list MUST cite why the content is not crawler/Ctrl-F dependent, or re-scope to pagination — do not silently make content undiscoverable.
- Any variable-height fix MUST cite the measurement strategy (measured/estimated row size) — a windowed list with wrong row heights scrolls to the wrong offset.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` when claiming a list is "already virtualized" is forbidden — cite the virtualizer call site.

## What "~100" is actually a proxy for

The hard rule's threshold is a **row count**, because a row count is the only thing a reviewer can check at a glance. The cost it stands in for is **DOM nodes, and the layout and style work they force on every frame** — and rows are not interchangeable. A 3-node row (checkbox, label, badge) and a 40-node row (avatar, nested actions menu, inline chart, expandable panel) differ by more than an order of magnitude at the same count.

The number to reason about is therefore **`nodes-per-row × rows`**, against a frame budget: the browser recalculates style and layout across the whole container on scroll and on every mutation, and that work scales with the node count, not with the array length. Practical consequences of reading the rule this way:

- **A heavy row hits the ceiling far below 100.** A 40-node row at 40 rows is already 1,600 nodes — window it, and do not argue that 40 < 100.
- **A trivial row can pass well above 100** if it is genuinely 2-3 nodes, has no per-row event listener, and the container is not re-rendered on unrelated state. Say so explicitly and `dismiss`; do not add a virtualizer, a scroll-math dependency and an a11y surface to a flat list of chips.
- **Count the nodes, do not estimate them.** Open one rendered row in the element inspector and count its subtree. This is a 30-second check and it is the difference between a cited finding and a threshold applied by reflex.

`~100` remains the default and the review trigger: below it, argue from the node count to skip; above it, argue from the node count to skip. What is not acceptable is treating the number as either a law or a suggestion without ever looking at a row.

## The windowing concept

A virtualizer renders only the rows whose position intersects the scroll viewport, plus an **overscan** (a few rows above and below) so fast scrolls don't flash blank. The full collection stays in memory as data; only the visible slice becomes DOM nodes. A tall spacer (or absolutely-positioned rows inside a sized container) reserves the total scroll height so the scrollbar reflects the whole list, not just the mounted slice.

```
total rows: 10,000        mounted DOM nodes: ~visible + overscan (e.g. 20)
[····· scrolled past (data only, no DOM) ·····]
[ overscan ][ VISIBLE WINDOW ][ overscan ]   ← the only rows in the DOM
[····· not yet reached (data only, no DOM) ·····]
```

## Fixed vs variable row height

- **Fixed height** — every row is the same known height. The virtualizer computes offsets by multiplication; cheapest and jank-free. Prefer it when the design allows.
- **Variable / dynamic height** — rows differ (wrapping text, media, expandable content). The virtualizer needs an **estimate** up front and then **measures** each row after mount (`measureElement` / `ResizeObserver`), correcting the running offset. Without measurement the scrollbar and scroll-to-index land at the wrong place. Provide a sensible estimate to minimize the correction jump.

## Infinite scroll + windowing together

Infinite scroll (fetch the next page as the user nears the end) and virtualization are **complementary, not alternatives**. Infinite scroll bounds network; virtualization bounds the DOM. Do both: append fetched pages to the backing array, but let the virtualizer window it so scrolled-past rows unmount. Trigger the next fetch from the virtualizer's rendered range (e.g. when the last virtual item index nears the loaded count), not from a raw scroll listener. Appending pages to the DOM with no windowing is the classic memory-leak infinite feed.

## Stable keys

Key each row by a **stable domain id**, never the array index — with windowing the mounted set shifts constantly, and index keys make the framework reuse the wrong DOM node against the wrong data (state bleed, wrong focus, flicker). Pass the id from the virtual item's underlying datum.

## Scroll restoration & CLS-safety

- **Reserve height.** The scroll container and row estimate must reserve the list's height before data lands, so the scrollbar doesn't jump when rows populate. Give the container a fixed/`min-height` and rows an estimated size; render a skeleton at the reserved height while loading. Height that resolves late = layout shift (CLS).
- **Scroll restoration.** On back/forward or route return, restore scroll by **index/offset**, not pixel scrollTop — a windowed list's pixel height only settles as rows measure. Persist the first-visible index and scroll to it (`scrollToIndex`) after mount.

## Accessibility (WCAG 2.2 AA)

Windowing must not strip semantics from a list/grid the user navigates by keyboard or screen reader:

- Keep the correct roles: a virtualized data grid still needs `role="grid"`/`role="table"` on the container and `role="row"`/`gridcell` on rows; a virtualized listbox keeps `role="listbox"`/`option`.
- Advertise the **full** count, not the mounted count: `aria-rowcount` (grid) / `aria-setsize` + `aria-posinset` (options), because most rows aren't in the DOM. Screen readers otherwise announce "row 12 of 20" for a 10,000-row list.
- Keyboard navigation must reach rows outside the window — key handlers scroll the virtualizer to bring the target into view before focusing it.
- **Don't lose focus on unmount.** When the focused row scrolls out and unmounts, focus falls back to `<body>` and the user is stranded. Move focus to a stable ancestor (the scroll container) or keep the focused row in the overscan/rendered set until focus leaves it.

## The SEO / find-in-page tradeoff

Restated because it is the pattern's sharpest edge: rows outside the window are absent from the DOM, so `Ctrl+F`/`⌘F`, "select all → copy", and search-engine crawlers see only the mounted slice. For public indexable content or documents users search in-page, do not virtualize — server-paginate + server-render (→ `rendering-strategy.md`), or ship a separate non-virtualized print/export path. Windowing is a client-performance tool, not a content-delivery strategy.

## Adapt to the codebase

Mirror whichever virtualizer the project already imports; add one only if none exists. Never wire a second.

| Primitive | Frameworks | Fixed vs variable height |
|---|---|---|
| **TanStack Virtual** (`@tanstack/*-virtual`) | React / Vue / Svelte / Solid | Both — `estimateSize` + `measureElement` for variable |
| **react-window** | React | Fixed (`FixedSizeList`); variable via `VariableSizeList` (per-index size fn) |
| **react-virtualized** | React (legacy/heavier) | Both — `CellMeasurer` for dynamic; prefer react-window/TanStack for new code |
| **`vue-virtual-scroller`** (`RecycleScroller`/`DynamicScroller`) | Vue | `RecycleScroller` fixed; `DynamicScroller` variable |
| **VueUse `useVirtualList`** | Vue | Both — `itemHeight` as number (fixed) or fn (variable) |
| **`svelte-virtual-list`** | Svelte | Variable via measurement (fixed by estimate) |
| **Angular CDK** `cdk-virtual-scroll-viewport` | Angular | Fixed via `itemSize`; variable via custom/autosize strategy |
| **CSS `content-visibility: auto` + `contain-intrinsic-size`** | Any / progressive baseline | Both — `contain-intrinsic-size` reserves the estimated size; skips render/layout of off-screen content while keeping it in the DOM (Ctrl-F + crawlable) |

`content-visibility` is the no-library baseline: it keeps rows in the DOM (so it does NOT break find-in-page or SEO) but skips their rendering work off-screen. Reach for a JS virtualizer only when the DOM node count itself — not just rendering — is the cost.

## Detectors (cite-or-halt)

### 1. Unbounded `.map()` over server data, no virtualizer

```
BAD:  {items.map(i => <Row key={i.id} {...i} />)}   // items from a fetch, length unbounded
GOOD: {rowVirtualizer.getVirtualItems().map(v => <Row key={items[v.index].id} … />)}
```
Grep: `\.map\(` on a list backed by a fetch/query/store with no virtualizer import in the file (`grep -L "virtual\|VirtualList\|RecycleScroller\|cdk-virtual" <files with .map over server data>`). Flag when max length is unbounded.

### 2. `<table>`/data-grid mounting every row

```
BAD:  <tbody>{rows.map(r => <tr key={r.id}>…</tr>)}</tbody>   // 5k <tr> in the DOM
```
Grep: `<tbody>` / `<DataGrid` / `.map(` over `<tr>` with no row virtualization. Flag any grid whose row source can exceed ~100.

### 3. Infinite scroll appending to the DOM with no windowing

```
BAD:  onScrollEnd → setItems([...items, ...page]); {items.map(...)}   // DOM + memory grow forever
GOOD: append to backing array; virtualizer windows it; fetch next from rendered range
```
Grep: `setItems`/`push` on scroll-end near a `.map()` render with no virtualizer. Flag the ever-growing DOM.

### 4. Index-as-key (or missing key) on virtualized rows

```
BAD:  key={index}          // windowed set shifts → wrong node ↔ wrong data
GOOD: key={items[virtualItem.index].id}
```
Grep: `key={index}` / `key={i}` / `:key="index"` inside a virtualized render. Flag every instance.

### 5. No reserved height → CLS on load

```
BAD:  <div class="list">{loading ? <Spinner/> : rows…}</div>   // 0-height → content jumps in
GOOD: container min-height + estimated row size + skeleton at reserved height
```
Grep: virtualized/list container with no `height`/`min-height` and no size estimate. Flag late-resolving height.

### 6. Accessibility loss on the windowed list

```
BAD:  <div role="grid">{visible.map(...)}</div>            // aria-rowcount = mounted count, focus lost on unmount
GOOD: <div role="grid" aria-rowcount={total}> … row: aria-rowindex; keep focus on scroll container
```
Grep: virtualized `role="grid"`/`role="listbox"` with no `aria-rowcount`/`aria-setsize`, or a row focus handler with no unmount fallback. Flag missing full-count semantics and dropped focus.

### 7. `content-visibility` opportunity missed on long static content

```
GOOD: .row { content-visibility: auto; contain-intrinsic-size: 0 72px; }
```
Grep: long static, find-in-page-relevant lists (docs, comments, changelog) rendering hundreds of nodes with no `content-visibility`. Prefer this over a JS virtualizer where the content must stay crawlable/searchable.

## Closure verbs

- `report-with-fix` — cited render site + the fix routed through the project's existing virtualizer (or `content-visibility` for crawlable content).
- `halt-handoff` — SEO/find-in-page-critical content, or an ambiguous primitive: hand off to `rendering-strategy.md` (pagination + SSR) or `@ui-architect` before windowing.
- `dismiss` — a list above ~100 rows whose measured nodes-per-row keeps it under the frame budget (§ What "~100" is actually a proxy for), or a bounded list whose maximum length the data shape guarantees. Record the node count so the next scan does not re-open it.

## Related

- `rendering-strategy.md` — owns per-route initial-render + when to server-paginate crawlable/SEO content instead of windowing it.
- `data-fetching.md` — the infinite/paginated backing array comes from the query cache; each page is a cache entry, invalidation targets the root key, the virtualizer just windows it.
- `navigation-speed.md` (skill) — scroll restoration on back/forward + bfcache; restore virtualized lists by index, not pixel offset.
- `inp-responsiveness` (cross-pack, performance) — scroll jank / long tasks caused by oversized DOM; windowing is a primary lever there.
- `bundle-analyze` (skill) — accounts for the virtualizer library's own cost; don't add a second one.
- `@accessibility-auditor` — reviews `aria-rowcount`/`aria-setsize`, keyboard reach, and focus survival on virtualized rows.
- `@ui-architect` — owns the list/table/grid component shape when a shared virtualized primitive is introduced.
