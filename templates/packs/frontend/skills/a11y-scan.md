---
name: a11y-scan
description: Automated accessibility scan using axe-core against a running app. Catches ~30% of real issues — blockers for merge on critical pages.
---

# a11y-scan

## Premise

Find real a11y issues, not hand-waves. Every finding cites the rule id + the offending node selector + `<file:line>` of the source that produced it. "Looks accessible" is not a finding. "Probably fine" is not a finding. If axe reports zero violations on a page that obviously has them (no headings, no landmarks, no labels) — the scan was misconfigured, re-run it.

A run that produces zero output for zero reason is a failed run, not a clean one.

## Tools

- `@axe-core/cli` — standalone CLI.
- `@axe-core/playwright` / `@axe-core/puppeteer` — integrates with e2e tests.
- `pa11y` — alternative, simpler output.
- `lighthouse` — includes accessibility audit.

Best integration: **@axe-core/playwright** inside existing Playwright test suite.

## Setup

```ts
// e2e/a11y.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('accessibility', () => {
  for (const route of ['/', '/products', '/cart', '/checkout', '/login']) {
    test(`${route} has no critical violations`, async ({ page }) => {
      await page.goto(route);
      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])  // WCAG 2.1 AA
        .analyze();
      expect(results.violations.filter(v => v.impact === 'critical')).toEqual([]);
      // Log all violations for visibility
      results.violations.forEach(v => {
        console.log(`${v.impact}: ${v.help} (${v.nodes.length} nodes)`);
      });
    });
  }
});
```

## Routes to cover

Must include:
- Home / landing
- Product listing + detail
- Cart + checkout
- Auth (login, signup, password reset)
- Account dashboard
- Any form-heavy page

For authenticated routes: login in a `beforeAll` hook, reuse session.

## Severity levels

- **critical** — blocks usage (keyboard trap, missing label on required input). Fix immediately.
- **serious** — major (contrast failure, missing alt). Fix within sprint.
- **moderate** — usability degradation (missing heading structure). Plan.
- **minor** — cosmetic / best practice. Nit.

## Themes + locales

Run the scan across theme variants:
```ts
for (const theme of ['light', 'dark']) {
  for (const locale of ['en', 'ar']) {
    test(`a11y ${theme} ${locale} home`, async ({ page }) => {
      await page.goto(`/${locale}?theme=${theme}`);
      // ... axe analyze
    });
  }
}
```

Dark mode contrast fails differently from light. RTL (Arabic) surfaces layout / label association bugs.

## CI integration

- Run on every PR that touches UI.
- Critical violations = BLOCK merge.
- Serious = WARN (track trend over time, plan fixes).

## Output

```
a11y scan — /checkout

Critical (0):
  (none)

Serious (2):
  - color-contrast: "Save card" button contrast 3.8:1 (needs 4.5:1)
    Affected: 1 node
    Fix: darken button text OR lighten background
  - label: Checkbox missing accessible name
    Affected: 1 node — input#saveAddress
    Fix: add <label for="saveAddress">Save address for next time</label>

Moderate (1):
  - heading-order: h1 followed by h3, skipping h2
    Affected: 1 node
    Fix: either demote h1 → h2 context, or promote h3 → h2

Minor (0):
  (none)

Verdict: REQUEST_CHANGES (serious issues must be fixed).
```

## Limitations

Automated a11y tools catch **~30%** of real issues. They miss:
- Screen reader experience (announcements, order, context).
- Keyboard interaction quality.
- Cognitive load / clarity.
- Context-dependent meanings.

Pair automated scans with:
- Keyboard-only testing (unplug the mouse).
- Screen reader testing (VoiceOver on macOS, NVDA on Windows).
- User testing with people using assistive tech.

## Rules

- Critical violations = BLOCK.
- Serious = FIX before release.
- Never disable axe checks without a documented justification in a comment.
- Add new routes to the scan as they ship.
- Run across theme + locale variants, not just default.

## Halt conditions

- Halt on hand-waves: "looks fine", "probably accessible", "skipped because complex" are not acceptable verdicts. Cite rule id + node + `<file:line>` or do not report.
- Halt if the scan returns zero findings AND the page renders no `<h1>`, no landmark, or no labelled inputs — the scan didn't actually run against the page.
- Halt if a violation is "fixed" by disabling the rule rather than addressing the node. Disablement requires an inline comment with the justification.
- Halt if routes were skipped silently — every route in the matrix must produce a row in the report (PASS, FAIL, or SKIPPED-with-reason).
