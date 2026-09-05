---
name: a11y-quick-check
description: A focused a11y check on a single screen / component, split into the lane an agent can actually execute (axe rule ids, computed contrast, DOM semantics from source) and the lane only a human can (screen reader, keyboard, OS reduced-motion). Reports each lane's real coverage instead of one blended percentage. The in-pack a11y pass that /design-review and /enhance-ui run; escalates to the frontend pack's @accessibility-auditor for a full audit when that pack is installed.
kind: skill
pack: ui-ux
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: a11y-quick-check

The **resolvable in-pack** a11y check — `/design-review` and `/enhance-ui` run it. For a heavier full audit, escalate to the `frontend` pack's `@accessibility-auditor` *when that pack is installed* — never depend on it from here; this skill is self-sufficient for one screen / one PR.

## Premise

**Two lanes, reported separately — because one of them an agent can run and the other one it cannot.**

An unattended run executes **Lane A** and *nothing else*. Printing a single blended "coverage" number over both lanes is how this skill used to claim credit for work no run performed. So:

- **Lane A — machine-resolvable.** Anything decidable from the source tree, the token file, or a headless browser: axe rule ids, contrast ratios **computed** from the resolved token pair, DOM semantics, label wiring, heading order, `prefers-reduced-motion` branches, target geometry. An agent closes this lane completely, or names what blocked it.
- **Lane B — human-only.** Screen-reader announcement quality, keyboard *feel*, focus-order sanity on a real device, OS-level reduced-motion. An agent **cannot** run these. It emits the runbook and marks the lane `NOT RUN (human lane)` — never `✓`, never silently absent.

Every finding cites `<path:line>` (or an axe rule id + DOM selector) for the offender and names the WCAG criterion **with its conformance level**. "Looks inaccessible" is not a finding; "icon-only `<button>` at `Cart.vue:42` has no accessible name — axe `button-name`, WCAG 4.1.2 (Level A)" is.

**How much do the auto-tools cover? Do not print a number.** The most-cited measurement — Deque's, over 2,000+ audits / 13,000+ pages / ~300,000 issues — is **57%**, but that is share of issue *volume*, not of success criteria, and Deque notes it is inflated by colour-contrast node counts ([deque.com](https://www.deque.com/blog/automated-testing-study-identifies-57-percent-of-digital-accessibility-issues/)). What determines the split on *your* screen is **which SC families the surface trips**: a table of text and links is mostly machine-checkable; a custom combobox, a drag-reorder or a live region is mostly not. Report the two lanes' real coverage instead.

## Halt conditions

- Halt on any finding without `<path:line>`, an axe rule id, or a reproducible artifact (screen-reader transcript, screenshot).
- Halt on "auto-tool said clean" used as a stand-in for the Lane-B checks it cannot see.
- Halt on a severity claim ("BLOCKER") without a named WCAG criterion **and its level** — a Level-AAA criterion asserted as the AA floor is the specific error this halt exists to catch (see the tap-target row).
- Halt on a contrast ratio that was estimated rather than computed from the two resolved colour values.
- Halt on a Lane-B lane printed as `✓` by an unattended run.

## When to use

- PR review on a UI change.
- Pre-merge quick check.
- Adding a new component to the design system.
- Sanity check before declaring a screen "done."

**NOT for** a native mobile tree (SwiftUI / Compose / React Native / Flutter). These checks are web-DOM-shaped — CSS pixels, `:focus-visible`, `<label for>`. The platform floor and its cited platform minimums are `platform-conventions-audit` *(mobile pack)*; escalate there instead of running web tooling against a native surface.

## Procedure

### Lane A1 — Automated scan (needs a browser)

`axe-core` (extension, or `@axe-core/playwright` in CI) — report **rule ids**, not prose: `color-contrast`, `button-name`, `label`, `link-name`, `image-alt`, `heading-order`, `region`, `aria-required-attr`, `frame-title`, `target-size` ([axe rule descriptions](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md)). `Lighthouse` — the failing audits, never the score alone. `pa11y` — for pipelines with no Playwright. No browser → `SKIPPED (no harness)`; Lane A2 still runs.

### Lane A2 — Source-resolvable, no browser required

These close without a render, so an agent has no excuse to skip them:

