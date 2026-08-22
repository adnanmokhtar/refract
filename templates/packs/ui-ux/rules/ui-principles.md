---
name: ui-principles
description: UI / UX Principles
kind: rule
pack: ui-ux
severity: must
applies-to: ui-ux-track, every-code-writing-task-in-ui-ux
---

# UI / UX Principles

> **Hard rule.** Every interactive element MUST be keyboard-reachable with a visible `:focus-visible` ring, every input MUST have a `<label>` (placeholders don't count), and color contrast MUST meet WCAG 2.2 AA (≥ 4.5:1 body, ≥ 3:1 large/UI). Hover-only critical info, icon-only buttons without `aria-label`, status by color alone, and `outline: none` without a replacement are forbidden.

Prevents the three failures users punish: confusing labels, broken keyboard nav, low-contrast text.

## Must

- Labels are verbs in the user's tense: "Save changes", "Delete account", "Send invite". Not "OK", "Submit", "Yes".
- Error messages name the field, the rule, and the fix: "Phone must be 10 digits — you entered 9." Not "Invalid input."
- Empty states explain what goes here AND offer one primary action ("No orders yet — Create your first").
- Pointer targets clear **WCAG 2.2 SC 2.5.8 (Minimum) — Level AA, 24×24 CSS px** (or a Spacing / Inline / Equivalent exception), and are DESIGNED to the platform target: 44×44 CSS px (iOS HIG 44pt) / 48dp (Material). 44×44 is SC **2.5.5**, Level **AAA** — house target, never the AA floor.
- Color contrast ≥ 4.5:1 for body text, ≥ 3:1 for large text and UI components (WCAG 2.2 AA). Audit with axe-core or Lighthouse.
- Every interactive element is reachable + operable via keyboard. Tab order matches visual order.
- `:focus-visible` style on every interactive element. Never `outline: none` without a replacement ring.
- Every `<img>` has `alt`. Decorative images get `alt=""`, not omitted.
- Every form input has a `<label>` (or `aria-label` if visually hidden). Placeholders are NOT labels.
- Loading, success, error, and empty states exist for every async surface — list, form, page.
- Destructive actions require either a typed-confirmation modal ("type DELETE to confirm") or a 5-second undo toast.

## Must not

- Hover-only menus or tooltips that gate critical info — touch devices can't hover. Use click-to-open with `aria-expanded`.
- Disabled buttons without a tooltip or message explaining WHY. Users assume the UI is broken.
- Icon-only buttons without `aria-label`. Screen readers say "button"; sighted users guess.
- Modals stacked >1 deep. If you need a wizard, use steps, not nested modals.
- Auto-focus on page load when content is below the fold — scrolls users away from context.
- Truncated text without a tooltip or expansion control. The hidden content matters.
- Status by color alone (red / green icons). Pair with text or shape for color-blind users.

## Should

- Use 3 baseline breakpoints: 320 (mobile), 768 (tablet), 1280+ (desktop). Add more only when the design demands it.
- Run inline validation on blur, never on every keystroke (keystroke validation = noise + error blink).
- Add pagination, search, sort, and filter for any list expected to exceed 50 items in production.
- Prefer inline editing over modals when only one field changes — fewer context switches.
- Render exactly one primary action per screen, visually distinct. Multiple primaries = no primary.

## Enforcement

- An a11y lint plugin in the lint config: `eslint-plugin-jsx-a11y` (React) or `eslint-plugin-vuejs-accessibility` (Vue — NOT `eslint-plugin-vue-a11y`, last published 2019). Angular: `@angular-eslint/template/accessibility`.
- Storybook + `@storybook/addon-a11y` for component-level audits.
- Lighthouse CI budget on a11y score gating PRs; visual regression via Playwright / Chromatic on critical pages.
- Lint + axe do not cover the whole floor. The manual lane — tab-order walk, screen-reader smoke, OS reduce-motion toggle, offline state, 320px reflow — is `a11y-quick-check`'s runbook, not a checklist to restate here.

## Axis catalog (the usability floor + `ui-design-sweep` closure map)

**16 axes / 19 closure verbs — a CLOSED vocabulary.** The 16 axes are:

`tokens` · `wrappers` · `patterns` · `hierarchy` · `type-scale` · `rhythm` · `density` · `states` · `contrast` · `focus` · `iconography` · `motion` · `tap-target` · `cta` · `affordance` · `surface`

19 ≠ 16 on purpose — some axes carry several verbs (`tokens`, `states`). Both numbers are cited verbatim downstream: extend a row, never renumber the set.

Any UI/UX finding NOT on these 16 axes routes OUT — (a) architectural → `architectural-diagnosis`, (b) code-structure → `refactoring-sweep` or `/align-recheck`, (c) out of scope → halt and surface. **Never invent a 17th axis.**

**Depth lives at `ai/patterns/axis-catalog.md`** — per-axis detection heuristic, closure verbs, the catalog's dual role (closure map for `ui-design-sweep`; usability floor for `creative-director` / `ux-reviewer` / `/redesign`), and the composite-surface *completeness* companion floor. Load it at dispatch; the closed names above are what must be in session.
