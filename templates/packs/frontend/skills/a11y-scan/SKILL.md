---
name: a11y-scan
description: Run axe-core against the running app on a declared route matrix and gate the merge on it — WCAG 2.2 AA tag set, critical/serious severity split, an interactive-surface pass that opens every menu/dialog/tab before scanning, and axe's `incomplete` review items surfaced instead of swallowed. Needs a running server; start one with `dev-server-start` first. NOT the manual audit — it cannot judge screen-reader experience, keyboard interaction quality, or context, so a clean run is a floor and never a conformance claim; those axes belong to `@accessibility-auditor` (this pack) or the ui-ux pack's `a11y-quick-check` fast lane.
allowed-tools: [Read, Grep, Glob, Bash]
---

# a11y-scan

## Premise

Find real a11y issues, not hand-waves. Every finding cites the rule id + the offending node selector + `<file:line>` of the source that produced it. "Looks accessible" is not a finding. "Probably fine" is not a finding. If axe reports zero violations on a page that obviously has them (no headings, no landmarks, no labels) — the scan was misconfigured, re-run it.

A run that produces zero output for zero reason is a failed run, not a clean one. **And a run that never opened anything scanned the closed page** — see § Interactive surfaces; a route report with no `interactive surfaces` row is incomplete by construction, not clean.

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

## Interactive surfaces — the second pass

Everything above scans the page **as it loads**. In an admin app the a11y defects are almost never there: the modal, the dropdown, the combobox, the date picker, the tab panel and the disclosure are unmounted or `hidden` at load, so `Critical (0)` on a route with a keyboard-trapping dialog is a true statement about a page nobody uses. The gotcha below has always named this blind spot; this section is the step that closes it. It is not optional and it is not an extension — a route matrix without it is half a scan.

### 1. Enumerate the triggers — from source AND from the DOM

```bash
# Source pass. Add this project's own wrapper names (modal / dropdown / drawer /
# popover components) from .claude/codebase-profile.md or _extracted-idioms.md -
# a repo whose menus are all <AppMenu> matches none of the generic attributes.
rg -n 'aria-haspopup|aria-expanded|aria-controls|role="tab"|<details|<dialog|popovertarget' <route-dir>
```

```ts
// DOM pass, after the route has settled - catches portals, generated menus and
// wrapper output that no source file spells literally.
const triggers = await page.locator(
  '[aria-haspopup], [aria-expanded], [aria-controls], [role="tab"], summary, [popovertarget]'
).all();
```

Union the two. The grep finds triggers the DOM has not rendered yet (a menu inside a collapsed section); the DOM query finds triggers the source never spells.

### 2. Open each one, scan the opened state

```ts
const SURFACES = '[role="dialog"], [role="menu"], [role="listbox"], [role="tabpanel"], [popover]:not([hidden])';
const unreachable = [];

for (const trigger of triggers) {
  const name = (await trigger.getAttribute('aria-label')) || (await trigger.innerText());
  await trigger.click();

  const surface = page.locator(SURFACES).first();
  const opened = await surface.waitFor({ state: 'visible', timeout: 2000 }).then(() => true, () => false);
  if (!opened) { unreachable.push(name); continue; }   // a trigger that opens nothing is a finding, not a skip

  // Same option order as above - .options() before .withTags() or the tags are dropped.
  let builder = new AxeBuilder({ page })
    .options({ rules: { 'target-size': { enabled: true } } })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']);

  // Scope the scan to the opened surface: same rules, a fraction of the runtime, and the
  // violation is attributed to the surface rather than to the page. `.include()` takes a
  // CSS SELECTOR - not an element handle - so it only applies when the surface has one
  // that resolves uniquely. No id: scan the whole document; the surface is in it either way.
  const id = await surface.getAttribute('id');
  if (id) builder = builder.include(`#${id}`);

  record(`${route} :: ${name} (opened)`, await builder.analyze());

  await page.keyboard.press('Escape');
}
```

### 3. The four things only the opened state can show

Three of these are not axe rules — axe will report `Critical (0)` on all of them. Assert them explicitly and carry the result in the row, or the pass buys only the accessible-name check:

1. **Accessible name of the surface** — `aria-dialog-name` / `aria-command-name` fire only once the surface exists. This one *is* axe.
2. **Focus moved in on open, and returned to the trigger on close** — read `:focus` before the click, after the open, and after `Escape`. A dialog that leaves focus on `<body>` strands every keyboard user.
3. **Keyboard trap or the reverse** — Tab past the last focusable inside the surface: a modal must wrap focus back inside, a menu must let focus leave. Both failures are invisible to a scanner.
4. **`aria-expanded` flipped on the trigger** — a trigger stuck at `false` tells a screen reader nothing opened.

### 4. The mandatory report row

Every route row carries, whatever the outcome:

```
interactive surfaces: <N> found / <M> opened / <K> unreachable
```

Until that row is present the route has no result. `Critical (0)` beside `0 found` on an admin route means the enumeration did not run — not that the page has no menus. `K > 0` is itself a finding: a trigger that opens nothing under a plain click is either broken or mouse-only, and both are graded.

**Cost control, not scope reduction.** A route with dozens of triggers scans the opened state of each *scoped to the surface* (`.include()` above), which is where the time goes from prohibitive to routine. If a run must still be capped, cap it by declaring the excluded triggers in the row (`N found / M opened / K unreachable / J deferred: <names>`) — a deferred trigger is a named backlog item, never an unmentioned one.

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

Critical (0) in the loaded state:
  (none) — see the interactive-surface rows below before reading this as clean

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

interactive surfaces: 6 found / 5 opened / 1 unreachable
  - "Account menu" (opened)      — no violations; focus entered, returned on Escape
  - "Edit address" dialog        — SERIOUS aria-dialog-name: no accessible name on [role=dialog]
  - "Card details" tab panel     — no violations
  - "Country" combobox           — CRITICAL: focus left the listbox on Tab, trigger aria-expanded stayed false
  - "Date range" picker          — no violations
  - "Row actions" (row 1)        — UNREACHABLE: click, hover and Enter all opened nothing

Verdict: REQUEST_CHANGES (serious issues must be fixed; 1 review item unresolved; 1 critical in an opened surface; 1 trigger unreachable).
Automated coverage only — screen-reader, keyboard-quality and context checks are NOT covered here.
```