| Check | How it resolves from source |
|---|---|
| Contrast (default state) | Resolve the foreground/background **token pair** from the token file and **compute** the ratio. Print `#595959 on #fff → 7.0:1 ✓ AA` / `#999 on #fff → 2.85:1 ✗ AA`. Unresolvable pair (dynamic value, unresolved var) → `contrast: SKIPPED (pair unresolved)`, never a guess. Same source-level compute `/design-review` Phase 6 requires. |
| Accessible name | Icon-only `<button>` / `<a>` with no text child, no `aria-label`, no `aria-labelledby` → finding. Visible text already present → **not** a finding. |
| Label wiring | `<input>` / `<select>` / `<textarea>` with no `<label for>` and no `aria-labelledby`. A `placeholder` is not a label. |
| Heading order | Parse the template's heading levels in document order; flag skips (h1 → h3) and multiple `<h1>` per page. |
| `outline: none` | Any interactive selector clearing the outline with no `:focus-visible` replacement in the same file. |
| Reduced motion | Every `animation` / `transition` declaration reachable without a `prefers-reduced-motion` branch (project-wide reset counts — cite it by `<path:line>`). |
| Colour-only state | `color:` is the only differentiator on an error/success/selected state — no icon, no text, no shape. |
| Target geometry | Compute the border-box of small interactive elements at the mobile breakpoint (two thresholds — see Lane A3). |
| Focus management | Focus moves into a modal/drawer on open and returns to the trigger on close — readable from the open/close handlers. |
| Form errors | Each error tied to its input via `aria-describedby` + `aria-invalid`. |
| Loading + toasts | Loading announced via a live region or `aria-busy`, not a bare spinner; toasts `role="status"` / `role="alert"`, never stealing focus. |
| Contrast at hover / focus / disabled | Auto-tools test the default state only — compute the other three token pairs. |
| Custom controls | A re-implemented select / tab / accordion matches the keyboard model in [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/) — cite the pattern by name. |
| Dynamic content | Newly inserted content is reachable in the tab order and announced. |

### Lane A3 — Target size: two different numbers, do not conflate them

