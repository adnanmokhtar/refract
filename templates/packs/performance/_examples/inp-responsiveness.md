---
name: inp-responsiveness
description: Pattern — keep per-interaction main-thread work under the INP budget. Diagnose the dominant INP sub-part (input delay / processing / presentation), then break long tasks, defer non-urgent updates, and attribute the blocking script via LoAF.
kind: ai-pattern
pack: performance
---

# Pattern: INP responsiveness

> **Hard rule** — Browser input handlers MUST keep per-interaction main-thread work under the INP budget (good ≤ 200ms at p75). Attribute the dominant sub-part with field data before fixing; a synchronous >50ms handler on a hot interaction is forbidden.

**Where those two numbers come from** — INP "good" is **≤ 200 ms at the 75th percentile** (https://web.dev/articles/inp); a **long task** is "any uninterrupted period where the main UI thread is busy for 50 ms or longer" (https://developer.mozilla.org/en-US/docs/Web/API/PerformanceLongTaskTiming). Neither is this project's SLA — where `ai/runtime/perf-budgets.md` sets a tighter budget, that one wins and is the number to cite.

**Halt conditions / mandatory cites**
- Cite the handler at `<file:line>` + the attributed INP sub-part (`inputDelay` / `processingDuration` / `presentationDelay`) before proposing a fix; "this handler is probably slow" is a halt.
- Cite the blocking script from the Long Animation Frames API (LoAF) — `longAnimationFrameEntries[].scripts[].invoker` / `.sourceURL` — when claiming a specific script blocks the interaction.
- Hand-wave grep ban — never claim "no long tasks" without the LoAF / performance-trace artifact.
- A fix that wraps an *async data fetch* in `startTransition` (transitions are for state updates, not data latency) is a bug — reject.

**When to apply** — `web-vitals-field` attributes a poor INP to a handler/element, or a high-frequency handler (typing/scroll/drag/filter) or expensive click drives an interaction.

**When NOT to apply** — INP already good (≤200ms p75); cost already off-main-thread (Worker); rare admin action.

**Halt / cites** — cite the handler `<file:line>` + the attributed sub-part (`inputDelay`/`processingDuration`/`presentationDelay`); cite the LoAF blocking script (`longAnimationFrameEntries[].scripts[].invoker`/`.sourceURL`). Wrapping an async *data fetch* in `startTransition` is a bug — reject.

## INP = three sub-parts — diagnose first

```
INP = inputDelay + processingDuration + presentationDelay
```

| Dominant | Cause | Fix |
|---|---|---|
| inputDelay | main thread busy at click | break the *other* long tasks (yield, defer hydration) |
| processingDuration | handler does too much sync | `scheduler.yield()`, debounce, Worker |
| presentationDelay | expensive render after handler | `startTransition` / `useDeferredValue`, virtualize, avoid layout thrash |

## Break long tasks

```ts
for (const chunk of chunks) {
  process(chunk);
  if (navigator.scheduling?.isInputPending?.()) await scheduler.yield();  // fallback: setTimeout(r)
}
```

`scheduler.yield()` resumes at the front of the queue (better than `setTimeout(0)`). `requestIdleCallback` for non-urgent work.

## Defer non-urgent updates

```tsx
const [isPending, startTransition] = useTransition();
const onChange = (e) => { setQuery(e.target.value); startTransition(() => setResults(filter(all, e.target.value))); };
// or useDeferredValue(query)
```

React: `useTransition` / `startTransition` / `useDeferredValue`. Vue: batched by default; debounce heavy recomputes. Svelte: keep derivations cheap.

## Attribute the blocking script (LoAF)

```ts
new PerformanceObserver((list) => {
  for (const f of list.getEntries()) for (const s of f.scripts) console.log(s.invoker, s.sourceURL, s.duration);
}).observe({ type: 'long-animation-frame', buffered: true });
```

## Forbidden

- Synchronous handler doing >50ms on a hot interaction (typing/drag/primary click).
- `startTransition` around an async fetch (defers renders, not network).
- `setTimeout(fn, 0)` where `scheduler.yield()` is available.
- Claiming an INP cause without the attributed sub-part + LoAF script.
- Filtering/sorting a large list in `onChange` without a transition / debounce.