## False positives / gotchas

- **Automation is a floor, not a coverage percentage.** Published "automated tools catch N%" figures measure different things (share of *issues found in an audit* vs share of *success criteria testable*) and are not interchangeable — do not quote one as the other, and do not quote any figure this skill has not opened the source for. What is safe to say: axe cannot evaluate screen-reader announcement/order/context, keyboard interaction quality, cognitive load, or context-dependent meaning, so a clean scan is a floor.
- Pair automated scans with: keyboard-only testing (unplug the mouse), screen-reader testing (VoiceOver on macOS, NVDA on Windows), and testing with people who use assistive tech.
- `color-contrast` on text over an image or gradient lands in `incomplete`, not `violations` — that is axe being honest, not a pass.
- A component rendered only after interaction (menu, dialog, tab panel) is invisible to a scan that never opens it. Drive it open first, or the route's report is incomplete by construction — that is what § Interactive surfaces is for, and its report row is what proves it ran.
- A trigger that opens nothing under a plain `click()` is not automatically a bug: some open on hover, on `keydown`, or only for a role the test user lacks. Retry once with `hover()` and once with `Enter` before recording it `unreachable`, and say which attempt worked in the row.
- A route behind an auth guard that redirects to `/login` scans the *login page* and reports it clean. Assert a surface-unique marker after `goto` before trusting any result (the `visual-check` blocked-render rule applies verbatim).
- Disabling a rule to make CI green is a masking action, not a fix — see Halt conditions.

## When to run

- On every PR that touches UI, as a merge gate on the critical-route matrix.
- After a theme, token, or locale change — contrast and RTL failures are theme-specific and do not reproduce in the default combo.
- After any change to a modal, menu, tab, combobox or disclosure — the interactive pass is the only lane that sees it, and the loaded-state scan will report clean either way.
- Before a release, across the full route matrix rather than the PR-scoped subset.
- When `@accessibility-auditor` (this pack) — or `a11y-quick-check` *(ui-ux pack, when co-installed)* — escalates a suspected machine-checkable defect and wants it proven on the real DOM.

## Halt conditions

- Halt on hand-waves: "looks fine", "probably accessible", "skipped because complex" are not acceptable verdicts. Cite rule id + node + `<file:line>` or do not report.
- Halt if the scan returns zero findings AND the page renders no `<h1>`, no landmark, or no labelled inputs — the scan didn't actually run against the page.
- Halt if a violation is "fixed" by disabling the rule rather than addressing the node. Disablement requires an inline comment with the justification.
- Halt if routes were skipped silently — every route in the matrix must produce a row in the report (PASS, FAIL, or SKIPPED-with-reason).
- Halt if a route report carries no `interactive surfaces: N found / M opened / K unreachable` row. A scan of the closed page is not a scan of the route, and a missing row is indistinguishable from a page with no menus — which is why the row is mandatory even when `N` is 0.
- Halt if a surface was opened and only axe ran on it: focus-entered, focus-returned, tab-containment and `aria-expanded` are asserted separately or they were not checked at all. axe reporting zero on those four is silence, not a pass.
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
