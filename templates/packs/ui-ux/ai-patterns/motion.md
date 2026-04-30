---
name: motion
description: Pattern: Motion + Animation
kind: ai-pattern
pack: ui-ux
---

# Pattern: Motion + Animation

> **Hard rule** — Animate only `transform` and `opacity`, keep UI micro-interactions ≤ 250ms, and respect `prefers-reduced-motion` globally. Decorative motion without a stated purpose is forbidden.

**When to apply**
- Showing state transitions (open/close, success/error, list add/remove).
- Communicating relationships between elements (drawer slides from edge it lives on).
- Micro-feedback on interactive elements (button press, toggle flip) under 200ms.

**When NOT to apply**
- Looping ambient motion in a content view (attention hog, accessibility risk).
- Animating layout-triggering properties (`width`, `height`, `top`, `left`, `box-shadow`) — performance kills before polish.
- Decorative sparkles / bounces with no functional message — cheapens the product.

**Halt conditions / mandatory cites**
- Cite the duration + easing token file as `<path:line>` before introducing a new animation; raw `200ms ease-out` strings inline are a halt.
- Cite the global `@media (prefers-reduced-motion: reduce)` rule as `<path:line>`; if absent, halt and add it BEFORE shipping any new motion.
- Cite a low-end-device test or perf budget doc as `<path:line>` for any animation > 250ms or affecting > 25% viewport.
- Refuse to animate non-composited properties without a measured perf justification recorded as `<path:line>` in the perf log.
- Hand-wave grep ban — never claim "no `transition: all`" without a cited stylelint rule or grep artifact path.

Motion guides attention, communicates state, adds polish. Bad motion distracts, annoys, excludes users with vestibular disorders.

## Principles

### Purpose, not decoration
- Every animation answers WHY. Drawing attention? Showing relationship between states? Providing feedback?
- Decorative motion (sparkles, bounces-for-fun) cheapens UX.

### Fast + subtle
- UI micro-interactions: 150-250ms.
- Page transitions: 250-400ms.
- Anything > 500ms feels slow.
- Never block interaction on animation (user must be able to click through).

### Consistent easing
- `ease-out` for entering elements.
- `ease-in` for exiting elements.
- `ease-in-out` for transitions between states.
- Custom cubic-beziers stored as design tokens:
  ```ts
  duration: { fast: 150, base: 250, slow: 400 }
  ease: { out: 'cubic-bezier(0.2, 0, 0, 1)', in: 'cubic-bezier(0.4, 0, 1, 1)', ... }
  ```

## Common patterns

### Reveal (fade + slight rise)
```css
@keyframes reveal {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
.reveal { animation: reveal 200ms var(--ease-out); }
```

### Skeleton loading
- Not spinners. Shape-matched placeholders with subtle shimmer.
- Fades out in place when real content arrives.

### Transition between states
- List add/remove: `transition-all 250ms` + `opacity 0 → 1`.
- View transitions (page navigation): CSS `view-transition` API where supported.

### Micro-interactions (button press, toggle flip)
- Transform-based (GPU-accelerated), < 200ms.

## Tools

- **Framer Motion** / `motion-one` — React/Vue, declarative.
- **GSAP** — heavyweight but powerful.
- **CSS transitions + keyframes** — for simple cases (which is most cases).
- **View Transitions API** — for full-page transitions (progressive enhancement).

## Accessibility: `prefers-reduced-motion`

MANDATORY. Respect it:

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

OR at component level: check `window.matchMedia('(prefers-reduced-motion)').matches` and disable animations conditionally.

## Performance

- Animate TRANSFORM + OPACITY only (GPU-composited). Avoid animating width / height / top / left / box-shadow.
- `will-change` sparingly — only when animation is about to start, remove after.
- `contain: layout paint` on animating containers.
- Test on low-end devices. A 60fps MacBook animation can be 15fps on cheap Android.

## Forbidden

- Animations > 500ms on UI micro-interactions.
- Motion that loops indefinitely in view (attention hog).
- Large elements animating continuously (perf killer + distraction).
- Ignoring `prefers-reduced-motion`.
- Animating layout-triggering properties (width, height, top, left).
- Decorative motion without a clear purpose.
