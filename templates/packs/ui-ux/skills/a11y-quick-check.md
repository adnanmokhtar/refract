---
description: A focused 60-second a11y check on a single screen / component. Reports the violations that auto-tools catch, plus the ones they miss that humans must verify. The in-pack a11y pass that /design-review and /enhance-ui run; escalates to the frontend pack's @accessibility-auditor for a full audit when that pack is installed.
kind: skill
pack: ui-ux
---

# Skill: a11y-quick-check

A fast pass focused on the highest-impact a11y issues, tunable per scope. This is the **resolvable in-pack** a11y check — `/design-review` and `/enhance-ui` run it. For a heavier full audit, escalate to the `frontend` pack's `@accessibility-auditor` *when that pack is installed* — never depend on it from here; this skill is self-sufficient for one screen / one PR.

## Premise

Find real a11y issues, no hand-waves. Every finding cites `<path:line>` (or screen-reader transcript line / DOM selector) for the offender, and names the WCAG criterion it violates. "Looks inaccessible" is not a finding; "icon-only `<button>` at `Cart.vue:42` has no accessible name (WCAG 4.1.2)" is. Auto-tools cover ~40% — the audit's value is the manual 60% (focus order, SR announcements, motion, keyboard model). Citations let a reviewer reproduce the issue without re-running the tools.

## Halt conditions

- Halt on any finding without `<path:line>` or a reproducible artifact (screen-reader transcript, screenshot, axe rule id).
- Halt on "auto-tool said clean" used as a stand-in for manual review.
- Halt on severity claims ("BLOCKER") without a named WCAG criterion.

## When to use

- PR review on a UI change.
- Pre-merge quick check.
- Adding a new component to the design system.
- Sanity check before declaring a screen "done."

## Procedure

### 1. Run the automated tools

Web:
- `axe-core` (browser extension or `@axe-core/playwright` for CI).
- `Lighthouse` accessibility audit (Chrome DevTools).
- `pa11y` (CLI).

React Native:
- `axe-react-native` (where supported).
- `accessibility-scanner` (Android tool).
- VoiceOver / TalkBack manual walkthrough.

Flutter:
- `flutter analyze` accessibility (static).
- `accessibility_test` package.
- TalkBack / VoiceOver manual walkthrough.

These catch ~40% of WCAG issues. The other 60% need human review.

### 2. Manual checks the auto-tools miss

| Check | What to verify |
|---|---|
| Keyboard reachability | Tab through every interactive element. Visible focus indicator. Logical order. |
| Skip-link | First Tab on a page goes to "Skip to content" or main element. |
| Focus management on modal/drawer | Focus moves into modal on open; back to trigger on close. |
| Form errors | Each error tied to its input via `aria-describedby` + `aria-invalid`; announced to screen reader. |
| Loading states | Communicated via live region OR `aria-busy`. |
| Toast messages | `role="status"` (polite) or `role="alert"` (assertive). Don't steal focus. |
| Headings | Logical hierarchy (h1 → h2 → h3); no jumps. One h1 per page. |
| Image alt | Decorative: `alt=""`. Informative: meaningful. Functional (icon button): `aria-label`. |
| Color contrast at hover/focus state | Auto-tools test default state; hover/focus often forgot. |
| Motion | `prefers-reduced-motion` respected for entry / scroll / parallax. |
| Touch targets (mobile) | ≥ 44×44 CSS pixels (Apple HIG / WCAG 2.5.5). |
| Form labels | `<label for>` or `aria-labelledby`. Placeholder is NOT a label. |
| Custom controls | If you re-implement a select / tab / accordion, verify keyboard model matches WAI-ARIA Authoring Practices. |
| Dynamic content | Newly inserted content reachable + announced. |

### 3. Run with screen reader

5-minute manual walk:
- macOS: VoiceOver (Cmd+F5).
- Windows: NVDA (free).
- iOS: VoiceOver (Settings → Accessibility).
- Android: TalkBack.

