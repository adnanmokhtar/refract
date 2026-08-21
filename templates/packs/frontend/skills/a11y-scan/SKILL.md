---
name: a11y-scan
description: Run axe-core against the running app on a declared route matrix and gate the merge on it — WCAG 2.2 AA tag set, critical/serious severity split, and axe's `incomplete` review items surfaced instead of swallowed. Needs a running server; start one with `dev-server-start` first. NOT the manual audit — it cannot judge screen-reader experience, keyboard interaction quality, or context, so a clean run is a floor and never a conformance claim; those axes belong to `@accessibility-auditor` (this pack) or the ui-ux pack's `a11y-quick-check` fast lane.
---

# a11y-scan

## Premise

Find real a11y issues, not hand-waves. Every finding cites the rule id + the offending node selector + `<file:line>` of the source that produced it. "Looks accessible" is not a finding. "Probably fine" is not a finding. If axe reports zero violations on a page that obviously has them (no headings, no landmarks, no labels) — the scan was misconfigured, re-run it.

A run that produces zero output for zero reason is a failed run, not a clean one.

**Automation is a floor, not a pass.** This skill proves the machine-checkable subset of WCAG conformance on real rendered DOM. It cannot see screen-reader experience, keyboard interaction quality, cognitive load, or whether the accessible name it found is the *right* name. A green scan means "no automated violation," never "accessible" — the verdict wording must say which one it is.

## Ownership boundary

- **This skill** — automated axe run over a route × theme × locale matrix, gating CI.
- **`@accessibility-auditor`** (this pack) — the deep manual audit: screen-reader flow, focus order, SC-by-SC grading. It consumes this scan's output; it does not re-run it.
- **`a11y-quick-check`** *(ui-ux pack, when co-installed)* — the 60-second in-review fast pass on a diff. When that pack is installed, do not duplicate its lane; grade what it escalates.

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
  // criticalRoutes: fill from THIS project - home, auth, and its highest-traffic + form-heavy routes.
  for (const route of criticalRoutes) {
    test(`${route} has no critical violations`, async ({ page }) => {
      await page.goto(route);
      const results = await new AxeBuilder({ page })
        // ORDER IS LOAD-BEARING: .options() REPLACES the whole option object
        // (AxeBuilder does `this.option = options`), so it must come BEFORE
        // .withTags() or the tag list is silently discarded and the default
        // rule set runs instead. Verify this order survives your axe version.
        .options({ rules: { 'target-size': { enabled: true } } })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])  // WCAG 2.2 AA - this pack's declared baseline
        .analyze();

      expect(results.violations.filter(v => v.impact === 'critical')).toEqual([]);
      results.violations.forEach(v => {
        console.log(`${v.impact}: ${v.help} (${v.nodes.length} nodes)`);
      });
      // Review items - axe could NOT decide pass/fail. Never drop these silently.
      results.incomplete.forEach(v => {
        console.log(`REVIEW ${v.id}: ${v.help} (${v.nodes.length} nodes) - needs a human`);
      });
    });
  }
});
```

**Why the explicit `target-size` enable.** Deque's rule reference states the WCAG 2.2 rules are *"disabled by default, until WCAG 2.2 is more widely adopted and required"* (dequeuniversity.com/rules/axe — `target-size` is the rule carrying the `wcag22aa` tag). Whether a `runOnly` tag allowlist re-enables a disabled-by-default rule is **not documented** in the axe API reference — so the explicit enable is written defensively and is harmless if it turns out to be redundant.

**Confirm against the axe-core version this project installs, do not assume:** run `axe.run(document, { runOnly: { type: 'tag', values: ['wcag22aa'] } })` against a page holding a 20x20px button and check whether `target-size` appears in `violations`/`passes` or is absent entirely. If absent, the `rules` enable above is load-bearing — do not remove it. Record which answer you got in the report.

## Routes to cover

Must include (map to THIS project's routes):
- Home / landing
- The primary list + detail flow
- Any multi-step flow (checkout / onboarding / wizard)
- Auth (login, signup, password reset)
- The main authenticated dashboard
- Any form-heavy page

For authenticated routes: login in a `beforeAll` hook, reuse session. For the Playwright-MCP route, the session file and gitignored artifact dir follow the `visual-check` contract — do not invent a second convention.

## Severity levels

- **critical** — blocks usage (keyboard trap, missing label on required input). Fix immediately.
- **serious** — major (contrast failure, missing alt). Fix within sprint.
- **moderate** — usability degradation (missing heading structure). Plan.
- **minor** — cosmetic / best practice. Nit.
- **review items** (`results.incomplete`) — axe found the node but could not determine pass/fail: contrast over a background image, target size where spacing may compensate, colour-only meaning. **An unresolved review item is not a pass.** Each one is assigned to a human and reported by rule id + node.

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
- Review items = never auto-pass; they carry an owner or the run reports them as outstanding.

## Output

```
a11y scan — /checkout          axe-core <version>   tags: wcag2a,wcag2aa,wcag21aa,wcag22aa
                               target-size rule: enabled explicitly (tag-only behaviour: <verified|unverified>)

