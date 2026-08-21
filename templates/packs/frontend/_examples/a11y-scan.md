---
name: a11y-scan
description: Run axe-core against the running app on a declared route matrix and gate the merge on it — WCAG 2.2 AA tag set, critical/serious severity split, and axe's `incomplete` review items surfaced instead of swallowed. Needs a running server; start one with `dev-server-start` first. NOT the manual audit — it cannot judge screen-reader experience, keyboard interaction quality, or context, so a clean run is a floor and never a conformance claim; those axes belong to `@accessibility-auditor` (this pack) or the ui-ux pack's `a11y-quick-check` fast lane.
---

# a11y-scan

## Premise

Find real a11y issues, not hand-waves. Every finding cites the rule id + the offending node selector + `<file:line>` of the source that produced it. "Looks accessible" is not a finding. "Probably fine" is not a finding. If axe reports zero violations on a page that obviously has them (no headings, no landmarks, no labels) — the scan was misconfigured, re-run it.

A run that produces zero output for zero reason is a failed run, not a clean one.

**Automation is a floor, not a pass.** This skill proves the machine-checkable subset of WCAG conformance on real rendered DOM. It cannot see screen-reader experience, keyboard interaction quality, cognitive load, or whether the accessible name it found is the *right* name. A green scan means "no automated violation," never "accessible" — the verdict wording must say which one it is.

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
        // .options() REPLACES the option object, so it MUST precede .withTags()
        // or the tag list is silently dropped. axe ships WCAG 2.2 rules disabled
        // by default, hence the explicit enable.
        .options({ rules: { 'target-size': { enabled: true } } })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])  // WCAG 2.2 AA
        .analyze();
      expect(results.violations.filter(v => v.impact === 'critical')).toEqual([]);
      // Log all violations for visibility
      results.violations.forEach(v => {
        console.log(`${v.impact}: ${v.help} (${v.nodes.length} nodes)`);
      });
      // Review items: axe could not decide. Never drop these silently.
      results.incomplete.forEach(v => {
        console.log(`REVIEW ${v.id}: ${v.help} (${v.nodes.length} nodes)`);
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

Review items (1) — axe could not determine pass/fail; a human resolves each.
An unresolved review item is NOT a pass:
  - color-contrast-enhanced: text over hero background image (.hero h1)

Moderate (1):
  - heading-order: h1 followed by h3, skipping h2
    Affected: 1 node
    Fix: either demote h1 → h2 context, or promote h3 → h2

Minor (0):
  (none)

Verdict: REQUEST_CHANGES (serious issues must be fixed).
```

## False positives / gotchas

Automation is a floor, not a coverage percentage — do not quote a "tools catch N%" figure you have
not opened the source for. axe cannot evaluate screen-reader announcement/order/context, keyboard
interaction quality, cognitive load, or context-dependent meaning. Contrast over an image lands in
`incomplete`, not `violations`. A component that only exists after interaction is invisible to a
scan that never opens it. An auth-gated route that redirected to `/login` scans the login page and
reports it clean.

Pair automated scans with keyboard-only testing, screen-reader testing (VoiceOver / NVDA), and
testing with people who use assistive tech.

## When to run

Every PR that touches UI (critical routes), after a theme/token/locale change, before release
(full matrix), and whenever the manual audit wants a machine-checkable claim proven on real DOM.

## Halt conditions

- Critical violations BLOCK; serious must be fixed before release.
- Halt if `results.incomplete` was not read — a report showing only `violations` claims certainty axe never had.
- Halt if the report claims WCAG 2.2 AA without the 2.2 tag + `target-size` enable.
- Never disable an axe check without a documented inline justification.
- Every route in the matrix produces a row: PASS, FAIL, or SKIPPED-with-reason.

## Related

`@accessibility-auditor` (deep audit, this pack) · `/a11y-audit` (orchestrator) · `dev-server-start`
(prerequisite) · `visual-check` (render-harness contract) · `a11y-quick-check` *(ui-ux pack, when
co-installed — the 60-second in-review lane)*.
