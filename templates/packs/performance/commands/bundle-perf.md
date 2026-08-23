---
description: Web bundle + page-load performance audit. Bundle size, JS execution, rendering, hydration. Reports + targeted fixes per category. (Mobile bundle work lives in mobile/optimize-bundle.)
project_kind: browser   # requires a rendered UI layer; see templates/packs/_project-kind.md
---

# /bundle-perf

> **`--plan` / `--plan-only`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/bundle-perf <pages> --plan` runs the read-only audit phases (1-3 + the Phase 4 report), writes the ranked fixes as a plan to `.claude/plans/`, and exits before applying any fix — execute it later with `/execute-plan <file>`. Honesty clause: a plan-only run still measures real Web Vitals + bundle sizes; it never lists a KB/ms saving without the measured `<before>` behind it.

## The Premise (read this first, internalize, do not deviate)

**The bottleneck is real. The pattern almost always repeats — same import / same query / same render path.** A heavy date library imported in one route is the same heavy import in 14 routes. A render-blocking font declared in the project's root layout is render-blocking on every page that extends it. A client-runtime marker placed on a leaf primitive bloats every parent that imports the primitive. The audit's job is to find ONE concrete bottleneck with measurement, then **scan for the same shape across the rest of the bundle** before reporting.

**The agent's job is exactly this:**
1. Measure the dominant axis (web-vitals profiler / bundle visualizer / coverage / performance flame).
2. Identify the heaviest single contribution with `<file:line>` + KB / ms attribution.
3. **Scan for the same pattern.** `grep` the import, the wrapper prop, the unparallelized await. Count occurrences. Report N — not 1.
4. Propose targeted fixes ranked by impact / effort, citing every site.

**The agent does NOT:**
- Recommend "consider tree-shaking" without naming the bloated module + KB delta.
- Recommend "lazy-load third-party" without naming the script + load timing + KB.
- Skip the similar-pattern scan after finding a hit. **One occurrence is a finding; N occurrences is the actual cost.**
- Ship "I think this helps" without before/after numbers.

**Closure verbs (mandatory per finding):**
- `report-with-fix` — measurement + `<file:line>` + sibling-occurrence count + concrete patch sketch.
- `report-flagged` — measurement confirms hot, but fix needs cross-team / framework upgrade / architectural decision; surfaced for ADR.
- `dismiss` — measured, NOT a real bottleneck against budget; documented so the next audit doesn't re-flag it.

**Mechanical halt (similar-pattern scan accounting):**

Before writing the report, the agent MUST resolve this equation for every finding class:

```
N_found  ==  N_fixed  +  N_explained  +  N_followup
```

- `N_found` — every site where the bottleneck pattern (import / wrapper / await / asset / script tag) appears in the codebase.
- `N_fixed` — sites the report's targeted fixes actually cover.
- `N_explained` — sites legitimately exempt (e.g., admin-only route, behind a feature flag, dev-only).
- `N_followup` — sites parked to a follow-up ticket with rationale.

If the equation does not balance, HALT and re-scan. **Hand-wave grep ("there's probably more like this") is forbidden** — every count is an actual occurrence list.

**Lightweight default:** if the audit finds < 3 sites for a pattern AND the total impact is < 50 KB / 100 ms, dispatch closure-verb `dismiss` and skip the full report section — note in `Out of scope`. Don't bloat the report with sub-budget findings.

Web frontend perf focused on bundle + initial render. Use when:
- The project's web-vitals profiler reports Performance score < 90.
- LCP > 2.5s on 4G.
- Bundle CI budget exceeded.
- Pre-launch optimization pass.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only audit + fix proposals).

## When to use / NOT to use

- USE: any web frontend (regardless of framework — meta-framework, SPA, MPA, SSG).
- USE: pre-release optimization on a public-facing site.
- USE: page-load budget regressed.
- NOT: mobile native bundle → use `mobile/optimize-bundle`.
- NOT: server response time → use `profile-perf`.
- NOT: per-component runtime perf → use the framework's dev-tools profiler.

## Phase 1 — Understand

Confirm:
- Pages/routes in scope (list, or "everything").
- Target devices (default: mid-tier mobile + 4G).
- Current web-vitals baseline.
- Current bundle size (initial JS / CSS / total transferred).

## Phase 2 — Organize

Seven axes audited in parallel:

1. **Bundle size** — initial + lazy chunks.
2. **JS execution** — main-thread time during load + interaction.
3. **Critical rendering path** — render-blocking CSS, font-loading strategy.
4. **Hydration** — for SSR/SSG: how long is hydration; is it streaming? **TTFB branch:** if `TTFB > 600ms` AND the wait is SSR server-think-time (the server is blocked computing the document — serial data fetches, un-awaited-in-parallel queries — not network/DNS/CDN), shrinking JS will NOT move it; route to the [`streaming-ssr`](../../frontend/skills/streaming-ssr/SKILL.md) skill (parallelize the queries, wrap slow regions in a Suspense boundary, enable PPR) instead of bundle/asset fixes. Distinguish the two TTFB owners so they don't fight over the same finding: **SSR server-think-time** (the framework's own render is slow) → `streaming-ssr`; **backend endpoint latency** (the document is fast but a downstream API/DB call it awaits is slow) → [`profile-perf`](./profile-perf.md). A bundle/asset fix addresses neither.
5. **Asset delivery** — image format/size, font subsetting, video preload.
6. **Third-party scripts** — analytics, ads, chat widgets, tag managers.
7. **Navigation timing** — measure the navigation itself, not just the cold load. **Hard nav:** read `PerformanceNavigationTiming` (the `navigation` entry — `responseStart`, `domContentLoadedEventEnd`, `loadEventEnd`). **Soft / SPA nav:** the soft-navigation heuristic (where available — emerging / origin-trial, never a stable cross-browser guarantee) OR a wrapping `performance.mark` straddling the router's start/end events (mark before the route transition fires, measure to the next paint). Detector: a router guard / `beforeEach` hook doing synchronous heavy work, or a route component awaiting **all** its data before it renders anything (no streaming / no Suspense boundary) — cite `<file:line>`. See the [`navigation-speed`](../../frontend/skills/navigation-speed/SKILL.md) skill for the prefetch / Speculation Rules / bfcache / View-Transitions follow-up.

## Phase 3 — Retrieve

Tools:
- **Web-vitals profiler** (browser dev-tools or a CI integration like Lighthouse CI / Calibre / SpeedCurve) — overall + per-category.
- **WebPageTest** or equivalent — real-network simulation.
- **Bundle visualizers** — the bundler's native analyzer (webpack-bundle-analyzer for webpack, the Rollup visualizer for Rollup-based bundlers, esbuild metafile, the framework's bundle-analyzer plugin).
- **Coverage panel** in browser dev-tools — unused CSS / JS percentage.
- **Performance panel** in browser dev-tools — flame chart of load.
- **The framework's dev-tools** for component-level profiling.

Read project's:
- The project's framework / bundler config files (per the project's stack).
- The project's TS / module-resolution config.
- CDN / image-optimization config.

## Phase 4 — Generate (the report)

```
## Bundle + page-load audit — <date>

