---
name: visual-check
description: Playwright-based UI verification — captures screenshots across locales, themes, and viewports. Run after a visible change; compares against a baseline.
---

# visual-check

## Premise

Real artifacts only. Every claim cites the baseline file path + the actual file path + the diff file path produced. "Looks the same" without a diff image is not verification. A run that updates baselines without explicit user confirmation is forbidden — `--update-snapshots` is a deliberate decision, not a workaround for a failing run.

Refuse to declare PASS unless every combo in the matrix produced a row with either "no diff" or a diff image path.

For frontend changes. Verifies the UI renders correctly across locales, themes, and viewport sizes before shipping.

## When to use

- After any change that touches a `.vue` / `.tsx` / `.svelte` template, CSS, or design tokens.
- After an i18n string update that may shift layout (Arabic / German / Japanese often do).
- After a Tailwind config change.
- Before a release candidate goes to QA.

## Prerequisites

- Dev server running locally (or a built static preview).
- Playwright installed: `pnpm add -D @playwright/test && npx playwright install`.
- Baseline screenshots at `test/visual/baseline/` (generated on the first green run; commit them).
- A `test/visual/visual.spec.ts` that drives `page.goto` + `expect(page).toHaveScreenshot()`.

## Procedure

1. Confirm the dev server URL (default `http://localhost:3000`) and that it serves all declared locales.
2. Run the visual suite — full or scoped:
   ```bash
   # All routes, all combos
   npx playwright test test/visual/
   # One route
   npx playwright test test/visual/ -g 'products'
   # Update baselines after an intentional change
   npx playwright test test/visual/ --update-snapshots
   ```
3. The matrix per route:
   - Locales: every entry in `i18n.config.ts` (`en`, `ar`, ...).
   - Themes: `light` + `dark` (if supported).
   - Viewports: mobile (375x667), tablet (768x1024), desktop (1280x800).
4. For each combo, Playwright compares pixel diff vs baseline; threshold from `playwright.config.ts` (`maxDiffPixelRatio`).
5. Inspect failures:
   ```bash
   npx playwright show-report   # opens HTML diff viewer with side-by-side baseline / actual / diff
   ```
6. After confirming the change is intentional, regenerate baselines and commit them with a message that explains the visual delta.

## Output

```
Running 18 tests using 4 workers

  PASS  /products  en  light  mobile     no diff
  PASS  /products  en  light  desktop    no diff
  PASS  /products  en  dark   desktop    no diff
  FAIL  /products  ar  light  mobile     12.3% pixel diff
        Snapshot: test/visual/baseline/products-ar-light-mobile.png
        Diff:     test/visual/diffs/products-ar-light-mobile.png
  PASS  /products  ar  light  desktop    no diff

1 failed (1 of 18). Open report:  npx playwright show-report
```

## False positives / gotchas

- Fonts loading after the first paint cause pixel diff — wait for `document.fonts.ready` before screenshotting.
- Time-based content (countdowns, "5 minutes ago") — mock the clock with `page.clock.install()` or freeze with stable test data.
- Animations — disable via `page.emulateMedia({ reducedMotion: 'reduce' })` in setup.
- Image sources with cache-busted query strings produce different pixels per run — pin or stub.
- RTL (Arabic, Hebrew) layout MUST be in the matrix if the app serves those locales — flipped layouts catch real bugs.
- Never run against prod. Dev server only.

## Halt conditions

- Halt unless every combo (locale × theme × viewport) produces a row in the report with the diff file path or "no diff".
- Halt if `--update-snapshots` was used to "fix" a failing run without explicit user approval — that's masking a regression.
- Halt if no baseline exists yet AND the run claims PASS — the first run only generates baselines, it cannot verify them.
- Halt if RTL locales are declared in `i18n.config.ts` but absent from the matrix — flipped layouts must be tested.
