---
name: inp-responsiveness
description: Pattern — keep per-interaction main-thread work under the INP budget. Diagnose the dominant INP sub-part (input delay / processing / presentation), then break long tasks, defer non-urgent updates, and attribute the blocking script via LoAF.
kind: ai-pattern
pack: performance
project_kind: browser   # requires a rendered UI layer; see templates/packs/_project-kind.md
---

# Pattern: INP responsiveness

> **Hard rule** — Browser input handlers MUST keep per-interaction main-thread work under the INP budget (good ≤ 200ms at p75). Before fixing, attribute the dominant sub-part with field data — never guess. A long task that blocks the main thread during an interaction MUST be broken up or deferred; shipping a synchronous >50ms handler on a hot interaction is forbidden.

**Where those two numbers come from** — INP "good" is **≤ 200 ms at the 75th percentile** (https://web.dev/articles/inp); a **long task** is "any uninterrupted period where the main UI thread is busy for 50 ms or longer" (https://developer.mozilla.org/en-US/docs/Web/API/PerformanceLongTaskTiming). Neither is this project's SLA — where `ai/runtime/perf-budgets.md` sets a tighter budget, that one wins and is the number to cite.

**When to apply**
- `web-vitals-field` attributes a poor INP to a specific handler / element, OR `/bundle-perf`'s class ledger flags INP.
- A high-frequency handler (typing, scrolling, dragging, filtering a large list) drives an interaction.
- A click triggers an expensive synchronous recompute / large re-render before the next paint.

**When NOT to apply**
- INP is already good (≤200ms p75) — don't pre-optimize handlers that aren't on the critical interaction path.
- The cost is in a Web Worker / off the main thread already (yielding won't help; it's not blocking paint).
- A one-off interaction (rare admin action) where responsiveness isn't user-facing.

**Halt conditions / mandatory cites**
- Cite the handler at `<file:line>` + the attributed INP sub-part (`inputDelay` / `processingDuration` / `presentationDelay`) before proposing a fix; "this handler is probably slow" is a halt. Without field data the candidate is **Unconfirmed**, listed with the probe that settles it (§ Detectors).
- Cite the blocking script from the Long Animation Frames API (LoAF) — `longAnimationFrameEntries[].scripts[].invoker` / `.sourceURL` — when claiming a specific script blocks the interaction.
- Hand-wave grep ban — never claim "no long tasks" without the LoAF / performance-trace artifact, and never "no INP risk" without the § Detectors coverage block.
- A candidate becomes a finding only through [`refute-before-report.md`](../../../snippets/refute-before-report.md); the agent that found it never clears it.
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

Update what the user sees first, then yield between chunks so the browser can paint. Yield **whether or not input is pending**: `navigator.scheduling.isInputPending()` is no longer recommended (web.dev, *Optimize long tasks*, updated 2024-12-19) — it gives false negatives and ignores animations. `scheduler.yield()` ships in Chrome and Edge 129+ and Firefox 142+ but not Safari, so the fallback is mandatory and must run, not live in a comment:

```js
const yieldToMain = () =>
  globalThis.scheduler?.yield?.() ?? new Promise(r => setTimeout(r, 0));
```

```ts
async function handleClick() {
  showPending();                        // the visible response first
  for (const chunk of chunks) {
    process(chunk);
    await yieldToMain();               // every chunk, not only when input waits
  }
}
```

- `scheduler.yield()` — yields then continues at the *front* of the queue (better than `setTimeout(0)`, which goes to the back). That ordering difference is the whole reason to prefer it: a `setTimeout` yield can put your continuation behind every other queued task.
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
      console.log(script.invoker, script.sourceURL, script.duration, script.forcedStyleAndLayoutDuration);
    }
  }
}).observe({ type: 'long-animation-frame', buffered: true });
```

The Long Animation Frames API names the script (`invoker`, `sourceURL`) responsible for a long frame — that's the citeable culprit, not "something is slow."

## Avoid synchronous layout thrash

Reading layout (`offsetWidth`, `getBoundingClientRect`) right after writing to the DOM forces a synchronous reflow inside the handler. Batch reads then writes (or use `requestAnimationFrame`) so a hot handler doesn't thrash layout per element.

## Detectors

**Who owns which INP cause.** This pattern owns §1–§4 below. The other causes have owners elsewhere; a run cites them by name and prints `N/A (owner pack <x> not installed)` for an absent pack rather than re-deriving them.

| INP cause | Owner |
|---|---|
| Input delay from JS parsed and run at load | `bundle-analyze` + `code-splitting` detectors 1, 2, 5 *(frontend pack, when installed)* |
| Input delay during hydration | `ssr-audit` § Client-boundary cost, `streaming-ssr` §1 *(frontend pack, when installed)* |
| DOM size: unvirtualized lists, grids, infinite scroll | `list-virtualization` detectors 1–3; index keys on windowed rows: detector 4 *(frontend pack, when installed)* |
| Render storm from a high-frequency stream | `realtime-client` detector 6 *(frontend pack, when installed)* |
| Third-party long tasks | `critical-path-scan` §2 *(frontend pack, when installed)* |
| Animating layout or paint properties | `motion-audit` § 2 *(ui-ux pack, when installed)* |
| The field oracle for every row | `web-vitals-field` § Attribution fields (this pack) |

**Pre-flight (one script, run from the repo root).** `ROOTS` keeps the scan on the UI packages; server code with an `onSale` variable is not a handler.

```bash
ROOTS=( $(rg -l --pcre2 '"(?:react|react-dom|vue|svelte|@angular/core|solid-js|preact|astro)"\s*:' -g '**/package.json' -g '!**/node_modules/**' . | xargs -n1 dirname | sort -u) ); [ ${#ROOTS[@]} -eq 0 ] && ROOTS=(.)
FX=(-g '!**/node_modules/**' -g '!**/{dist,build,out,.next,.nuxt,.output,.svelte-kit,.angular,coverage,storybook-static}/**'
    -g '!**/{test,tests,__tests__,__mocks__,mocks,e2e,fixtures,__fixtures__,scripts,tools,playwright,cypress}/**'
    -g '!**/*.{test,spec,stories,story}.*' -g '!*.{md,mdx,snap,map}' -g '!**/{locales,locale,i18n,translations}/**' -g '!**/docs/**' -g '!**/*.min.*')
UI=(-g '*.{js,jsx,ts,tsx,mjs,vue,svelte,astro,html}')
# 0 context: React Compiler (gate for §3), a yield primitive anywhere
rg -n --no-heading 'babel-plugin-react-compiler|reactCompiler' -g '**/package.json' -g '**/{next,vite,babel,rsbuild}.config.*' -g '!**/node_modules/**' "${ROOTS[@]}"
rg -l 'scheduler\.yield|yieldToMain|requestIdleCallback|scheduler\.postTask' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
# 1a inline handler doing collection work; 1b named handler whose first lines sort / reduce / parse / clone
rg -n --no-heading --pcre2 '\bon(?:Click|Change|Input|Submit|KeyDown|KeyUp|Drop|Paste)\s*=\s*\{[^}\n]*(?:\.(?:sort|toSorted|filter|reduce)\(|\bJSON\.parse\(|\bstructuredClone\()|@(?:click|input|change|submit|keyup)="[^"]*\.(?:sort|filter|reduce)\(' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
rg -n -U --pcre2 --max-columns 160 '\b(?:(?:const|let)\s+(?:handle|on)[A-Z]\w*\s*=\s*(?:useCallback\(\s*)?(?:async\s*)?(?:\([^)\n]*\)|\w+)\s*=>|function\s+(?:handle|on)[A-Z]\w*\s*\()[^\n]*\n(?:[^\n]*\n){0,10}?[^\n]*(?:\.(?:sort|toSorted|reduce)\(|\bJSON\.parse\(|\bstructuredClone\()' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
# 1c files where a text input sets query state, the file filters or sorts, and nothing defers it
comm -23 <(rg -l --pcre2 '\bset\w*(?:Query|Search|Filter|Term|Keyword)\w*\(\s*(?:e|ev|event)\.(?:target|currentTarget)\.value' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}" | sort) \
         <(rg -l 'useDeferredValue|useTransition|startTransition|debounce|throttle' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}" | sort) |
  while read -r f; do rg -l --pcre2 '\.(?:filter|sort|toSorted)\(' "$f"; done
# 2a style write then a geometry read within 3 lines; 2b geometry read inside a loop; 2c files with scroll / resize / pointer handlers
rg -n -U --pcre2 '\.style\.\w+\s*=[^\n]*\n(?:[^\n]*\n){0,3}?[^\n]*\b(?:offset(?:Width|Height|Top|Left)|client(?:Width|Height)|scroll(?:Top|Height|Width)|getBoundingClientRect|getComputedStyle)\b' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
rg -n -U --pcre2 '(?:\bfor\s*\(|\bwhile\s*\(|\.forEach\(|\.map\()[^\n]*\n?(?:[^\n]*\n){0,3}?[^\n]*\b(?:getBoundingClientRect|getComputedStyle|offset(?:Width|Height|Top|Left))\b' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
rg -l --pcre2 'addEventListener\(\s*["\x27](?:scroll|resize|wheel|pointermove|mousemove)["\x27]|\bon(?:Scroll|Wheel|PointerMove|MouseMove)\s*=' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
# 3a context value built inline; 3b whole-state selectors (Redux identity, or a zustand store called with no selector)
rg -n --no-heading --pcre2 '<\w+(?:\.Provider|Context)\s+value=\{\s*[\{\[]' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
ST=$(rg -o --no-filename --pcre2 '\b(use[A-Z]\w*)\s*=\s*create(?:WithEqualityFn)?\s*(?:<[^>]*>)?\s*\(' -r '$1' "${UI[@]}" "${FX[@]}" "${ROOTS[@]}" | sort -u | paste -sd'|' -)
rg -n --no-heading --pcre2 "\\buseSelector\\(\\s*\\(?\\s*(\\w+)\\s*\\)?\\s*=>\\s*\\1\\s*\\)${ST:+|\\b(?:$ST)\\(\\s*\\)}" "${UI[@]}" "${FX[@]}" "${ROOTS[@]}"
# 4a Vue: deep watchers, third-party instances made reactive, method calls in templates; 4b Angular; 4c Svelte 5
rg -n --no-heading --pcre2 '\bdeep:\s*true\b|\b(?:ref|reactive)\(\s*new\s+(?:Chart|mapboxgl\.Map|L\.map|THREE\.\w+)|\{\{\s*\w+\([^)]*\)\s*\}\}' -g '*.{vue,ts,js}' "${FX[@]}" "${ROOTS[@]}"
rg -n --no-heading --pcre2 '@for\s*\([^)]*track\s+\$index|\bpure\s*:\s*false\b|ChangeDetectionStrategy\.(?:Default|Eager)\b' -g '*.{ts,html}' "${FX[@]}" "${ROOTS[@]}"
rg -n -U --pcre2 '\$effect\(\s*\(\)\s*=>\s*\{\s*\w+\s*=' -g '*.svelte' "${FX[@]}" "${ROOTS[@]}"
```

### 1. Long synchronous work in an interaction handler

`BAD:` `onChange={(e) => setRows(all.filter(r => r.name.includes(e.target.value)))}` over every row on every keystroke. `GOOD:` the input stays urgent and the list update is a transition (`startTransition` / `useDeferredValue`), or the work is chunked with `yieldToMain()`, or it moves to a Worker.

**Read the code:** How many items does the work touch in production — the API's page size, an "all" endpoint, a store that accumulates? Does it run in the handler, or in the render the handler triggers? Is the interaction frequent (typing, drag, a primary click) or rare? Is a transition, deferred value, debounce, Worker or server-side filter already on the path? **Finding when** field attribution names this handler's element with `processingDuration` dominant, or the work grows with data on a hot interaction and the lab trace confirms it; static evidence alone is **Unconfirmed**. **Severity:** High when a field p75 INP > 200 ms is attributed to it; Medium when lab processing exceeds 100 ms at 4× CPU on a production build; else Low. **Proof:** field — `onINP` attribution (`interactionTarget`, `processingDuration`, `longAnimationFrameEntries`); lab — a DevTools trace at 4× CPU, or Chrome DevTools MCP `performance_start_trace` then `performance_analyze_insight` `INPBreakdown`; fix test (run-invariant) — stub the yield helper, run the handler over N = 10,000 items and assert it yields at least `ceil(N / chunk)` times (0 before the fix).

### 2. Forced synchronous layout (layout thrash)

`BAD:` `items.forEach(el => { el.style.width = w + 'px'; total += el.getBoundingClientRect().height; })` — every read after a write forces a layout. `GOOD:` read every value first, then write; or `requestAnimationFrame` for the writes; or `ResizeObserver` / `IntersectionObserver` instead of reads in scroll handlers.

**Read the code:** Is a DOM write followed by a geometry read in the same task — the same loop iteration, the same handler? Reads batched before any write are fine. Is the path an interaction, scroll or resize, or one-off initialisation? How many elements does the loop touch? **Finding when** an interleaved write→read sits on an interaction or scroll path and the trace shows it. **Severity:** High when forced layout exceeds 30 ms inside an INP-attributed frame; Medium on scroll or resize paths; Low at initialisation. **Proof:** LoAF `scripts[].forcedStyleAndLayoutDuration` > 0 on the interaction's frame (Chromium); the DevTools `ForcedReflow` insight; after the fix both read 0 for that script.

### 3. Re-render storms (React)

`BAD:` `<Ctx.Provider value={{ user, cart }}>` at the root re-renders every consumer on any parent render; `useStore()` with no selector re-renders on every store change. `GOOD:` a memoised or split context value; a selector per field (`useStore(s => s.count)`, `useShallow` for objects; Redux `shallowEqual`).

**Version gate first:** with React Compiler 1.0 on (`babel-plugin-react-compiler`, Next `reactCompiler: true`), inline objects and missing memo are not findings unless the component opts out with `'use no memo'` (`precedents/performance.md` § 59). Whole-store selectors are still candidates. **Read the code:** How often does the value change — on every keystroke? How many consumers, and how heavy is each subtree? **Finding when** a render-count test proves extra commits on an unrelated update **and** the cost shows (an INP-attributed React commit, or lab commits > 16 ms on typing or drag). **Severity:** High when INP points at a commit > 100 ms at 4× CPU; Medium for > 16 ms commits on typing or drag; else Hardening. **Proof:** render-count test — a child `vi.fn()` (or `<Profiler onRender>` commit count) is unchanged after an unrelated parent update; it fails first. Production profiling needs the `react-dom/profiling` build.

### 4. Framework reactivity overhead (Vue, Angular, Svelte)

`BAD:` Vue `watch(bigTree, cb, { deep: true })`, `ref(new Chart(…))`, `{{ total(order) }}` in a template; Angular `@for (… ; track $index)` on mutable data, `pure: false` pipes, explicit `ChangeDetectionStrategy.Default` / `Eager`; Svelte `$effect(() => { total = … })` doing a derivation. `GOOD:` `shallowRef` / `markRaw` for third-party instances and `computed` in templates; a stable `track` key and pure pipes; `$derived` for derived values and `$state.raw` for large data replaced wholesale.

**Version gate:** Angular ≥ 21 is zoneless with signals by default and ≥ 22 makes OnPush the default, so missing `trackBy` or OnPush is not a finding there; an explicit `Eager` is (`precedents/performance.md` § 65). **Read the code:** How large is the watched or rendered structure, and does the work run per keystroke or scroll? **Finding when** INP is attributed to the component or a measured change-detection cycle exceeds 50 ms while typing or scrolling; otherwise Hardening. **Proof:** Vue `app.config.performance = true` marks or the Vue DevTools timeline; Angular DevTools profiler cycles per interaction; a trace's processing time for Svelte; then field INP.

### Output, coverage and scale

```
src/pages/SearchPage.tsx:48  INP §1 long handler  [report-with-fix]  High
  onChange sets the query and the render filters 4,200 rows on every keystroke; no transition.
  Proof: field p75 INP 340 ms · interactionTarget input#q · processingDuration 280 ms (web-vitals-field, 28 days).
  Fix: keep setQuery urgent; startTransition(() => setResults(filter(all, q))) or useDeferredValue(q).
src/ui/Tabs.tsx:112  INP §2 forced layout  [report-flagged]  Medium — Unconfirmed
  Width written then offsetWidth read per tab inside a resize handler. Probe: LoAF forcedStyleAndLayoutDuration on resize.
INP detectors: §1 checked (22 files → 1 finding, 3 unconfirmed) · §2 checked (6 hits → 0, 1 unconfirmed) · §3 checked (1 hit → 0; React Compiler off) · §4 N/A (no Vue, Angular or Svelte files)
```

The block is a shape; every number in a real run comes from a tool. Every run ends with the coverage line, one entry per § as `checked (k hits → m findings)` / `N/A (<reason>)` / `blocked (<reason>)`. **Thousands of hits** (a large app): group by component and pattern, rank by route traffic and interaction frequency (typing and drag first), read the top 30 groups fully, and list the rest as `Live, unreviewed (k groups / n hits)` with the command that continues them — never `checked`.

## Forbidden

- A synchronous handler that does >50ms of work on a hot interaction (typing, dragging, primary click).
- Wrapping an async data fetch in `startTransition` to "fix INP" (transitions defer renders, not network).
- `setTimeout(fn, 0)` as the yield mechanism where `scheduler.yield()` is available (back-of-queue = worse) — and `scheduler.yield()` with no fallback, which throws on Safari.
- Gating yields on `isInputPending()`.
- Claiming an INP cause without the attributed sub-part + LoAF script.
- Filtering / sorting a large list directly in an `onChange` without a transition / debounce.
