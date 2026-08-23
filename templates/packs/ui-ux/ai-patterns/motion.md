---
name: motion
description: "Pattern: Motion + Animation"
kind: ai-pattern
pack: ui-ux
---

# Pattern: Motion + Animation

> **Hard rule** — Animate `transform` and `opacity` by default, take every duration from the scale in § The duration scale (this file is the pack's single source for those numbers), and gate motion on `prefers-reduced-motion` **by trigger, not by duration**. Decorative motion without a stated purpose is forbidden.

**The failure this prevents:** two of them, and they pull in opposite directions. (1) Motion added as garnish — a page where everything eases, nothing means anything, and the 40×/day user is waiting on animation to finish. (2) Motion "handled" by one global reduced-motion reset that the team then treats as the accessibility story, while the parallax hero that actually triggers vestibular symptoms keeps running because it is driven by scroll, not by a `transition-duration`.

**When to apply**
- Showing state transitions (open/close, success/error, list add/remove).
- Communicating relationships between elements (a drawer slides from the edge it lives on).
- Micro-feedback on interactive elements (button press, toggle flip).

**When NOT to apply**
- Looping ambient motion in a content view — attention hog and an accessibility risk.
- Animating layout-triggering properties (`width`, `height`, `top`, `left`, `box-shadow`) — performance dies before polish arrives.
- Decorative sparkles / bounces with no functional message — they cheapen the product.
- A high-frequency operator surface where the same transition is paid 200×/hour. Speed is the feature; cut the duration or cut the motion.

**Halt conditions / mandatory cites**
- Cite the duration + easing token file as `<path:line>` before introducing a new animation; raw `200ms ease-out` strings inline are a halt.
- Cite the `prefers-reduced-motion` handling as `<path:line>`; if absent, halt and add it BEFORE shipping any new motion.
- Cite a low-end-device measurement or perf budget doc as `<path:line>` for any animation above the `base` band or affecting > 25% of the viewport.
- Refuse to animate non-composited properties without a measured perf justification recorded as `<path:line>` in the perf log.
- Hand-wave grep ban — never claim "no `transition: all`" without a cited stylelint rule or grep artifact path.

## The duration scale (the pack's single source — cite this, do not restate it)

`motion-audit`, `ui-design-sweep § normalize-motion` and the `/redesign` · `/art-direct` motion lens all cite this table. A number that disagrees with it is drift.

| Class | Token | Band | Rule |
|---|---|---|---|
| Micro-interaction — press, toggle, hover, focus ring | `fast` | **100–150 ms** | Perceived as instant. Anything slower makes the control feel laggy. |
| UI transition — open/close, expand, tab change, list add/remove | `base` | **200–300 ms** (token: 250 ms) | The band the design rubrics mean by "≤ 200–300 ms". |
| Page / view transition | `slow` | **300–400 ms** (token: 400 ms) | The only class allowed past 300 ms as a matter of course. |
| **Frequent-action ceiling** | — | **> 400 ms is a finding** | Any motion on an action a user performs repeatedly (button, row, filter). It is not "premium", it is a tax per repetition. |
| **Absolute ceiling** | — | **> 500 ms is forbidden** for non-decorative UI motion | Past this the animation is the interaction. |

```ts
duration: { fast: 150, base: 250, slow: 400 }
ease:     { out: 'cubic-bezier(0.2, 0, 0, 1)',   // entering
            in:  'cubic-bezier(0.4, 0, 1, 1)',   // exiting
            inOut: 'cubic-bezier(0.4, 0, 0.2, 1)' }  // state change
```

Easing follows the class: `ease-out` entering, `ease-in` exiting, `ease-in-out` between states. Never block interaction on an animation.

## Common patterns

### Reveal (fade + slight rise)
```css
@keyframes reveal {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
.reveal { animation: reveal var(--duration-base) var(--ease-out); }
```

### Skeleton loading
Shape-matched placeholders, not a spinner; fade out in place when content arrives. A skeleton whose shape does not match the eventual layout is a layout-shift generator in a loading state's clothes.

### State transitions
List add/remove and expand/collapse take `base`. Prefer explicit property lists over `transition: all` — `all` animates properties you did not intend, including newly-added ones, and is the commonest source of accidental layout animation.

### View transitions
The CSS View Transitions API for full-page navigation, as a progressive enhancement — navigation must work identically where it is unsupported.

## Tools

- **Motion for React** (`motion`, imported from `motion/react`) — **previously named Framer Motion**; the rename is complete and the old package name is the stale-doc tell ([motion.dev](https://motion.dev/docs/react)).
- **GSAP** — heavyweight, powerful; justified by timeline complexity, not by preference.
- **CSS transitions + keyframes** — for simple cases, which is most cases.
- **View Transitions API** — for full-page transitions (progressive enhancement).

## Accessibility: `prefers-reduced-motion`

**Gated by TRIGGER, not by duration.** Any interaction- or scroll-triggered motion — parallax, zoom, scale, auto-play, scroll-linked — respects the preference **regardless of how short it is**: the criterion is about motion the user did not ask for, not about a clock. Duration only decides whether an *incidental* transition also needs the branch (over the `base` token, 250 ms, it does). Preferred shape is per-component opt-IN, so new motion is reduced-motion-safe by default.

```css
@media (prefers-reduced-motion: no-preference) {
  .drawer { transition: transform var(--duration-base) var(--ease-out); }
}
```

The global reset is the **blunt retrofit fallback**, not the strategy — know what it costs:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

- It also kills `scroll-behavior: smooth`, which many users of the preference still want.
- It nulls motion that is **essential** to the information conveyed (progress, where a panel went) — the criterion exempts those; the reset does not.
- It cannot reach scroll-linked or JS-driven motion, which is usually what caused the complaint. Pair it with `matchMedia('(prefers-reduced-motion: reduce)')` in the animation layer.

Reduce ≠ remove: a cross-fade beats an instant cut, because the user still sees that something changed.

## Performance

- **Animate `transform` and `opacity`.** They composite; `width` / `height` / `top` / `left` / `margin` / `font-size` re-layout every frame.
- **`filter` is not in the cheap set.** It composites but is *shaded* per frame, and `blur()` scales with area — a large animated blur is routinely the most expensive thing on the page. Measure it.
- **`will-change` sparingly** — apply just before the animation, remove after; left on, it holds GPU memory per element.
- **`contain: layout` is the safe containment hint.** Do NOT reach for `contain: paint` reflexively: `paint` means a descendant "will be clipped to the containing element's overflow clip edge" ([MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/contain)), so it silently clips tooltips, dropdowns, popovers and focus rings. Use it only where nothing is meant to escape, and verify in the render.
- **Measure on the slowest device you support.** A 60fps laptop animation can be 15fps on a low-end phone; the profile, not the feeling, is the finding.

## Forbidden

- Any non-decorative UI motion over **500 ms**; over **400 ms** on a frequent action is a finding.
- `transition: all`.
- Motion that loops indefinitely in view (attention hog).
- Large elements animating continuously (perf killer + distraction).
- Ignoring `prefers-reduced-motion`, or treating a global reset as full coverage for scroll-linked/JS-driven motion.
- Animating layout-triggering properties (width, height, top, left).
- `contain: paint` on a container whose children are meant to overflow it.
- Decorative motion without a clear purpose.
