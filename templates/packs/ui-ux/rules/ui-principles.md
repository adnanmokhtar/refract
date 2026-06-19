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
- Touch targets ≥ 44×44 CSS px (iOS HIG) / 48×48 dp (Android Material). Test with a finger, not a mouse.
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

## Review checklist

- [ ] Tab through the page — every interactive element reachable, focus ring visible, order matches layout.
- [ ] Run axe DevTools or Lighthouse a11y audit — zero serious violations.
- [ ] Resize from 320px up — no horizontal scroll, no overlapping elements.
- [ ] Disable network in DevTools → verify offline / error state, not infinite spinner.
- [ ] Toggle "Reduce motion" in OS settings → animations are disabled or instant.
- [ ] Screen reader smoke test (VoiceOver / NVDA) on the primary flow.

## Enforcement

- `eslint-plugin-jsx-a11y` (React) / `vue-a11y` / `nuxt-a11y` plugin in lint config.
- Storybook + `@storybook/addon-a11y` for component-level audits.
- Lighthouse CI budget on a11y score (≥ 95) gating PRs.
- Visual regression via Playwright / Chromatic on critical pages.

## Axis catalog (cited by `ui-design-sweep` closure verbs)

The skill `ui-design-sweep.md` operates from a closed vocabulary of 18 verbs; each verb closes a finding on ONE of these axes. This catalog is the single source of truth — when a tool reports "design-token drift" or "hierarchy violation", it cites the axis name from this list.

| Axis | Heuristic | Closure verbs that operate on it |
|---|---|---|
| **tokens** | Every conceptual value (color / spacing / radius / shadow / type / motion) lives in `_extracted-idioms.md § Tokens`; literals in components are drift. | `consolidate-tokens`, `extract-token` |
| **wrappers** | A shared wrapper exists for every recurring component shape; raw HTML / library components used where a wrapper exists is drift. | `unify-component` |
| **patterns** | ≥5 instances of the same affordance pattern means the wrapper is missing and should be extracted. | `extract-pattern` |
| **hierarchy** | Exactly one primary action per screen (visually dominant); heading levels descend without skips; primary-action prominence ≥ 80 score. | `normalize-hierarchy` |
| **type-scale** | Every `font-size` matches a declared scale step (no `17.5px` when scale is `12 / 14 / 16 / 18 / 20 / 24 / 32 / 48`). | `apply-type-scale` |
| **rhythm** | Every margin / padding / gap is a multiple of the spacing-token base (typically 4 or 8 px). | `tighten-rhythm` |
| **density** | A single surface uses one density (compact / cozy / comfortable); density chosen for context (admin → compact, marketing → comfortable). | `simplify-density` |
| **states** | Every async surface renders a specific empty / loading / error state; data + spinner never simultaneous (no CLS). | `wire-empty-state`, `wire-loading-state`, `wire-error-state` |
| **contrast** | Body text ≥ 4.5:1, large text + UI components ≥ 3:1 (WCAG 2.2 AA), at every interactive state (default / hover / focus / disabled). | `lift-contrast` |
| **focus** | Every interactive element has visible `:focus-visible` ring with ≥ 3:1 contrast; never `outline: none` without replacement. | `align-focus-ring` |
| **iconography** | One canonical icon set per project (no Heroicons + Material + FontAwesome mixed). | `unify-iconography` |
| **motion** | Animation duration + easing comes from motion tokens; respects `prefers-reduced-motion`; targets `transform` / `opacity` (no layout-thrash). | `normalize-motion` |
| **tap-target** | Every interactive element ≥ 44×44 CSS px at mobile breakpoint (WCAG 2.5.5 / iOS HIG / Material 48dp). | `expand-tap-target` |
| **cta** | Primary CTA position is canonical per surface type (list / detail / form / modal). | `unify-cta-placement` |
| **affordance** | Action elements LOOK interactive (hover / focus / cursor); icon-only has `aria-label`; disabled buttons explain WHY. | `clarify-affordance` |
| **surface** | Each page matches the prototypical example for its surface type (list / detail / form / modal); divergent skeletons are drift. | `normalize-surface` |

Any UI/UX finding NOT on this catalog is either (a) an architectural concern (route to `architectural-diagnosis`), (b) a code-structure concern (route to `refactoring-sweep` / `align-recheck`), or (c) outside scope — halt and surface, do not invent a 17th axis.
