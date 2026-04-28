---
name: motion
description: Pattern: Motion + Animation
kind: ai-pattern
pack: ui-ux
---

# Pattern: Motion + Animation

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
