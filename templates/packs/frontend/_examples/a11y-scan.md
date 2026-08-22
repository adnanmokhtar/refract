---
name: a11y-scan
description: Run axe-core against the running app on a declared route matrix and gate the merge on it — WCAG 2.2 AA tag set, critical/serious severity split, an interactive-surface pass that opens every menu/dialog/tab before scanning, and axe's `incomplete` review items surfaced instead of swallowed. Needs a running server; start one with `dev-server-start` first. NOT the manual audit — it cannot judge screen-reader experience, keyboard interaction quality, or context, so a clean run is a floor and never a conformance claim; those axes belong to `@accessibility-auditor` (this pack) or the ui-ux pack's `a11y-quick-check` fast lane.
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

## Interactive surfaces — the second pass

Everything above scans the page **as it loads**. In an admin app the defects are almost never there: modals, dropdowns, comboboxes, date pickers, tab panels and disclosures are unmounted or hidden at load, so `Critical (0)` on a route with a keyboard-trapping dialog is a true statement about a page nobody uses. Not optional — a route matrix without this pass is half a scan.

1. **Enumerate triggers from source AND from the DOM.** Grep `aria-haspopup|aria-expanded|aria-controls|role="tab"|<details|<dialog|popovertarget` over the route's components (plus this project's own modal / dropdown wrapper names), then query the settled DOM for `[aria-haspopup], [aria-expanded], [aria-controls], [role="tab"], summary, [popovertarget]`. Union the two: the grep finds triggers not yet rendered, the DOM query finds triggers no source file spells.
2. **Open each, re-run `analyze()` on the opened state**, scoped to the surface where it has a unique id (`.include('#id')` — a CSS selector, not an element handle). A trigger that opens nothing under click, hover and Enter is recorded `unreachable`, which is a finding, not a skip.
3. **Assert the three things axe cannot see** — focus moved into the surface on open and returned to the trigger on close; Tab is contained in a modal and free to leave a menu; `aria-expanded` flipped on the trigger. axe reporting zero on these is silence, not a pass. The accessible name of the surface is the one axe *does* own, and it only exists once the surface does.
4. **Report the row on every route, whatever the outcome:** `interactive surfaces: <N> found / <M> opened / <K> unreachable`. `Critical (0)` beside `0 found` on an admin route means the enumeration did not run.

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

Critical (0) in the loaded state:
  (none) — read the interactive-surface rows below before calling this clean

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

interactive surfaces: 6 found / 5 opened / 1 unreachable
  - "Edit address" dialog   — SERIOUS aria-dialog-name: no accessible name on [role=dialog]
  - "Country" combobox      — CRITICAL: focus left the listbox on Tab; trigger aria-expanded stayed false
  - "Row actions" (row 1)   — UNREACHABLE: click, hover and Enter all opened nothing
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
scan that never opens it — that is what the interactive-surface pass above is for, and its report
row is what proves it ran. A trigger that opens nothing under a plain click is not automatically a
bug: retry once with hover and once with Enter before recording it `unreachable`, and say which
attempt worked. An auth-gated route that redirected to `/login` scans the login page and
reports it clean.

Pair automated scans with keyboard-only testing, screen-reader testing (VoiceOver / NVDA), and
testing with people who use assistive tech.

## When to run

Every PR that touches UI (critical routes), after any change to a modal / menu / tab / combobox / disclosure (the interactive pass is the only lane that sees it), after a theme/token/locale change, before release
(full matrix), and whenever the manual audit wants a machine-checkable claim proven on real DOM.

## Halt conditions

- Critical violations BLOCK; serious must be fixed before release.
- Halt if `results.incomplete` was not read — a report showing only `violations` claims certainty axe never had.
- Halt if the report claims WCAG 2.2 AA without the 2.2 tag + `target-size` enable.
- Never disable an axe check without a documented inline justification.
- Every route in the matrix produces a row: PASS, FAIL, or SKIPPED-with-reason.
- Halt if a route report carries no `interactive surfaces: N found / M opened / K unreachable` row — a missing row is indistinguishable from a page with no menus, which is why it is mandatory even at `N = 0`.
- Halt if a surface was opened and only axe ran on it: focus-entered, focus-returned, tab-containment and `aria-expanded` are asserted separately or they were not checked at all.

## Related

`@accessibility-auditor` (deep audit, this pack) · `/a11y-audit` (orchestrator) · `dev-server-start`
(prerequisite) · `visual-check` (render-harness contract) · `a11y-quick-check` *(ui-ux pack, when
co-installed — the 60-second in-review lane)*.
