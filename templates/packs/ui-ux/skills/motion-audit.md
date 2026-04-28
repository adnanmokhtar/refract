---
description: Audit motion + animations for performance, reduced-motion respect, easing/duration consistency, and the "feels janky" smell. Output concrete fixes per offender.
---

# Skill: motion-audit

Animations are where polish lives — and where battery drains, where prefers-reduced-motion is ignored, and where 60fps becomes 30fps without anyone noticing. This skill walks the project's motion surface.

## When to use

- Pre-release polish pass.
- Investigating "feels janky" complaints (subjective, real).
- After a major framework upgrade (RN → New Architecture, React 19 transitions, etc.).
- Quarterly motion-token audit.

## Procedure

### 1. Inventory animations

Search the codebase for animation primitives:

| Web | RN | Flutter |
|---|---|---|
| `transition:` (CSS) | `Animated.*`, Reanimated `useSharedValue` | `AnimatedBuilder` |
| `animation:` (CSS keyframes) | `LayoutAnimation` | `Hero`, `AnimatedContainer` |
| Framer Motion `<motion>` | `react-native-reanimated` | `flutter_animate` |
| GSAP, anime.js | Lottie | `lottie_flutter` |
| View Transitions API | `Animated.parallel` / `sequence` | `AnimationController` |

Per animation, note: trigger, duration, easing, what property animates.

### 2. Performance check

Animating these is GPU-cheap (60fps stable):
- `transform` (translate / scale / rotate)
- `opacity`
- `filter` (modern browsers)

Animating these triggers layout / paint (frequently expensive):
- `width`, `height`, `top`, `left`, `right`, `bottom`
- `margin`, `padding`
- `font-size`, `line-height`
- `border-width`

Web rule: animate transform + opacity only. Use `will-change` sparingly (it's a hint, not a fix; over-use blows GPU memory).

RN rule: use Reanimated 2/3 worklets for any animation > 100ms. Animated.View on the JS thread blocks UI on heavy renders.

Flutter rule: use `AnimatedBuilder` not `setState` in the animation loop.

### 3. Reduced-motion respect

Per platform:
- Web: CSS `@media (prefers-reduced-motion: reduce)` — disable / shorten / replace with cross-fade.
- iOS: `UIAccessibility.isReduceMotionEnabled` — same idea.
- Android: `Settings.Global.ANIMATOR_DURATION_SCALE` — respect the user's setting.
- RN: `AccessibilityInfo.isReduceMotionEnabled()`.
- Flutter: `MediaQuery.disableAnimations`.

If any animation > 500ms doesn't respect reduce-motion → finding.

### 4. Token consistency

Project's animation tokens (if any):

| Token | Common values |
|---|---|
| Duration | fast (150ms), base (250ms), slow (400ms) |
| Easing | linear, ease-in, ease-out, ease-in-out, spring |
| Stagger | 50ms, 100ms |

Check if animations use tokens or hardcode. Consistency matters: same trigger should feel the same across the app.

### 5. Specific anti-patterns

- **Spinner that animates indefinitely on a backgrounded screen** — drains battery.
- **Long entry animation on every render** — annoys users, breaks scroll perception.
- **Animation longer than 600ms on a frequent action** (button press, list item) — feels slow.
- **No animation when changing critical state** — abrupt; users miss the change.
- **Animation that hides actual content** (loading shimmer for 2s when data already loaded).
- **Parallax / scroll-driven animation without throttling** — janky on mid-tier devices.
- **Lottie animation embedded but never garbage-collected** — memory leak.
- **CSS animation with high-frequency keyframes** (60+ keyframes for a 1s anim) — pointless precision.

### 6. Mobile-specific

- 60fps target; profile with React Native Performance Monitor / Flipper / Flutter DevTools.
- Animations on the same frame as data fetch → frame drops.
- Native driver (`useNativeDriver: true`) for RN Animated API.
- Avoid animating during scroll (causes layout thrash on iOS).
- Avoid >2 simultaneous Lottie / Rive animations.

## Output format

```
## Motion audit — <YYYY-MM-DD>

### Inventory
- 47 animations found across 23 files.
- Token usage: 18/47 use tokens; 29/47 hardcode duration / easing.

### Performance findings
**Layout-triggering animations (BLOCKER):**
- `Card.vue:34` — animates `height` on hover. Causes layout thrash. Fix: animate `transform: scaleY()` + adjust origin.
- `Modal.tsx:88` — animates `width` on open. Same fix pattern.

**JS-thread animations on RN:**
- `OnboardingCarousel.tsx` — Animated.View without `useNativeDriver`. Drops to 30fps on mid-tier Android. Fix: migrate to Reanimated worklet.

### Reduced-motion findings (HIGH)
- 12 animations > 250ms that don't check `prefers-reduced-motion`.
- 1 hero parallax that disorients reduced-motion users — replace with static image.

### Token consistency (MEDIUM)
- 7 different durations in use (150 / 200 / 250 / 280 / 300 / 320 / 400). Reduce to 3 tokens (fast/base/slow).
- 5 different easing curves. Reduce to 2 (ease-out for entry, ease-in-out for state changes).

### Anti-patterns (LOW)
- Indefinite shimmer on already-loaded list (`UserList.vue:45`). Remove.
- 3 animations longer than 800ms — review if they're earning the time.
- 2 looping Lottie animations on the home screen — collapse to one or load on-demand.

### Suggested motion tokens
```
duration: { fast: 150, base: 250, slow: 400 }
easing:   { entry: 'cubic-bezier(.2,.8,.2,1)', exit: 'cubic-bezier(.4,.0,.2,1)' }
```

### Auto-fixable
- 18 hardcoded `200ms` / `300ms` → token replacement (mechanical).
```

## Inputs

- Scope (whole repo / specific module / changed files).
- Has motion tokens? (auto-detect from theme files).

## Outputs

- `ai/audits/motion-<date>.md`.

## Failure modes

- Reviewed CSS but missed JS-driven animations (GSAP, Framer Motion programmatic API).
- Said "use transform" but the animation legitimately needs to animate layout (rare; flag for human review).
- Profile-tested on a high-end device → missed mid-tier degradation.
- Disabled an animation for reduced-motion but the surrounding state change is no longer visible → finding without recovery.

## Related

- `design-token-audit.md` — token consistency, broader scope.
- `a11y-quick-check.md` — overlap on reduced-motion respect.
- `@design-system-guardian` — governance.
- `@accessibility-auditor` — WCAG 2.2 AA covers motion (success criterion 2.3.3).
