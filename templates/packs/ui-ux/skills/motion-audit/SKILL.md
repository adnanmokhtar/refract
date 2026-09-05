---
name: motion-audit
description: Audit motion and animations for performance, reduced-motion respect, easing/duration consistency, and the "feels janky" smell, emitting concrete fixes per offender. Run as a pre-release polish pass, when investigating jank complaints, after a major framework upgrade, or as a quarterly motion-token review. Motion only — `design-token-audit` covers the broader token surface and `a11y-quick-check` owns the reduced-motion overlap. Durations are not defined here; they are cited from `motion.md § The duration scale`.
kind: skill
pack: ui-ux
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: motion-audit

Animations are where polish lives — and where battery drains, where `prefers-reduced-motion` is ignored, and where 60fps becomes 30fps without anyone noticing. This skill walks the project's motion surface.

## Premise

Find real motion issues, no hand-waves. Every finding cites `<path:line>` of the animation declaration and names the concrete cost: a layout-trigger property, a main-thread block, a missing `prefers-reduced-motion` branch, or a duration off the project's token scale. "Feels janky" is the symptom that prompts the audit, not a finding — the finding is the offending property plus a measurement.

**This skill does NOT own the numbers.** Durations come from `motion.md § The duration scale` (fast 150 / base 250 / slow 400; `> 400 ms` on a frequent action is a finding, `> 500 ms` is forbidden); token *values* come from the project's resolved tokens. This skill detects and cites — a threshold here that disagrees with `motion.md` is drift, and `motion.md` wins.

## Halt conditions

- Halt on findings without `<path:line>` for the animation declaration.
- Halt on performance claims ("drops to 30fps") without a profiling artifact — a captured trace or profile file, or a frame-rate reading from the platform's own performance overlay. Name the tool and the artifact path; a frame rate nobody recorded is not a measurement.
- Halt on token suggestions that propose values not in the project's resolved motion-token table.
- Halt on citing a WCAG criterion at the wrong conformance level (see § 3) — this skill's findings are quoted into a11y reports.

## When to use

- Pre-release polish pass.
- Investigating "feels janky" complaints (subjective, real).
- After a major framework or animation-library upgrade.
- Quarterly motion-token audit.

## Procedure

### 1. Inventory animations

Search the codebase for animation primitives. The families differ per stack; the audit is the same:

| Web | React Native | Flutter |
|---|---|---|
| `transition:` (CSS) | `Animated.*`, Reanimated `useSharedValue` | `AnimatedBuilder` |
| `animation:` (CSS keyframes) | `LayoutAnimation` | `Hero`, `AnimatedContainer` |
| Motion for React `<motion>` (`motion/react`; ex-Framer Motion) | `react-native-reanimated` | `flutter_animate` |
| GSAP, anime.js | Lottie | `lottie_flutter` |
| View Transitions API | `Animated.parallel` / `sequence` | `AnimationController` |

Per animation, record: trigger, duration, easing, and **which property animates** — the last one is what decides most findings.

### 2. Performance check

| Class | Properties | Verdict |
|---|---|---|
| **Composited** | `transform` (translate / scale / rotate), `opacity` | Cheap — the default target. |
| **Composited but SHADED per frame** | `filter` (especially `blur()`), `backdrop-filter` | **Measure, never assume.** Cost scales with the animated area; a large animated blur is routinely the most expensive thing on the page and behaves nothing like `opacity`. "It's GPU-accelerated" is a hypothesis to profile, not a pass. |
| **Triggers layout / paint** | `width`, `height`, `top`/`left`/`right`/`bottom`, `margin`, `padding`, `font-size`, `line-height`, `border-width`, `box-shadow` | Expensive. For `box-shadow`, animate `opacity` on a stacked shadow layer instead of repainting the shadow every frame. |

**The stack-neutral rule underneath it:** an animation is cheap when it runs on the compositor without asking the main/UI thread for a new frame of layout. Every platform spells "get this off the main thread" differently; audit the *property class* here, and leave the platform mechanism to that platform's reference (see § Related).

Also flag `transition: all` (animates properties nobody intended) and `will-change` left on permanently (holds GPU memory per element).

### 3. Reduced-motion respect — and the conformance level, stated correctly

**Gate on TRIGGER, not on duration.** Any **interaction- or scroll-triggered** motion (parallax, zoom, scale, auto-play, scroll-linked) must respect reduced motion **regardless of duration**. A duration threshold applies only to *incidental* transitions: an incidental transition longer than the project's `base` token (250 ms) that ignores reduce-motion is a finding.