| Threshold | Criterion | Level | Use it as |
|---|---|---|---|
| **24 × 24 CSS px** | [WCAG 2.2 SC 2.5.8 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) | **AA** | The **conformance floor.** This is the one a "WCAG 2.2 AA" claim is measured against. Five named exceptions: **Spacing** (a 24px-diameter circle centred on each undersized target's bounding box does not intersect another target's), **Equivalent** (same function reachable from a conforming control on the page), **Inline** (target sits in a sentence / is constrained by the line-height of non-target text), **User agent control**, **Essential**. |
| **44 × 44 CSS px** | [WCAG 2.2 SC 2.5.5 Target Size (Enhanced)](https://www.w3.org/TR/WCAG22/) | **AAA** | A **design target**, not the AA floor. It matches Apple HIG's 44pt and sits under Material's 48dp, so it is a sound house rule — state it as a house rule, never as "what AA requires". |

**Verification must name which threshold it used.** `axe-core`'s `target-size` rule implements **2.5.8 at 24×24** including the spacing alternative ([Deque rule docs](https://dequeuniversity.com/rules/axe/4.10/target-size)) — so "axe clean" proves 24, not 44. A 44 claim needs a measured border-box, not axe. Print both: `target-size: axe clean (2.5.8 AA, 24×24) · house 44 target: 3 elements below (measured)`.

### Lane B — the human runbook (emit it; do not claim it)

Hand these to a person. An unattended run prints the runbook and marks the lane `NOT RUN (human lane)`.

1. **Screen reader, 5 minutes** — VoiceOver (macOS `Cmd+F5` / iOS) · NVDA (Windows, free) · TalkBack (Android). Listen for: buttons announced as "button" (not "graphic"/"div"); fields announcing label + state ("Email, edit text, required"); errors announced when they appear; headings spoken with level.
2. **Keyboard only** — mouse away, touch off. Every action reachable; focus visible at every step; no focus trap; `Esc` closes modals; `Enter` activates buttons, `Space` toggles checkboxes.
3. **OS reduced-motion** — toggle the system setting and re-walk the flow. A CSS branch that exists in source is not proof the rendered motion actually stops.
4. **Zoom / reflow** — 200% zoom and a 320px-wide viewport: no content lost, no horizontal scroll (WCAG 1.4.10 Reflow, Level AA).

## Output format

```
## A11y quick-check — <screen / component> — <date>

### Lane A — machine-resolvable
axe-core: <X> violations (<rule-id> ×N, …) | SKIPPED (no harness)
Lighthouse a11y: <score>/100 + failing audits | SKIPPED
contrast (computed from tokens): 6 pairs checked · 2 fail
  - `Button.vue:31` disabled: #b3b3b3 on #fff → 2.14:1 ✗ AA (needs 4.5:1) — WCAG 1.4.3 (AA)
target-size: axe clean (2.5.8 AA, 24×24) · house 44 target: 3 below (measured)

**BLOCKERS:** `Modal.vue:8` no focus trap, Tab cycles the page behind it — WCAG 2.4.3 (A) · `CrudActions.vue:19` icon-only submit has no accessible name — axe `button-name`, WCAG 4.1.2 (A)
**HIGH:** `OrderForm.vue:55` errors not tied to inputs (`aria-describedby` absent) — WCAG 3.3.1 (A) · `Page.vue:12` heading skip h1 → h3 — axe `heading-order`, WCAG 1.3.1 (A)
**MEDIUM:** `Toolbar.vue:44` close-button border-box 32×32 — passes 2.5.8 (AA), below the house 44 target
**LOW:** `Card.vue:7` decorative icon lacks `aria-hidden="true"`

### Lane B — human runbook (NOT RUN — requires a person)
screen-reader · keyboard-only · OS reduced-motion · 200% zoom / 320px reflow
Emitted above; nothing in this lane is claimed by this run.

### Recommendations (ordered)
1. Add `aria-label` to the icon-only buttons (closes 3 Lane-A findings).
2. Add focus trap + Esc handler to the modal (closes 2).
3. Raise disabled-state token to ≥ 4.5:1.

### Coverage (which lane actually ran — honesty footer)
Lane A: axe ✓ · contrast ✓ (default + hover + disabled; focus SKIPPED — token unresolved)
        · semantics ✓ · reduced-motion ✓ · target-size ✓
Lane B: NOT RUN (human lane) — screen-reader, keyboard, OS reduced-motion, zoom/reflow
Not validated: everything in Lane B. Do not read this run as "the screen is accessible".
```

Any check that did not run prints `SKIPPED (<why>)` or `NOT RUN (human lane)` — never an empty (implicitly-passing) section. The `Not validated:` line names the whole unclosed lane so nobody reads a Lane-A pass as a clean screen.

## Inputs

- Screen / component path (or "the changed files in this PR").
- The token source (required for computed contrast — without it, contrast is `SKIPPED (no token source)`).
- Optional: WCAG level target (default **AA** — which means 2.5.8/24×24 for targets, not 2.5.5/44).

## Outputs

- Inline PR comments OR `ai/audits/a11y-<scope>-<date>.md`.

## Failure modes

- **Auto-tool said clean → declared good.** axe cannot see focus order quality, announcement wording, or whether motion actually stopped. That is Lane B, and Lane B did not run.
- **A AAA criterion quoted as the AA floor.** Claiming AA against 2.5.5 both over-reports the requirement and hides that 2.5.8 — with its Spacing exception — was never evaluated.
- **"Verified 44×44 with axe."** axe's `target-size` implements 2.5.8 at 24×24 and passes everything between the two. The named tool cannot verify the claimed threshold.
- **Contrast asserted, not computed.** A ratio nobody computed is a guess with a colon in it.
- **Tested on macOS VoiceOver only** — iOS VoiceOver behaves differently.
- **`aria-label` reported missing on an element with visible text** — visible text works, and a label that differs from it breaks WCAG 2.5.3 (Label in Name).
- **Tap target measured in CSS, not as a rendered border-box** — padding miscounts, and the hit area is what the criterion is about.

## Related

- `@accessibility-auditor` *(frontend pack)* — full audit; this skill is the resolvable in-pack fast-pass and the a11y lane `/design-review` runs. Escalate only when the frontend pack is installed.
- `platform-conventions-audit` *(mobile pack)* — owns the NATIVE a11y floor and the platform tap-target minimums; this skill is web-DOM-shaped and routes native surfaces there.
- `motion-audit.md` — the reduced-motion inventory; this skill checks the branch exists, `motion-audit` checks every animation against it.
- `design-token-audit.md` — a token swap must not drop contrast below AA; that skill's colour-swap halt delegates the measure here.
- `ui-design-sweep.md` — consumes these findings as `lift-contrast` / `align-focus-ring` / `clarify-affordance` / `expand-tap-target`.
- `@ux-reviewer` — overlap on flow + content quality.