Listen for:
- Buttons announced as "button" (not "graphic" or "div").
- Form fields announce their label + state ("Email, edit text, required").
- Errors announced when they appear.
- Headings spoken with level ("Heading 1, Settings").

### 4. Run with keyboard only

Unplug mouse / disable touch. Walk the flow:
- Every action reachable.
- Focus indicator visible at every step.
- No focus traps (modal that locks you in).
- Escape closes modals.
- Enter activates buttons; Space activates checkboxes.

### 5. Color + contrast

- Use `contrast-ratio.com` or DevTools color picker.
- Body text: ≥ 4.5:1 vs background.
- Large text (18pt+ or 14pt bold): ≥ 3:1.
- UI controls + state indicators: ≥ 3:1.
- Don't convey state by color ALONE (red = error → also use icon + text).

## Output format

```
## A11y quick-check — <screen / component> — <date>

### Automated tool results
axe-core: <X> violations / <Y> serious / <Z> moderate
Lighthouse a11y: <score>/100

### Manual findings

**BLOCKERS:**
- Modal lacks focus trap; Tab cycles through page behind modal.
- Submit button has no accessible name (icon-only with no aria-label).
- Color contrast on disabled state is 2.1:1 — fails AA.

**HIGH:**
- Form errors not announced to screen reader.
- Heading skip from h1 → h3.

**MEDIUM:**
- Touch target on close button is 32×32 (mobile).
- Loading spinner has no aria-busy or live-region announcement.

**LOW:**
- Decorative icon next to text doesn't have `aria-hidden="true"` (not harmful, but cleaner).

### Screen-reader walkthrough notes
- "Button graphic, button" — the button name is missing; users hear "graphic" only.
- Form announces "edit text" on every field with no label.

### Keyboard walkthrough notes
- Tab order goes: nav → content → footer → BACK to nav skipping the form. Wrong order.
- Esc doesn't close the modal.

### Recommendations (ordered)
1. Add `aria-label` to icon-only buttons (fixes 3 issues).
2. Add focus trap + Esc handler to modal (fixes 2 issues).
3. Bump disabled state contrast to ≥ 3:1.
4. Add live-region for form errors.
5. Increase touch targets to 44×44.

Total fixes: 5 changes; estimated 1 hour of work.

### Coverage (which checks actually ran — honesty footer)
axe ✓ · keyboard ✓ · screen-reader SKIPPED (no VoiceOver this pass) · contrast ✓ (default state; hover/focus SKIPPED) · reduced-motion ✓
Not validated: screen-reader walk — the ~60% auto-tools miss is only partly covered this pass.
```

Any lane not run prints `SKIPPED (<why>)`, never an empty (implicitly-passing) section — a skipped screen-reader or keyboard walk must never read as clean (the skill's own #1 failure mode). The `Not validated:` line names the highest-value skipped lane so the reader knows the real coverage.

## Inputs

- Screen / component path (or "the changed files in this PR").
- Optional: WCAG level target (default AA).

## Outputs

- Inline PR comments OR `ai/audits/a11y-<scope>-<date>.md`.

## Failure modes

- Auto-tool said clean → declared good. Auto-tools miss focus order, heading hierarchy, screen-reader announcement, motion. Manual review is mandatory.
- Tested on macOS VoiceOver only — iOS VoiceOver behaves differently.
- Tested with keyboard but skipped screen reader → found 60% of issues, missed the worst.
- "Touch target ≥ 44×44" check passed in CSS but the actual hit area is smaller due to padding miscount.
- Reported `aria-label` missing but the element has visible text — visible text works, no aria-label needed.

## Related

- `@accessibility-auditor` *(frontend pack)* — full audit; this skill is the resolvable in-pack fast-pass version and the a11y lane `/design-review` runs. Escalate only when the frontend pack is installed.
- `motion-audit.md` — overlap on reduced-motion.
- `design-token-audit.md` — overlap on contrast (token swaps must preserve contrast).
- `@ux-reviewer` — overlap on flow + content quality.
