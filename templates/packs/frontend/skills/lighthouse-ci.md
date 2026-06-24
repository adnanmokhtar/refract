---
name: lighthouse-ci
description: Runs Lighthouse against the dev server with budget enforcement. Blocks regressions in LCP / CLS / TBT / bundle size.
---

# lighthouse-ci

## Premise

Find real perf regressions, not noise. Every failure cites the metric + measured value + budget + the suspected cause (commit / file / chunk). "Score dropped" without numbers is not a finding. A single run is not a measurement — median of ≥3 runs against the production build, or the result is invalid. Dev-mode runs are forbidden; HMR inflates TBT and LCP misleadingly.

A failed budget without a named cause is unfinished investigation.

Run Lighthouse against the production build, enforce budgets, and detect regressions vs a stored baseline.

## When to use

- Before merging a PR that touches frontend files.
- After upgrading a heavy dep (Vue / Vite / a UI library).
- Weekly in CI to track Core Web Vitals trend.
- Before a marketing campaign that will spike traffic.

## Prerequisites

- Built artifact served locally (NOT `pnpm dev` — HMR mode masks the perf issues you're hunting).
- `@lhci/cli` installed: `pnpm add -D @lhci/cli`.
- A `lighthouserc.json` at repo root with assertions + the URLs to audit.
- Optional: `LHCI_GITHUB_APP_TOKEN` to post results back to GitHub PRs.

## Procedure

1. Build for production:
   ```bash
   pnpm build
   pnpm preview --port 4173 &     # Vite preview, or `nuxi preview`, or `next start`
   sleep 3                         # let server bind
   ```
2. Run Lighthouse on the configured URLs:
   ```bash
   npx lhci autorun --config=./lighthouserc.json
   ```
3. Inspect the generated `.lighthouseci/` directory. Reports are JSON + HTML; `assertions.json` has pass/fail per metric.
4. Compare against stored baseline (median of last N runs) — `lhci`'s `assert` config supports baseline preset:
   ```bash
   npx lhci assert --preset=lighthouse:no-pwa
   ```
5. On a `bf-cache` failure, read the audit's `notRestoredReasons` — it lists the ACTUAL disqualifiers; cite those as the finding, not "bf-cache failed". The hard disqualifier is an `'unload'` (or `'beforeunload'`) listener → fix is to replace it with `'pagehide'` / `'visibilitychange'`. `Cache-Control: no-store` on the document is a WARN/review detector, NOT an error — Chrome rolled bfcache-for-CCNS to ~100% in 2025 where safe, so don't fail the build on it; flag it for review.
6. Stop the preview server when done:
   ```bash
   kill %1
   ```

## Default budgets

```json
{
  "ci": {
    "collect": { "numberOfRuns": 3 },
    "assert": {
      "assertions": {
        "categories:performance":              ["error", { "minScore": 0.9 }],
        "largest-contentful-paint":            ["error", { "maxNumericValue": 2500 }],
        "cumulative-layout-shift":             ["error", { "maxNumericValue": 0.1 }],
        "total-blocking-time":                 ["error", { "maxNumericValue": 300 }],
        "interaction-to-next-paint":           ["warn",  { "maxNumericValue": 200 }],
        "server-response-time":                ["error", { "maxNumericValue": 600 }],
        "bf-cache":                            ["error", {}],
        "first-contentful-paint":              ["warn",  { "maxNumericValue": 1800 }],
        "speed-index":                         ["warn",  { "maxNumericValue": 3400 }],
        "resource-summary:script:size":        ["error", { "maxNumericValue": 307200 }],
        "resource-summary:stylesheet:size":    ["warn",  { "maxNumericValue": 102400 }]
      }
    }
  }
}
```

Customize per-project. Mobile budgets stricter than desktop. Critical-JS budget tighter than total-JS.

Notes on the three additions:
- `interaction-to-next-paint` is the stable audit id (it was historically `experimental-interaction-to-next-paint`; do NOT hard-pin the `experimental-` prefix — let Lighthouse resolve the current id). Kept at `warn` deliberately — see the lab-INP callout below.
- `server-response-time` is the TTFB audit (good ≤ 600ms). Reframe any "TTFB as a share of LCP" guidance as diagnostic prose, NOT an assertion — `lhci` can only assert the single `largest-contentful-paint` numeric audit, not its sub-phases. Do NOT add an LCP-decomposition (resourceLoadDelay / resourceLoadDuration / TTFB-share) assertion or a `bf-cache`-less `interactive` (TTI) assertion — TTI was removed from Lighthouse 10's scored set.
- `bf-cache` asserts back/forward-cache eligibility; the audit reports `notRestoredReasons` (the actual disqualifiers) — see the bf-cache Procedure note.

> **Lab INP is not field INP.** Lighthouse runs ONE page load with no real user interactions, so `interaction-to-next-paint` here is a SYNTHETIC PROXY only — it cannot field-measure real INP. Authoritative INP MUST come from field data (CrUX, or RUM `onINP` via the [web-vitals-field](../../performance/skills/web-vitals-field.md) skill). Treat the lab number as a smoke test, never as the reported INP.

## Output

```
Lighthouse CI — /products (mobile, median of 3 runs)

  PASS  LCP             2210ms  (budget 2500)
  PASS  CLS             0.04    (budget 0.1)
  FAIL  TBT             420ms   (budget 300)   regression vs baseline 210ms
  WARN  INP (lab proxy) 240ms   (budget 200)   synthetic — confirm in field RUM
  PASS  TTFB            410ms    (budget 600)
  FAIL  bf-cache        ineligible             notRestoredReasons: unload listener
  PASS  FCP             1640ms  (budget 1800)
  PASS  performance     0.92    (budget 0.90)

Bundle (resource-summary):
  PASS  JS total        284 KB  (budget 300)
  FAIL  JS critical     162 KB  (budget 150)   12 KB over

Likely cause:
  Recent commit a1b2c3d added `import { Editor } from "tiptap"` to HomePage.
  Move Editor behind a lazy boundary or per-route chunk.

Reports:  .lighthouseci/lhr-1745492045123.html
```

Related: [navigation-speed](navigation-speed.md) (bf-cache disqualifiers + soft-nav prefetch) · [web-vitals-field](../../performance/skills/web-vitals-field.md) (authoritative field INP via CrUX / RUM `onINP`).

## False positives / gotchas

- Run against the BUILT artifact, not `pnpm dev`. Dev mode injects HMR + uncompressed source, which inflates TBT and LCP misleadingly.
- Network flake produces a one-shot regression — re-run before blocking.
- Baseline = median of last 10 successful runs. A single fast run isn't a baseline.
- Mobile throttling defaults to "Slow 4G + 4x CPU" — unchanged for years; matches real low-end devices, don't relax it.
- CLS often regresses from font swaps or hero images without `width/height` — verify in the diagnostic, not just the score.
- Skip server-rendered admin pages (no public traffic, no Core Web Vitals to chase). Keep the budget on customer-facing routes.
- Lighthouse audits ONE page load — it cannot see INP on in-app SPA route changes or post-hydration interactions. The lab `interaction-to-next-paint` proxy says nothing about those; rely on field RUM per route ([web-vitals-field](../../performance/skills/web-vitals-field.md)) for the real INP.

## Halt conditions

- Halt on hand-waves: every regression must cite metric + measured value + budget + likely cause (commit hash / file / chunk).
- Halt if the run targeted `pnpm dev` instead of the built artifact — invalid measurement, re-run.
- Halt if `numberOfRuns < 3` — a single run is noise, not a signal.
- Halt if INP is reported only from lab with no field/RUM source cited — lab INP is not a measurement. Pair it with CrUX or RUM `onINP` ([web-vitals-field](../../performance/skills/web-vitals-field.md)) before claiming an INP value.
- Halt if a budget is relaxed in `lighthouserc.json` to make the build pass — that's masking, not fixing. Relaxation requires an ADR.
