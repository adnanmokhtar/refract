---
name: lighthouse-ci
description: Lighthouse CI on the production build — 5-run median budgets, regression attribution, routes each failed metric to its scanner. Lab only; no INP.
---

# lighthouse-ci

Run Lighthouse against the production build, enforce budgets, and detect regressions vs a stored baseline.

## When to use

- Before merging a PR that touches frontend files.
- After upgrading a heavy dep (Vue / Vite / a UI library).
- Weekly in CI to track Core Web Vitals trend.
- Before a marketing campaign that will spike traffic.

## Premise

Find real perf regressions, not noise. Every failure cites the metric + measured value + budget + the suspected cause (commit / file / chunk). "Score dropped" without numbers is not a finding. A single run is not a measurement — median of ≥3 runs against the production build, or the result is invalid. Dev-mode runs are forbidden; HMR inflates TBT and LCP misleadingly.

A failed budget without a named cause is unfinished investigation — and naming it is a procedure step, not an act of intuition.

**This skill is also the pack's performance front door.** Eight of this pack's skills are performance scanners; this is the only one that measures, so it decides which of the other seven to run and in what order. See § Triage routing.

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
4. Compare against the baseline. `lhci assert` checks the absolute budgets on the median run; a `--preset` only seeds default assertions and is not a baseline. A relative regression needs a stored series (the LHCI server's compare view, or § Baseline registration in the source skill); without one, say `baseline: none`.
5. Stop the preview server when done:
   ```bash
   kill %1
   ```
6. **Attribute the regression.** The Output block and the Halt conditions require a likely cause; steps 1-5 build, run and compare, so this step is where the cause comes from. Strongest source first, stop at the first that answers: **(a) the chunk** — a script-size or TBT jump is a bundle question, so run `bundle-analyze` and take its named chunk + anchoring import; **(b) the diff since the baseline** — `git log --oneline "$BASELINE_SHA..HEAD" -- src/ package.json` plus `git diff --stat "$BASELINE_SHA..HEAD" -- package.json`, since a dependency bump is the most common single cause (store `$BASELINE_SHA` beside the baseline or nothing can be attributed later); **(c) bisect the assertion** — re-run step 2 against the midpoint build. All three empty → report `likely cause: unattributed (<N> candidate commits in <sha>..<sha>)`, which is honest where a plausible-sounding commit nobody checked is not.

## Triage routing — this pack's performance entry point

Eight of this pack's skills are performance scanners and none of them is a front door; a developer holding "the dashboard is slow" otherwise has to know all eight names and guess an order. **Run this skill first** — it is the only one that measures — then route by the metric that actually failed, rather than fanning out to all eight and merging afterwards.

- **LCP** → `lcp-audit` (which element, is it prioritized) → then `image-optimization` if it is an image, `font-optimization` if it is text, `streaming-ssr` if TTFB dominates. Stop when the element and its dominant sub-phase are named.
- **CLS** → `font-optimization` (swap-CLS) → `image-optimization` (missing dimensions). Stop at a cited `file:line`.
- **TBT / lab-INP proxy** → `bundle-analyze` → `code-splitting.md`. Stop at a named chunk + its anchoring import.
- **TTFB (`server-response-time`)** → `streaming-ssr` → `ssr-audit` if the route is wrong-strategy rather than slow. Stop at the blocking call with its measured latency.
- **Script-size budget** → `bundle-analyze` → the asset scanners for the non-JS budgets.
- **`bf-cache` ineligible** → `navigation-speed`; it owns the disqualifier detectors, this runner only knows the audit failed.
- **Nothing failed but navigation feels slow** → `navigation-speed`; prefetch, loading UI and bfcache are invisible to one page load.
- **Lab clean, users complain** → field data via `web-vitals-field` *(performance pack, when co-installed)*; absent it, say `field source unavailable` and stop.

**Merging: one ranked list, not N reports.** Rank by savings per unit of effort — (bytes or milliseconds recovered) ÷ (files touched) — and say which single item closes the budget on its own. When the `performance` pack is co-installed its `/perf-audit` owns this orchestration and this section defers to it.

## Default budgets

```json
{
  "ci": {
    "collect": { "numberOfRuns": 5 },
    "assert": {
      "assertions": {
        "categories:performance":              ["error", { "minScore": 0.9, "aggregationMethod": "median-run" }],
        "largest-contentful-paint":            ["error", { "maxNumericValue": 2500, "aggregationMethod": "median-run" }],
        "cumulative-layout-shift":             ["error", { "maxNumericValue": 0.1, "aggregationMethod": "median-run" }],
        "total-blocking-time":                 ["error", { "maxNumericValue": 300, "aggregationMethod": "median-run" }],
        "first-contentful-paint":              ["warn",  { "maxNumericValue": 1800 }],
        "speed-index":                         ["warn",  { "maxNumericValue": 3400 }],
        "resource-summary:script:size":        ["error", { "maxNumericValue": 307200 }],
        "resource-summary:stylesheet:size":    ["warn",  { "maxNumericValue": 102400 }]
      }
    }
  }
}
```

Customize per-project. Mobile budgets stricter than desktop. Critical-JS budget tighter than total-JS. Pin `@lhci/cli@0.15.1`: it bundles Lighthouse 12.6.1, which still has the legacy audit ids; Lighthouse 13 keeps only the `*-insight` ids (source skill § Lighthouse ids by version). No `interaction-to-next-paint` assertion: that audit exists only in timespan mode, never in an `lhci autorun` navigation run.

## Output

```
Lighthouse CI — /products (mobile, median run of 5; LHCI 0.15.1 / Lighthouse 12.6.1)

  PASS  LCP             2210ms  (budget 2500)
  PASS  CLS             0.04    (budget 0.1)
  FAIL  TBT             420ms   (budget 300)   regression vs baseline 210ms
  PASS  FCP             1640ms  (budget 1800)
  PASS  performance     0.92    (budget 0.90)

Bundle (resource-summary):
  PASS  JS total        284 KB  (budget 300)
  FAIL  JS critical     162 KB  (budget 150)   12 KB over

Likely cause  (step 6, source b — diff since baseline 9f2e1c0):
  Commit a1b2c3d added `import { Editor } from "tiptap"` to HomePage; confirmed by
  source a, where bundle-analyze names chunk home-*.js (+41 KB) anchored on that import.
  Move Editor behind a lazy boundary or per-route chunk.

Routed next (§ Triage routing):
  TBT + JS-critical over budget -> bundle-analyze (done) -> code-splitting.md

Reports:  .lighthouseci/lhr-1745492045123.html
```

## False positives / gotchas

- Run against the BUILT artifact, not `pnpm dev`. Dev mode injects HMR + uncompressed source, which inflates TBT and LCP misleadingly.
- Network flake produces a one-shot regression — re-run before blocking.
- Baseline = median of last 10 successful runs. A single fast run isn't a baseline.
- Mobile throttling defaults to "Slow 4G + 4x CPU" — unchanged for years; matches real low-end devices, don't relax it.
- CLS often regresses from font swaps or hero images without `width/height` — verify in the diagnostic, not just the score.
- Skip server-rendered admin pages (no public traffic, no Core Web Vitals to chase). Keep the budget on customer-facing routes.

## Halt conditions

- Halt on hand-waves: every regression must cite metric + measured value + budget + likely cause (commit hash / file / chunk) — produced by the attribution step, or reported as `unattributed` with the candidate range named.
- Halt if the stored baseline carries no `$BASELINE_SHA`; without it the next regression is unattributable by construction.
- Halt if a failed metric is reported with no routed next step while § Triage routing names one.
- Halt if the run targeted `pnpm dev` instead of the built artifact — invalid measurement, re-run.
- Halt if `numberOfRuns < 5` or a numeric assertion lacks `aggregationMethod: "median-run"` — one Lighthouse run moves 5–10 points.
- Halt if any INP value is reported without a field source (CrUX or RUM `onINP`, the `web-vitals-field` skill *(performance pack, when co-installed)*). Without that pack the run prints `INP: field source unavailable` — never a TBT number relabelled.
- Halt if a budget is relaxed in `lighthouserc.json` to make the build pass — that's masking, not fixing. Relaxation requires an ADR.
