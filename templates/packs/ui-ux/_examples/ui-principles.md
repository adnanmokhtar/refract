---
name: ui-principles
kind: example
pack: ui-ux
---

# UI / UX Principles

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

- 3 baseline breakpoints: 320 (mobile), 768 (tablet), 1280+ (desktop). Add more only when the design demands it.
- Inline validation on blur, not on every keystroke (keystroke validation = noise + error blink).
- Pagination, search, sort, and filter for any list expected to exceed 50 items in production.
- Inline editing over modals when only one field changes — fewer context switches.
- One primary action per screen, visually distinct. Multiple primaries = no primary.

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