### Subject
- Pages audited: <list>
- Target: 4G mid-tier mobile (Lighthouse mobile profile)

> **Everything in this report block is an illustrative SHAPE, not a result.** The numbers below show what a populated report looks like; they are not defaults, expected values, or a starting point to adjust. Every cell in a real run is transcribed from the analyzer, the profiler, or the field data — and any cell that has no such source prints `SKIPPED [no-harness]` naming the tool that would fill it. A confidently-populated table for a run that never executed the analyzer is the single most damaging output this command can produce, because it is indistinguishable from a real one.

### Web Vitals (current → target)
| Metric | Current | Target | Status |
|---|---|---|---|
| LCP (Largest Contentful Paint) | 3.8s | ≤ 2.5s | ✗ |
| INP (Interaction to Next Paint) | 240ms | ≤ 200ms | ⚠ |
| CLS (Cumulative Layout Shift) | 0.18 | ≤ 0.1 | ✗ |
| TTFB | 650ms | ≤ 600ms | ⚠ |
| Total Blocking Time | 480ms | ≤ 200ms | ✗ |
| Soft navigation (route-change → next paint) | 720ms | ≤ 500ms | ✗ |

> **INP attribution (don't stop at the number).** A failing INP is not a reportable finding until it names a cause: attribute it to the longest **Long Animation Frame** (LoAF) script in the interaction and cite the handler `<file:line>` — e.g. *"INP 240ms — longest LoAF is the `onSearchInput` handler doing a synchronous filter over 4k rows at `components/SearchBox.tsx:48`"*, not bare *"INP 240ms"*. Lighthouse lab CANNOT field-measure INP (its interaction-to-next-paint audit is a synthetic proxy) — authoritative INP comes from the field via [`web-vitals-field`](../skills/web-vitals-field/SKILL.md) (CrUX / RUM `onINP`, whose attribution carries `inputDelay`, `processingDuration`, `presentationDelay`, `interactionTarget`, `longAnimationFrameEntries`). Route the INP-cause fix to the [`inp-responsiveness`](../ai-patterns/inp-responsiveness.md) pattern (yield / break up the long task / move work off the input handler).

### Bundle inventory
- Initial JS:           420 KB (target: ≤ 200 KB)
- Initial CSS:          85 KB (target: ≤ 50 KB)
- Lazy chunks:          12 chunks, avg 80 KB
- Images on first paint: 1.8 MB (target: ≤ 800 KB)

### JS — heaviest modules (initial bundle, illustrative)
| Module | Size | Notes |
|---|---|---|
| heavy date library (moment-class) | 165 KB | Replace with the platform's built-in Intl or a tree-shaken alternative |
| SDK imported wholesale | 90 KB | Use modular / namespaced imports |
| icon-library (full) | 60 KB | Tree-shake |
| utility library imported as default | 40 KB | Switch to ESM build + selective named imports |

### CSS — unused
Coverage tool reports 62% of CSS unused on first paint. Likely candidates:
- Atomic CSS framework without its purge / JIT pipeline — every utility class shipped.
- Component library shipping ALL component CSS even when most aren't used.

### Critical rendering path issues
- Render-blocking stylesheets in `<head>`.
- Web fonts loading from external origin without preconnect / preload — FOIT visible.
- `<script>` tags in `<body>` without `defer` / `async`.

### Hydration (any meta-framework with SSR / SSG)
- Hydration time: 850ms.
- All routes hydrate even when only the homepage is visible.
- Client-runtime markers too aggressive — many components marked client-only that are leaf primitives and could render server-side.

### Asset delivery
- Images: PNGs without modern-format variants. Re-encode to AVIF/WebP → ~60% reduction.
- Hero image: 1.2 MB. Resize to actual viewport size + use the framework's image primitive's priority hint — anchor the exact API to `references/<framework>.md § Core Web Vitals / Images` (which `priority` / `fetchpriority` / `loading=eager` knob the framework exposes, and what `<link rel=preload>` it does or does NOT emit) rather than asserting a generic behaviour. Cross-ref the [`lcp-audit`](../../frontend/skills/lcp-audit/SKILL.md) skill for the full LCP-resource priority-hint scan.
- 1 video preloads on every page (1.8 MB) — defer to user interaction.
- Fonts: full font family (4 weights × 2 styles = 8 files). Use only weights actually used (typically 400 + 600).

### Third-party scripts (illustrative)
- Tag manager: 70 KB before any tag fires. Lazy-load on scroll-depth or short timeout.
- Chat widget: 200 KB; loads on page load. Move to lazy-load on user click ("Need help?").
- Session-replay tool: 90 KB. Lazy or sample a subset of sessions only.

### Targeted fixes (ranked by impact / effort)

| # | Fix | Impact | Effort |
|---|---|---|---|
| 1 | Lazy-load chat + session-replay tooling | -290 KB JS, -800ms TBT | 2h |
| 2 | Replace heavy date library | -160 KB JS | 2-4h (refactor) |
| 3 | Tree-shake icons + SDK | -120 KB JS | 1-2h |
| 4 | Atomic CSS purge / JIT pipeline | -50 KB CSS | 1h (config) |
| 5 | Re-encode images to WebP/AVIF | -700 KB assets | 1h (build script) |
| 6 | Demote leaf primitives from client to server runtime | -150ms hydration | 2-3h |
| 7 | Subset fonts | -180 KB | 30m |
| 8 | Preconnect + preload critical font | -200ms LCP | 15m |
| 9 | Defer tag manager until scroll-depth = 30% | -300ms TBT | 30m |
| 10 | Mark hero image as priority via framework's image primitive (exact knob per `references/<framework>.md § Core Web Vitals / Images`; verify the emitted hint with [`lcp-audit`](../../frontend/skills/lcp-audit/SKILL.md)) | -300ms LCP | 5m |

### Projected end state — PROJECTION, not a measurement
Every line here is arithmetic over the fixes table, carrying `~` and the `PROJECTED` label until Phase 6 replaces it with a re-measured number. A projection that survives into the final report unlabelled has been laundered into a result.
- LCP: <before> → ~<projected> `PROJECTED`
- TBT: <before> → ~<projected> `PROJECTED`
- Initial JS: <before> → ~<projected> `PROJECTED`

### Out of scope
- SSR vs SSG tradeoff for the marketing pages (architectural decision; ADR needed).
- Adopting a partial-hydration framework (not a single-fix recommendation).
```

## Phase 6 — Validate (the production-grade gate — measured, not asserted)

A bundle change is **production-grade only when the after-number came out of the same tool that produced the before-number, lands at or under its budget, and cost nothing on the neighbour metrics.** This is `/perf-audit` Phase 6's gate applied to the browser; the two commands answer the same question and must not hold different standards for it.

**The four gates, per applied fix:**

1. **Measured, not asserted.** The `<after>` is a number from the SAME harness as the `<before>` — same analyzer, same network + device profile, same route set. An adjective ("lighter", "snappier", "much faster") in a number column FAILS the gate. `[self-policed]`: the smell test is `grep -inE '(faster|snappier|lighter|smoother|should be|feels)'` over the `Before`/`After` cells of the report; any hit is an unmeasured claim → convert to a number or mark it SKIPPED.
   - **No harness for this metric?** Mark the row `SKIPPED [no-harness]` and name what would fill it ("no bundle analyzer configured for this build"; "no RUM, so field LCP cannot be confirmed"). Never fake a pass; never let a `PROJECTED` value stand in the `After` column.
2. **Beats the budget, not just the before.** Each metric lands at or under its stated budget (the targets column, or `ai/runtime/perf-budgets.md`). Smaller-than-before but still over budget is `INCOMPLETE — over budget (<after> vs <budget>)`. Where no budget exists, stating one is the first deliverable.
3. **No guardrail regression.** Re-measure what the fix could have cost, not only what it improved: a bundle split trades bytes for round-trips; lazy-loading a widget can move work into the interaction and raise INP; font subsetting can reintroduce FOIT; image re-encoding can raise decode time on low-end devices. Any guardrail worse beyond the measured noise band → `INCOMPLETE — regressed <metric>`, HALT.
4. **Field-confirmed where the metric is field-only.** **INP is not lab-measurable** — Lighthouse scripts one synthetic interaction, so a lab INP delta is not evidence. An INP claim is confirmed from the field (`web-vitals-field`, CrUX/RUM p75) or it is `SKIPPED [field-data-unavailable]`. LCP and CLS may be gated in the lab but their field p75 is the truth; where the two disagree, the field wins and the lab number is reported as lab.

**Terminal verdict.** `PRODUCTION-GRADE` only when every applied fix is PASS or honestly `SKIPPED`, with zero adjectives and zero `PROJECTED` values left in a number column. Otherwise `INCOMPLETE`, naming every unmet item. Also verify no functional regression — a smaller bundle that broke a runtime-loaded icon is not a win.

## Output format

```
## /bundle-perf — <N> fixes — <PRODUCTION-GRADE | INCOMPLETE | PLAN>

Pages audited: <list>
Harness: <analyzer> / <profiler> / <field source, or "no RUM">
Noise band: ±<n>% (<N> baseline re-runs) — deltas inside it are NO-CHANGE

Web Vitals (measured before → measured after, or SKIPPED [no-harness]):
  LCP  <before> → <after>  (budget <n>)  <PASS | INCOMPLETE — over budget | SKIPPED [...]>
  INP  <before> → <after>  (budget <n>)  <field p75 | SKIPPED [field-data-unavailable]>
  CLS  <before> → <after>  (budget <n>)  <...>
Bundle (initial JS): <before KB> → <after KB> (budget <n> KB)  <...>

Status: PRODUCTION-GRADE     # every applied fix measured, at/under budget, guardrails clean
  # OR
Status: INCOMPLETE — <unmet items named>
  # OR
Status: PLAN — proposals only, nothing applied; every value PROJECTED [pre-apply]

Report: ai/runtime/bundle-perf-<date>.md
```

A bare `complete` is never a valid terminal status here — the reader must be able to tell *measured and under budget* from *the analyzer never ran*, and those two produce identically-shaped reports.

## Hard rules

- **Measure on a representative network + device.** Localhost on a developer M3 Pro is not the user's experience.
- **One change per PR for >100ms or >50KB optimizations.** Easier to revert.
- **Don't ship un-measured "optimizations."** "I think this helps" is not enough — and neither is a projection. A `PROJECTED` value that reaches the final report without being re-measured has become a fabricated result.
- **Web Vitals from field data trumps lab data.** Real users in real conditions are the truth.
- **Image formats: AVIF first, WebP as the fallback rung.** AVIF is no longer the narrow-support option — ~95% global, Chrome 85+, Firefox 93+, Safari 16.4+, Edge 121+ (https://caniuse.com/avif). Serve via `<picture>`/`srcset` so the long tail still gets WebP/JPEG; check the *project's* stated browser-support floor before dropping a rung.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the ranked fixes re-expressed as ONE ordered, numbered to-do — **ordered by measured savings**, not severity: **BIGGEST SAVINGS** (the largest KB / LCP / TBT wins first) → **SMALLER** → **MARGINAL** — each step carrying the resource + `<file:line>` (the heavy module / asset / script tag) + **Fix** (concrete — the named replacement / lazy-load / purge / re-encode) + **Verify** (the measured delta: re-run the web-vitals profiler + bundle analyzer and confirm the `<before> → <after>` KB / ms it claimed). Drop any line whose saving is below the lightweight `< 50 KB / 100 ms` budget into OPTIONAL or `Out of scope` — never above a real win. Close with: re-run `/bundle-perf` on the same network + device profile to confirm Web Vitals hit target, `/learn-from-task`, then ship one change per PR. A clean run collapses to a single line ("Within budget — no fixes above threshold"). The reader must never re-rank the fixes table themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Replaced a heavy date library but missed one timezone call in a deep code path → date wrong on holidays.
- Lazy-loaded a third-party widget but the conversion-tracking pixel was inside it → analytics broken.
- Tree-shook icons; missed a runtime-loaded icon name → blank icon in production.
- LCP improvement on lab measurement was real but field LCP barely moved (hosting / DNS / CDN dominated).
- Made initial bundle smaller but lazy chunks now too granular → many extra round trips.

## Related

- `mobile/optimize-bundle` — mobile-native counterpart; this command is for web.
- `profile-perf` — server-side performance counterpart.
- `@performance-optimizer` — broader perf agent.
- `caching-strategy` pattern — applies when this surfaces unnecessary refetches.
- `lazy-loading` pattern — formal pattern for deferred-load.
