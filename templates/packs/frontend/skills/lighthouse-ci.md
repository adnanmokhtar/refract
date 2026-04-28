---
name: lighthouse-ci
description: Runs Lighthouse against the dev server with budget enforcement. Blocks regressions in LCP / CLS / TBT / bundle size.
---

# lighthouse-ci

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
5. Stop the preview server when done:
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

## Output

```
Lighthouse CI — /products (mobile, median of 3 runs)

  PASS  LCP             2210ms  (budget 2500)
  PASS  CLS             0.04    (budget 0.1)
  FAIL  TBT             420ms   (budget 300)   regression vs baseline 210ms
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

## False positives / gotchas

- Run against the BUILT artifact, not `pnpm dev`. Dev mode injects HMR + uncompressed source, which inflates TBT and LCP misleadingly.
- Network flake produces a one-shot regression — re-run before blocking.
- Baseline = median of last 10 successful runs. A single fast run isn't a baseline.
- Mobile throttling defaults to "Slow 4G + 4x CPU" — unchanged for years; matches real low-end devices, don't relax it.
- CLS often regresses from font swaps or hero images without `width/height` — verify in the diagnostic, not just the score.
- Skip server-rendered admin pages (no public traffic, no Core Web Vitals to chase). Keep the budget on customer-facing routes.
