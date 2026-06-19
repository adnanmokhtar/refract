---
description: Web bundle + page-load performance audit. Bundle size, JS execution, rendering, hydration. Reports + targeted fixes per category. (Mobile bundle work lives in mobile/optimize-bundle.)
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

Six axes audited in parallel:

1. **Bundle size** — initial + lazy chunks.
2. **JS execution** — main-thread time during load + interaction.
3. **Critical rendering path** — render-blocking CSS, font-loading strategy.
4. **Hydration** — for SSR/SSG: how long is hydration; is it streaming?
5. **Asset delivery** — image format/size, font subsetting, video preload.
6. **Third-party scripts** — analytics, ads, chat widgets, tag managers.

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

### Web Vitals (current → target)
| Metric | Current | Target | Status |
|---|---|---|---|
| LCP (Largest Contentful Paint) | 3.8s | ≤ 2.5s | ✗ |
| INP (Interaction to Next Paint) | 240ms | ≤ 200ms | ⚠ |
| CLS (Cumulative Layout Shift) | 0.18 | ≤ 0.1 | ✗ |
| TTFB | 650ms | ≤ 600ms | ⚠ |
| Total Blocking Time | 480ms | ≤ 200ms | ✗ |

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
- Hero image: 1.2 MB. Resize to actual viewport size + use the framework's image primitive's priority hint.
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
| 10 | Mark hero image as priority via framework's image primitive | -300ms LCP | 5m |

### Estimated end state (after applying)
- LCP: 3.8s → ≤ 2.0s ✓
- TBT: 480ms → ≤ 150ms ✓
- Initial JS: 420 KB → ≤ 180 KB ✓
- Web-vitals score: ~60 → ~95+

### Out of scope
- SSR vs SSG tradeoff for the marketing pages (architectural decision; ADR needed).
- Adopting a partial-hydration framework (not a single-fix recommendation).
```

## Phase 6 — Validate (after applying)

- Re-run the project's web-vitals profiler on the same network profile.
- Verify Web Vitals hit target on field data (RUM if available).
- Verify no functional regression.
- Re-run bundle analyzer; confirm size delta.
- A/B test if feasible — measure real-user conversion lift.

## Output format

```
## /bundle-perf complete

Pages audited: <list>
Web Vitals (LCP / INP / CLS / TBT): <current> → <target>
Bundle (initial JS): <KB now> → <KB target>
Recommendations: <count>; quick wins (<1h, large impact): <count>

Report: ai/runtime/bundle-perf-<date>.md
```

## Hard rules

- **Measure on a representative network + device.** Localhost on a developer M3 Pro is not the user's experience.
- **One change per PR for >100ms or >50KB optimizations.** Easier to revert.
- **Don't ship un-measured "optimizations."** "I think this helps" is not enough.
- **Web Vitals from field data trumps lab data.** Real users in real conditions are the truth.
- **Image formats: WebP (broad), AVIF (smaller, narrower support).** Serve via picture/srcset.

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
