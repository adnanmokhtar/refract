---
name: lazy-loading
description: Pattern — defer loading of code, data, images, components until actually needed. Per-tier guide on what to lazy-load + what NOT to lazy-load + how to measure impact.
kind: ai-pattern
pack: performance
project_kind: browser   # requires a rendered UI layer; see templates/packs/_project-kind.md
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
- Cite the bundle-size measurement (the bytes-per-route output of `/bundle-perf`, or the `bundle-analyze` report) before proposing a split; lazy without measurement is a halt.
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

## Which tier is owned where

This pattern is the cross-tier decision: what to defer, what never to defer, and how to prove it paid. The JS, image and list tiers have detector owners in the frontend pack; this file does not restate them. **When the frontend pack is installed**, follow the owner; without it, the one-line rule in the last column is the whole guidance this pack gives, and `/bundle-perf` prints those rows `N/A (owner pack frontend not installed)`.

| Tier | Owner (frontend pack, when installed) | The rule, if the owner is absent |
|---|---|---|
| **Routes** | `code-splitting` detectors 2, 3, 4; meta-frameworks with file-system routing already split per page | Split per route through the framework's lazy-route primitive, with a placeholder and an error boundary |
| **Heavy modules** (charting, rich-text editor, maps, PDF, spreadsheet) | `code-splitting` detector 1; `bundle-analyze` names the chunk and its anchoring import | Dynamic import on first use, placeholder until it resolves |
| **Barrel / whole-library imports** | `code-splitting` detector 5 | Path imports, or the bundler's package-import optimizer |
| **Below-the-fold images** | `image-optimization` §3 (dimensions) and §4 (lazy below the fold, eager above) | `loading="lazy"` plus `width` / `height` or `aspect-ratio` |
| **The LCP element** | `lcp-audit` §1 — never lazy | Eager, `fetchpriority="high"`, in the initial HTML |
| **Large lists** | `list-virtualization` detectors 1–3 | Window the rows once a list can exceed ~100 |

The tiers below have no other owner, so their rules and detectors live here.

| Tier | Examples | Strategy |
|---|---|---|
| **Off-screen videos** | Tutorials, hero videos that auto-play | `preload="none"` + autoplay-on-intersection. |
| **Third-party scripts** | Chat widget, ad scripts, analytics, A/B testing | Load on user gesture, after first interaction, or in idle time; guard against double-load. Detection: `critical-path-scan` §2 (frontend pack, when installed; `/bundle-perf` row I3 dispatches it and prints that row N/A without the pack). |
| **Modal / drawer contents** | Account settings dialog, share sheet | Render the shell; fetch and mount the body on open (the component split itself is `code-splitting` detector 1). |
| **Server data not needed yet** | Tab content not currently selected | Fetch on tab activate. |
| **Hydration scheduling (interactive islands)** | Counter widget, accordion, carousel, comment box | Hydrate only what is interactive, and schedule when (§ Hydration scheduling). |

## When NOT to lazy-load

- **Above-the-fold images** — defer = layout shift + LCP regression.
- **First-paint critical CSS** — lazy CSS = FOUC (flash of unstyled content).
- **Auth check / user data** — needed before any UI; lazy = flicker through unauthenticated UI.
- **Tiny modules (<5 KB)** — splitting overhead > savings.
- **Modules that load on every route change** — they aren't actually deferred.

## Measure first

Lazy-loading is a fix, so the deferred thing must be big enough to matter: `/bundle-perf` measures brotli bytes per route from a production build (identical on every run of the same commit) and Lighthouse / field data for the cost. A 200 KB deferral saves ~200 KB of initial bytes; a 5 KB one saves nothing and adds a round trip. Re-measure after the change with the same build command, and check the guardrail: deferring a widget can move its cost into the first interaction and raise INP (`inp-responsiveness`).

## Hydration scheduling (interactive islands)

Don't hydrate the whole page — hydrate only the islands that are actually interactive, and schedule WHEN each one hydrates. Island frameworks expose a per-island hydration directive; the *names* differ by framework, the schedule classes do not:

| Schedule class | When it hydrates | Use for |
|---|---|---|
| **Eager** | at page load | above-the-fold interactivity only |
| **Idle** | in the runtime's idle callback | non-urgent interactivity |
| **Visible** | when the island enters the viewport | **the default for anything below the fold** |
| **Media-conditional** | only when a media query matches | viewport-specific controls (mobile-only menus) |
| **Client-only** | skips SSR entirely | islands that cannot server-render |

Take the concrete directive spelling from `references/<framework>.md` — never from memory, since the same class has different names across island frameworks. Where the framework offers **resumability** instead of hydration, listeners are serialized in HTML and resume on interaction — no hydration step runs at all, so there is no per-island schedule to tune.

## Detectors (this pattern's tiers)

```bash
FX=(-g '!**/node_modules/**' -g '!**/{dist,build,.next,.nuxt,.output,.svelte-kit,coverage}/**' -g '!**/{test,tests,__tests__,e2e,fixtures}/**' -g '!**/*.{test,spec,stories}.*' -g '!*.{md,mdx}')
# L1 islands hydrated eagerly: Astro client:load; Nuxt <Lazy*> components with no hydrate-on-* strategy
rg -n --no-heading --pcre2 '\bclient:load\b|<Lazy\w+(?![^>]*\bhydrate-)' -g '*.{astro,vue}' "${FX[@]}" .
# L2 off-screen video fetched eagerly: autoplay without preload="none", or preload="auto"
rg -n --no-heading --pcre2 '<video\b(?=[^>]*\bautoplay\b)(?![^>]*\bpreload=["\x27]none)|<video\b[^>]*\bpreload=["\x27]auto' -g '*.{html,jsx,tsx,vue,svelte,astro}' "${FX[@]}" .
```

1. **Island hydrated eagerly below the fold (L1).** Read: is the island below the fold on the measured viewport, and does its eager hydration cost measured main-thread time? Yes to both → `report-with-fix` at `<file:line>` with the directive, proposing the visible class (or idle if it must pre-warm). Above the fold, or no measured cost → `dismiss` with the reason. Proof: the hydration long task in a trace on a production build disappears from the load window after the change.
2. **Off-screen video fetched at load (L2).** Read: is the video in the first viewport? Below the fold → `report-with-fix` (`preload="none"` and play on intersection); a hero video is the LCP tier's business (`lcp-audit`). Proof: the video's bytes leave the load-window request list on a production build.

Report both rows in the run's coverage block as `checked (k hits → m findings)` or `N/A (no .astro or .vue files)`.

## Anti-patterns

- **Lazy-loading the hero image** — defers LCP; primary content not visible at first paint.
- **Lazy-loading without a placeholder** — blank UI for milliseconds; user sees a hole.
- **Lazy-loading without `width`/`height`** — layout shift.
- **Lazy-loading critical scripts** — auth check delayed, user sees a flash of public state.
- **Splitting at the wrong granularity** — 50 chunks of 5 KB = many round trips, slower than 5 chunks of 50 KB.
- **No fallback for a failed lazy load** — module load fails (network); UI stuck.

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
6. Measure impact: bytes per route before / after (same build command) + field LCP / INP.
```

## Monitoring

- **Bytes per route before / after** per chunk.
- **LCP and INP shift** on key pages (field p75).
- **Lazy chunks loaded** per session — too low = users not reaching deferred content; too high = the split was useless.
- **Failed dynamic imports** — track + alert.

## Project-specific anchors

(Phase 4.6 fills this with the project's actual code-split conventions, lazy-image helper, route mapping, and recently-deferred modules.)