**Do not quote this as a WCAG AA requirement.** The criterion about interaction-triggered motion is **[SC 2.3.3 Animation from Interactions](https://www.w3.org/TR/WCAG22/) — Level AAA**. What binds below AAA is narrower: **[SC 2.2.2 Pause, Stop, Hide](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html) — Level A** — a pause/stop/hide mechanism for content that "(1) starts automatically, (2) lasts more than five seconds, and (3) is presented in parallel with other content", unless essential. So an auto-playing carousel past 5 s beside other content is a **Level-A conformance failure**, while a parallax hero with no reduced-motion branch is a **house-rule violation with a AAA criterion named** — reporting the latter as "fails WCAG 2.2 AA" is false and discredits the rest of the report. `prefers-reduced-motion` is the mechanism, not the criterion; its per-platform equivalents belong in that platform's reference.

### 4. Token consistency

Read the project's resolved motion tokens (theme file / token source). If the project has none, the finding is "no motion token scale" and the proposal is `motion.md § The duration scale` as the seed — not a set of numbers invented in this run.

Check each animation: does it reference a token, or hardcode? Consistency is the point — the same trigger should feel the same everywhere in the app.

### 5. Specific anti-patterns

- **Spinner animating indefinitely on a backgrounded screen** — drains battery.
- **Long entry animation on every render** — annoys users, breaks scroll perception.
- **Motion over the frequent-action ceiling** (`> 400 ms`, `motion.md § The duration scale`) on a button press, row action, or filter — a tax paid per repetition.
- **No animation when changing critical state** — abrupt; users miss the change.
- **Animation that hides real content** (a 2 s shimmer over data that already arrived).
- **Parallax / scroll-driven animation without throttling** — janky on mid-tier devices, and a reduced-motion finding by trigger.
- **A Lottie / Rive composition mounted but never released** — memory leak.
- **CSS animation with high-frequency keyframes** (60+ keyframes for a 1 s animation) — pointless precision.

## Output format

```
## Motion audit — <YYYY-MM-DD>

### Inventory
- 47 animations found across 23 files.
- Token usage: 18/47 use tokens; 29/47 hardcode duration / easing.

### Performance findings
**Layout-triggering animations (BLOCKER):**
- `Card.vue:34` — animates `height` on hover. Layout thrash. Fix: animate `transform: scaleY()` + adjust origin.
- `Modal.tsx:88` — animates `width` on open. Same fix pattern.

**Shaded-property animations (HIGH — measured, not assumed):**
- `Hero.vue:22` — animates `filter: blur(0→12px)` over a full-bleed image. Measured 34fps on the reference low-end device [profile: `perf/hero-blur.json`]. Fix: pre-render two layers and cross-fade `opacity`.

**Main-thread-bound animations:**
- `OnboardingCarousel.tsx:64` — driven from the JS thread. Measured 30fps on mid-tier Android [trace: `perf/onboarding-carousel.<ext>`]. Fix: move to the platform's off-main-thread driver (see the platform reference). *(No trace? print `fps: SKIPPED (not profiled)` — never assert a frame rate you did not measure, per Halt conditions.)*

### Reduced-motion findings
**Conformance (Level A — 2.2.2 Pause, Stop, Hide):**
- `PromoTicker.vue:11` — auto-starts, runs indefinitely, sits beside page content, no pause control. WCAG 2.2.2 (A).

**House rule (2.3.3 is Level AAA — reported as a house violation, not as an AA failure):**
- 1 hero parallax with no reduced-motion branch — replace with a static image under `reduce`.
- 12 incidental transitions > 250 ms (`base`) with no reduced-motion branch.

### Token consistency (MEDIUM)
- 7 different durations in use (150 / 200 / 250 / 280 / 300 / 320 / 400). Reduce to 3 tokens (fast/base/slow).
- 5 different easing curves. Reduce to 3 (entry / exit / state-change).

### Anti-patterns (LOW)
- Indefinite shimmer on an already-loaded list (`UserList.vue:45`). Remove.
- 3 animations over the 500 ms absolute ceiling — cut or justify.
- 2 looping compositions on the home screen — collapse to one or load on demand.

### Suggested motion tokens  (from `motion.md § The duration scale` — not invented here)
    duration: { fast: 150, base: 250, slow: 400 }
    easing:   { entry: 'cubic-bezier(.2,.8,.2,1)', exit: 'cubic-bezier(.4,.0,.2,1)' }

### Auto-fixable
- 18 hardcoded `200ms` / `300ms` → token replacement (mechanical).

### Coverage
profiled: 2 of 3 performance findings · reduced-motion: source-scan only (no OS-level toggle test — human lane)
```

## Inputs

- Scope (whole repo / specific module / changed files).
- The project's resolved motion tokens (auto-detect from theme files). Absent → the token-consistency lane reports "no scale defined", never a fabricated one.

## Outputs

- `ai/audits/motion-<date>.md`.

## Failure modes

- **Reviewed CSS but missed JS-driven animation** (a library's programmatic API, a scroll listener). Grep the animation library's imports, not just stylesheets.
- **Said "use transform" where the animation legitimately needs layout** (rare) — flag for human review rather than forcing the fix.
- **Profiled on a high-end device** → missed the mid-tier degradation that prompted the audit.
- **Quoted 2.3.3 as a Level AA requirement.** It is AAA. Doing so inflates the severity of the reduced-motion findings and undermines the 2.2.2 finding that IS a Level-A failure.
- **Called `filter` GPU-cheap.** It composites but shades per frame; `blur()` cost scales with area.
- **Disabled an animation for reduced motion and left the state change invisible** — a finding with no recovery. Replace with a cross-fade, don't cut to nothing.

## Related

- `motion.md` (this pack) — **owns the duration scale, the easing classes, and the reduced-motion policy this skill audits against.** Findings cite it; they never restate a different number.
- `design-token-audit.md` — token consistency at the broader (colour / spacing / type) surface; this skill is the motion dimension of it.
- `a11y-quick-check.md` — the in-pack a11y skill; owns the accessibility report this skill's reduced-motion findings feed into.
- `@design-system-guardian` — governance.
- `@accessibility-auditor` *(frontend pack)* — full a11y audit; escalate only when that pack is installed. Note the level split above: 2.2.2 is Level A, 2.3.3 is Level AAA.
- **Native / mobile surfaces** — the per-platform reduced-motion APIs, off-main-thread drivers, and profilers live in the `mobile` pack's `references/<framework>.md` (React Native · Flutter · SwiftUI · Jetpack Compose · Expo), which is where platform mechanics belong. This skill audits the property class and the trigger; it does not carry platform APIs.
- `/enhance-ui` — apply motion findings as the `motion-drift` cleanup class within the system.
- `/redesign` · `/art-direct` — where motion is a first-class **BUILD OUTPUT** (a rendered lens), not just a token-consistency fix.
