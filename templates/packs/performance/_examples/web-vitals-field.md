---
name: web-vitals-field
description: Measure Core Web Vitals in the FIELD with attribution — wire the web-vitals attribution build so a poor INP/LCP/CLS points to the exact element + sub-part. Lab tools cannot field-measure INP; this is the only path to citing the headline CWV.
---

# web-vitals-field

## Premise

Field Core Web Vitals **with attribution**, or it is not a finding. Lighthouse runs one synthetic load with zero real interactions — it cannot field-measure INP (Interaction to Next Paint), the headline Core Web Vital since March 2024. The truth comes from real users: the `web-vitals` library's attribution build reports each metric AND the element + timing sub-part responsible, so a regression is citeable ("INP 340ms → `button.add-to-cart`, 280ms in processing") instead of a bare number.

A reported INP/LCP without an attributed target + sub-part breakdown is a halt, not a finding.

This skill stands up the measurement; `bundle-perf` / `lighthouse-ci` consume the budgets, `inp-responsiveness` fixes the INP causes it attributes, and `navigation-speed` consumes the per-route (soft-navigation) INP it surfaces.

## Procedure

```ts
import { onINP, onLCP, onCLS, onTTFB } from 'web-vitals/attribution';  // NOT plain 'web-vitals'
const send = (m) => navigator.sendBeacon('/rum', JSON.stringify(m));
onINP(send); onLCP(send); onCLS(send); onTTFB(send);
```

Report on `visibilitychange`/`pagehide` (`sendBeacon` survives unload + doesn't block bfcache). Cross-check the p75 against **CrUX** (CrUX History API / PageSpeed Insights API) — that's what "passing CWV" means.

## Attribution fields

- **INP** — `interactionTarget`, `interactionType`, `inputDelay`, `processingDuration`, `presentationDelay`, `longAnimationFrameEntries` (array of LoAF entries; read `.scripts[].invoker` / `.sourceURL`). *(Field is `longAnimationFrameEntries`, not `longAnimationFrames`.)*
- **LCP** — `element`, `url`, `timeToFirstByte`, `resourceLoadDelay`, `resourceLoadDuration` *(renamed from `resourceLoadTime`)*, `elementRenderDelay`.
- **CLS** — `largestShiftTarget`, `largestShiftValue`, `loadState`.

## Output

```
Field CWV (p75, 28d, mobile)        source: RUM + CrUX

  INP  340ms  POOR  (good ≤200)  → button.add-to-cart | inputDelay 20 · processing 280 · presentation 40
                     → LoAF script /assets/cart-abc.js → fix via inp-responsiveness
  LCP  2.9s   NEEDS-WORK (good ≤2.5) → img.hero | TTFB 700 · loadDelay 400 · loadDuration 600 · renderDelay 200
                     → TTFB dominates → streaming-ssr; loadDelay → preload + fetchpriority (lcp-audit)
  CLS  0.04   GOOD  (good ≤0.1)
  TTFB 700ms  NEEDS-WORK (lab budget) → server-response-time
       # field-good is ≤800ms; 700ms passes THAT and misses only the stricter 600ms lab audit.
       # Label which bar a value failed — calling a field-good value POOR hides real regressions.
```

## SPA / soft navigations

INP is attributed to the page at interaction time. Soft-nav reporting via the **experimental/flagged** `reportSoftNavs` option on `onINP` (depends on the emerging Soft Navigations heuristic) — opt-in, not a guarantee; mark route boundaries yourself (`performance.mark`) and segment RUM by route.

## False positives / gotchas

- Lab tools produce a *synthetic* interaction-to-next-paint only by scripting an interaction — it is a proxy, never the field value. **Never cite lab INP as the measurement.**
- A single user's value is noise; budgets are judged on the **p75 across real users**.
- Attribution needs the `web-vitals/attribution` import — the plain `web-vitals` import returns the value with no `attribution` object.
- `longAnimationFrameEntries` is only populated where the Long Animation Frames API is supported — absence ≠ "no blocking script", just no LoAF data.

## When to run

- Standing instrumentation on any production frontend with real users (this is RUM, not a one-shot).
- When a lab gate flags LCP/CLS and you need the field truth + the responsible element.
- When INP is the suspected problem — the field is the ONLY way to measure it.

## Halt conditions

- INP/LCP reported without `attribution` (target + sub-part) = halt.
- "Passing/failing CWV" claim citing lab data with no CrUX/RUM p75 = halt.
- Soft-nav INP claimed from `reportSoftNavs` without flagging it's experimental = halt.
- RUM beacon flushing on `unload` (blocks bfcache) = halt → use `pagehide` + `sendBeacon`.
