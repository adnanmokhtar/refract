---
name: lazy-loading
description: Pattern — defer loading of code, data, images, components until actually needed. Per-tier guide on what to lazy-load + what NOT to lazy-load + how to measure impact.
kind: ai-pattern
pack: performance
---

# Pattern: Lazy loading

> **Hard rule** — Lazy-load only after measuring; never lazy above-the-fold images, critical CSS, or auth checks. Every lazy primitive ships with a placeholder that preserves layout (width/height or aspect-ratio) and a documented failure fallback.

**When to apply**
- A measured chunk / module is ≥ ~50 KB and not used on the critical path.
- Below-the-fold images, off-screen videos, modal contents that aren't always opened.
- Third-party scripts (chat widget, analytics) that can wait for idle / interaction.

**When NOT to apply**
- Above-the-fold hero images — defers LCP and tanks perceived performance.
- Tiny modules (< 5 KB) — splitting overhead outweighs savings.
- Auth check / boot data — flash of unauthenticated UI is worse than the load cost.

**Halt conditions / mandatory cites**
- Cite the bundle-size measurement (`<path>` of bundle-analyzer output or `/bundle-perf` run) before proposing a split; lazy without measurement is a halt.
- Cite the placeholder component as `<path:line>` before lazy-loading any element with a layout footprint; missing width/height is a CLS halt.
- Cite the failure fallback path as `<path:line>` for any dynamic import; "module load fails, UI stuck" is forbidden.
- Cite the LCP / perf budget doc as `<path>` before deferring anything in the LCP element's tree; halt if uncited.
- Hand-wave grep ban — never claim "no lazy hero images" without citing the lint rule or grep artifact.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Stack`.
>
> - **Code splitting strategy**: `<route-based / feature-based / vendor-split>`
> - **Image lazy-load primitive**: the project's image primitive (framework's image component / native `loading="lazy"` / IntersectionObserver / a lazy-image library)
> - **Route-based code-split detected at**: `<paths>`
> - **Heavy modules deferred**: `<list>`

## When lazy is the right answer

| Tier | Examples | Strategy |
|---|---|---|
| **Routes** | Settings page, admin panel, infrequently-visited flows | Route-based code split via the framework's lazy-route primitive (every modern frontend framework has one). |
| **Heavy modules** | Charting library, rich-text editor, video player, map SDK | Dynamic import on first use; show placeholder while loading. |
| **Below-the-fold images** | Anything not visible on first paint | `loading="lazy"` (HTML), the framework's image primitive's default lazy mode, IntersectionObserver. |
| **Off-screen videos** | Tutorials, hero videos that auto-play | `preload="none"` + autoplay-on-intersection. |
| **Third-party scripts** | Chat widget, ad scripts, analytics, A/B testing | Lazy-load on user gesture or after main content interactive. |
| **Modal/drawer contents** | Account settings dialog, share sheet | Render placeholder; populate on open. |
| **Large lists** | Threads with 1000+ items, message history | Virtualization (the framework's virtualisation library). |
| **Server data not needed yet** | Tab content not currently selected | Fetch on tab activate. |

## When NOT to lazy-load

- **Above-the-fold images** — defer = layout shift + LCP regression.
- **First-paint critical CSS** — lazy CSS = FOUC (flash of unstyled content).
- **Auth check / user data** — needed before any UI; lazy = flicker through unauthenticated UI.
- **Tiny modules (<5 KB)** — splitting overhead > savings.
- **Modules that load on every route change** — they aren't actually deferred.

## Measure first

`/bundle-perf` profiles your current state. Lazy-load is a fix; measure that the thing you're deferring is actually big enough to matter.

A 200 KB lazy-load saves ~200 KB. A 5 KB lazy-load saves nothing meaningful and adds complexity.

## Per-tier patterns (stack-agnostic)

### Route-based code splitting

Use the framework's lazy-route primitive (every modern web framework has one — `lazy()` + Suspense in some, file-system route splitting in meta-frameworks, dynamic-import-style in others). Always pair with a placeholder while the route chunk loads.

Most meta-frameworks (file-system routing) split per page automatically — usually no work needed.

### Heavy module dynamic import

Defer the import until the component that uses the module mounts. Conceptually: replace a top-level static import of the heavy module with a dynamic import inside an effect / mount hook; render a placeholder until the dynamic import resolves; on resolve, render the real component.

### Image lazy-load

Use the platform's native lazy-loading attribute (`loading="lazy"` on `<img>`) for raw HTML, OR the framework's image primitive's default lazy mode. For above-the-fold images, mark them as priority (the framework's priority-hint API) so they load eagerly.

ALWAYS set `width` + `height` (or `aspect-ratio` CSS) — without them, lazy images cause layout shift (CLS regression).

### Third-party scripts

Defer third-party script tags until a user gesture (button click) OR after first idle / first interaction. The bad pattern is shipping a `<script>` tag in `<head>` that loads on every page; the good pattern is appending the `<script>` element to the DOM on demand and guarding against double-load.

For analytics: load after `requestIdleCallback` or after first interaction.

### Virtualization

Use the framework's virtualisation library (every modern frontend framework has at least one — windowed-list components for the visible viewport). Conceptually: render only the rows that fit in the visible viewport plus an over-render buffer; the underlying list metadata stays in memory. Memory + render-time both bounded.

## Anti-patterns

- **Lazy-loading hero image** — defers LCP; primary content not visible at first paint.
- **Lazy-loading without placeholder** — blank UI for milliseconds; user sees a hole.
- **Lazy-loading without `width`/`height`** — layout shift.
- **Lazy-loading critical scripts** — auth check delayed, user sees flash of public state.
- **Splitting at the wrong granularity** — 50 chunks of 5KB = many round trips, slower than 5 chunks of 50KB.
- **No fallback for lazy fail** — module load fails (network); UI stuck.
- **Re-fetch on every render** instead of caching — lazy without memo.

## Lifecycle for a lazy-loadable resource

```
1. Mark resource as deferred (lazy primitive).
2. Render a placeholder / skeleton at the visible position.
3. Trigger load on the appropriate event:
   - Route mount (route-split)
   - In-viewport (images/videos)
   - User gesture (third-party script)
   - First idle (analytics)
4. On load complete: swap placeholder → real content.
5. On load failure: show retry / fallback.
6. Measure impact: bundle-size delta + perception (Lighthouse field).
```

## Monitoring

- **Bundle size before / after** per chunk.
- **LCP shift** on key pages.
- **Lazy chunks loaded** per session — too low = users not reaching deferred content; too high = the split was useless.
- **Failed dynamic imports** — track + alert.

## Project-specific anchors

(Phase 4.6 fills this with the project's actual code-split conventions, lazy-image helper, route mapping, and recently-deferred modules.)