Critical (0):
  (none)

Serious (2):
  - color-contrast: "Save card" button contrast 3.8:1 (needs 4.5:1)
    Affected: 1 node
    Fix: darken button text OR lighten background
  - label: Checkbox missing accessible name
    Affected: 1 node — input#saveAddress
    Fix: add <label for="saveAddress">Save address for next time</label>

Review items (1) — axe could not determine pass/fail; a human must resolve each.
An unresolved review item is NOT a pass:
  - color-contrast-enhanced: text over hero background image
    Affected: 1 node — .hero h1
    Resolve: sample the rendered pixels behind the text, or add a scrim

Moderate (1):
  - heading-order: h1 followed by h3, skipping h2
    Affected: 1 node
    Fix: either demote h1 → h2 context, or promote h3 → h2

Minor (0):
  (none)

Verdict: REQUEST_CHANGES (serious issues must be fixed; 1 review item unresolved).
Automated coverage only — screen-reader, keyboard-quality and context checks are NOT covered here.
```

## False positives / gotchas

- **Automation is a floor, not a coverage percentage.** Published "automated tools catch N%" figures measure different things (share of *issues found in an audit* vs share of *success criteria testable*) and are not interchangeable — do not quote one as the other, and do not quote any figure this skill has not opened the source for. What is safe to say: axe cannot evaluate screen-reader announcement/order/context, keyboard interaction quality, cognitive load, or context-dependent meaning, so a clean scan is a floor.
- Pair automated scans with: keyboard-only testing (unplug the mouse), screen-reader testing (VoiceOver on macOS, NVDA on Windows), and testing with people who use assistive tech.
- `color-contrast` on text over an image or gradient lands in `incomplete`, not `violations` — that is axe being honest, not a pass.
- A component rendered only after interaction (menu, dialog, tab panel) is invisible to a scan that never opens it. Drive it open first, or the route's report is incomplete by construction.
- A route behind an auth guard that redirects to `/login` scans the *login page* and reports it clean. Assert a surface-unique marker after `goto` before trusting any result (the `visual-check` blocked-render rule applies verbatim).
- Disabling a rule to make CI green is a masking action, not a fix — see Halt conditions.

## When to run

- On every PR that touches UI, as a merge gate on the critical-route matrix.
- After a theme, token, or locale change — contrast and RTL failures are theme-specific and do not reproduce in the default combo.
- Before a release, across the full route matrix rather than the PR-scoped subset.
- When `@accessibility-auditor` (this pack) — or `a11y-quick-check` *(ui-ux pack, when co-installed)* — escalates a suspected machine-checkable defect and wants it proven on the real DOM.

## Halt conditions

- Halt on hand-waves: "looks fine", "probably accessible", "skipped because complex" are not acceptable verdicts. Cite rule id + node + `<file:line>` or do not report.
- Halt if the scan returns zero findings AND the page renders no `<h1>`, no landmark, or no labelled inputs — the scan didn't actually run against the page.
- Halt if a violation is "fixed" by disabling the rule rather than addressing the node. Disablement requires an inline comment with the justification.
- Halt if routes were skipped silently — every route in the matrix must produce a row in the report (PASS, FAIL, or SKIPPED-with-reason).
- Halt if `results.incomplete` was not read. A report that shows only `violations` claims certainty axe never had.
- Halt if the report claims WCAG 2.2 AA while the tag list or the `target-size` enable is missing — that is a 2.1 scan wearing a 2.2 banner.
- Halt if a critical violation is reported as PASS-with-note, or if the verdict line contradicts the severity blocks above it.

## Related

- `dev-server-start` — prerequisite: this scan needs a running app; reuse an already-running server rather than booting a second one.
- `visual-check` — owns the render harness contract this skill borrows for auth-gated routes (session file, gitignored artifact dir, blocked-render HALT). Its route x theme x locale matrix is the same matrix worth scanning.
- `@accessibility-auditor` — the deep audit agent. It grades WCAG 2.2 SC by SC (including the ones no scanner can reach: focus-not-obscured, redundant entry, accessible authentication) and consumes this scan as its automated floor.
- `/a11y-audit` — the command that orchestrates both lanes on a scope.
- `forms.md` — the label / `aria-describedby` / error-announcement contract most `label` and `aria-*` violations here trace back to.
- `a11y-quick-check` *(ui-ux pack, when co-installed)* — the 60-second in-review fast pass. This skill is the full automated gate; do not duplicate that lane, grade what it escalates.
