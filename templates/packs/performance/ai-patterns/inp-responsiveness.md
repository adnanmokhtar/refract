---
name: inp-responsiveness
description: Pattern — keep per-interaction main-thread work under the INP budget. Diagnose the dominant INP sub-part (input delay / processing / presentation), then break long tasks, defer non-urgent updates, and attribute the blocking script via LoAF.
kind: ai-pattern
pack: performance
---

# Pattern: INP responsiveness

> **Hard rule** — Browser input handlers MUST keep per-interaction main-thread work under the INP budget (good ≤ 200ms at p75). Before fixing, attribute the dominant sub-part with field data — never guess. A long task that blocks the main thread during an interaction MUST be broken up or deferred; shipping a synchronous >50ms handler on a hot interaction is forbidden.

**Where those two numbers come from** — INP "good" is **≤ 200 ms at the 75th percentile** (https://web.dev/articles/inp); a **long task** is "any uninterrupted period where the main UI thread is busy for 50 ms or longer" (https://developer.mozilla.org/en-US/docs/Web/API/PerformanceLongTaskTiming). Neither is this project's SLA — where `ai/runtime/perf-budgets.md` sets a tighter budget, that one wins and is the number to cite.

**When to apply**
- `web-vitals-field` attributes a poor INP to a specific handler / element, OR `bundle-perf`'s vitals table flags INP.
- A high-frequency handler (typing, scrolling, dragging, filtering a large list) drives an interaction.
- A click triggers an expensive synchronous recompute / large re-render before the next paint.

**When NOT to apply**
- INP is already good (≤200ms p75) — don't pre-optimize handlers that aren't on the critical interaction path.
- The cost is in a Web Worker / off the main thread already (yielding won't help; it's not blocking paint).
- A one-off interaction (rare admin action) where responsiveness isn't user-facing.

**Halt conditions / mandatory cites**
- Cite the handler at `<file:line>` + the attributed INP sub-part (`inputDelay` / `processingDuration` / `presentationDelay`) before proposing a fix; "this handler is probably slow" is a halt.
- Cite the blocking script from the Long Animation Frames API (LoAF) — `longAnimationFrameEntries[].scripts[].invoker` / `.sourceURL` — when claiming a specific script blocks the interaction.
- Hand-wave grep ban — never claim "no long tasks" without the LoAF / performance-trace artifact.
- A fix that wraps an *async data fetch* in `startTransition` (transitions are for state updates, not data latency) is a bug — reject.

## INP = three sub-parts — diagnose before fixing

```
INP  =  inputDelay  +  processingDuration  +  presentationDelay
        (main thread     (your event           (render + paint
         busy at click)   handlers run)          after handler)
```

Read `metric.attribution` from `web-vitals-field` (`onINP`) to see which dominates — the fix is different for each:

| Dominant sub-part | Cause | Fix |
|---|---|---|
| **inputDelay** | main thread busy with other work when the user clicked | break the *other* long tasks (yield, defer hydration, split bundles) |
| **processingDuration** | your handler does too much synchronously | break the task (`scheduler.yield()`), debounce, move pure compute to a Worker |
| **presentationDelay** | huge/expensive render after the handler | defer non-urgent updates (`startTransition` / `useDeferredValue`), virtualize, avoid layout thrash |

## Break long tasks (processing-bound)

Yield to the main thread so the browser can paint between chunks. Define the yield once, with a real fallback — `scheduler.yield()` is not universally available, and a fallback that lives in a comment does not run:

```js
const yieldToMain = () =>
  globalThis.scheduler?.yield?.() ?? new Promise(r => setTimeout(r, 0));
```

```ts
async function handleClick() {
  for (const chunk of chunks) {
    process(chunk);
    if (navigator.scheduling?.isInputPending?.()) await yieldToMain();
  }
}
```

- `scheduler.yield()` — yields then continues at the *front* of the queue (better than `setTimeout(0)`, which goes to the back). That ordering difference is the whole reason to prefer it: a `setTimeout` yield can put your continuation behind every other queued task.
- `navigator.scheduling.isInputPending()` — only yield when input is actually waiting.
- `requestIdleCallback` — run genuinely non-urgent work in idle time.

## Defer non-urgent updates (presentation-bound)

```tsx
// React: keep the input responsive; the expensive filtered list updates as a low-priority transition
const [isPending, startTransition] = useTransition();
const onChange = (e) => {
  setQuery(e.target.value);                 // urgent — input echoes immediately
  startTransition(() => setResults(filter(all, e.target.value))); // non-urgent
};
// or: const deferredQuery = useDeferredValue(query);
```

- **React** — `useTransition` / `startTransition` for nav- or filter-triggered updates; `useDeferredValue` for derived expensive views.
- **Vue** — updates are batched/async by default; for very large reactive recomputes, debounce the source or split with `computed` + `shallowRef`.
- **Svelte** — keep `$:`/runes-derived work cheap; debounce the trigger for heavy derivations.

## Debounce / throttle high-frequency handlers

`input`, `scroll`, `resize`, `pointermove`, `mousemove` fire rapidly — coalesce them so the handler runs once per frame / per pause, not per event.

## Attribute the blocking script (LoAF)

```ts
new PerformanceObserver((list) => {
  for (const frame of list.getEntries()) {          // type: 'long-animation-frame'
    for (const script of frame.scripts) {
      console.log(script.invoker, script.sourceURL, script.duration);
    }
  }
}).observe({ type: 'long-animation-frame', buffered: true });
```

The Long Animation Frames API names the script (`invoker`, `sourceURL`) responsible for a long frame — that's the citeable culprit, not "something is slow."

## Avoid synchronous layout thrash

Reading layout (`offsetWidth`, `getBoundingClientRect`) right after writing to the DOM forces a synchronous reflow inside the handler. Batch reads then writes (or use `requestAnimationFrame`) so a hot handler doesn't thrash layout per element.

## Forbidden

- A synchronous handler that does >50ms of work on a hot interaction (typing, dragging, primary click).
- Wrapping an async data fetch in `startTransition` to "fix INP" (transitions defer renders, not network).
- `setTimeout(fn, 0)` as the yield mechanism where `scheduler.yield()` is available (back-of-queue = worse).
- Claiming an INP cause without the attributed sub-part + LoAF script.
- Filtering / sorting a large list directly in an `onChange` without a transition / debounce.
