---
description: Review UI changes for UX, design system compliance, and accessibility in parallel.
---

# /design-review [path|screenshot]

> **Not this command? (ANTI-triggers)** — you want the findings FIXED, not listed → `/enhance-ui` (one surface) · `/align-recheck` (mechanical drift) · `/redesign` (the layout) · `/art-direct` (the language). Every route, from a real browser, with axe and console probes → `/ui-crawl`. Measured project-wide quality with an HTML report and baselines → `/ui-sweep`. **This command writes no code and grades no surface it cannot cite.**

Audit command. Three reviewers run in parallel against changed UI files (or a provided screenshot). Phases 1-3 + 6 dominate; Phase 4 produces findings; Phase 5 logs the review.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves.** A design review's value is the **ratio of findings to citations**. A finding without a `<file:line>` or `<token>` reference is noise — the implementer cannot act on it, the reviewer cannot defend it, the audit log cannot verify it next pass. "This feels off" is not a finding; it is a smell that the reviewer failed to convert into a fact.

**The agent's job is exactly this:** walk the changed UI files (or the screenshot DOM if available) line by line; for each candidate finding, **cite-or-halt** — a `<file:line>` for source-based findings, a `<token-name>` for design-system findings, or a WCAG criterion ID + element selector for a11y findings; if a finding cannot be cited, drop it (never promote it to `[opinion]` to keep it on the list — opinions also need a heuristic anchor). When reviewers contradict, resolve it by the protocol below — never average to make peace.

**The contradiction protocol (the one thing the orchestrator does that no single reviewer can).** Three reviewers grade overlapping surface, so they WILL disagree. "Pick the strictest" is a slogan, not a mechanism. Resolve in this fixed order and print which rule fired:

1. **A COMPUTED value beats an asserted one** — a measured contrast ratio, a measured border-box, an axe rule id with a node count outranks a reading of the same element.
2. **A conformance failure beats a house-rule improvement** — a Level-A/AA criterion (level NAMED) outranks a AAA or house target on the same element. They are not the same claim.
3. **The axis OWNER beats a visitor** — tokens/naming → `design-system-guardian`; flow, states, micro-copy, composite-surface completeness → `ux-reviewer`; semantics, focus, contrast, target size → `a11y-quick-check`.
4. **Still tied → BOTH are printed, tagged `[contested]`, with each citation, and the stricter one is what the action plan carries.** An unresolved disagreement is information about the design system, not noise to smooth away.

**The agent does NOT:** write "consider better contrast" without a contrast ratio + element + token; flag a token violation without naming the token and the raw value; flag an a11y issue from a screenshot alone (DOM semantics need source — a screenshot review is explicitly "DOM-blind for a11y"); fabricate criteria when the repo has no design system; or pad blocker counts with opinions. `[opinion]` and `[violation]` are tagged, never blurred.

**Mechanical halt — hand-wave grep + cite-or-halt (mandatory before the audit is written):**

Grep your own findings and reject any line that contains `feels` / `seems` / `might be` / `could be cleaner` / `better UX` / `nicer` / `polish` / `improve` without a cited token, `<file:line>`, or heuristic; that lacks a `<file:line>` for a source-grounded finding; that lacks a `<token>` for a design-system violation; or that lacks a WCAG SC ID / Nielsen heuristic number for a UX or a11y finding. A finding that fails the grep is **dropped**, not softened. Report the dropped count (`Dropped (uncited): <N>`) so the user sees what was filtered.

## When to use / NOT to use
- USE: before shipping a new page / component / flow.
- USE: after visual changes that span ≥ 2 components.
- NOT: when there is no design system — propose adopting one and stop (review against undefined criteria = noise).
- NOT: as a substitute for a real design partner on net-new flows; this is a check, not the design itself.

## Phase 1 — Understand
- Resolve scope: `git diff --name-only` for UI extensions, plus any provided screenshot path.
- Confirm intent: full-flow review vs single-component compliance check.

## Phase 2 — Organize
- Decide reviewers: `ux-reviewer` + `design-system-guardian` (parallel) + the `a11y-quick-check` skill for the a11y lane — all in-pack. (Optional deeper a11y: the `frontend` pack's `accessibility-auditor`, only if installed.)
- If repo lacks design tokens, flag and proceed without compliance checks (don't fabricate criteria).

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Design-specific:
- Project's design tokens (`tailwind.config.*`, `theme.ts`, `tokens.json`, CSS custom properties).
- `ai/patterns/component-library.md` if present.
- Any `ai/audits/<date>-design-*.md` for repeat findings.

## Phase 4 — Generate (findings)
- Dispatch in parallel:
  - `ux-reviewer` — task flow, affordance, error/empty/loading states, microcopy, composite-surface completeness (data-table / dashboard table-stakes vs `ui-design-sweep.md § normalize-surface`).
  - `design-system-guardian` — token usage (colors, spacing, typography), reuse vs duplication, naming.
  - `a11y-quick-check` skill — semantics, focus, contrast (computed), labels, reduced-motion.
- Merge findings. Tag opinions as `[opinion]`, factual violations as `[violation]`.
- Print grouped by severity:
  ```
  UX:
    [opinion]   LoadingState.tsx  Spinner with no caption — consider "Loading orders..."
    [violation] EmptyCart.tsx     No empty state illustration; design system requires one
  Design system:
    [violation] Button.tsx:42     Hex color #336699 — use token color.brand.500
    [violation] Card.tsx:18       Custom 14px font-size — use typography.body.sm
  A11y:
    [violation] Modal.tsx:8       Missing focus trap
    [violation] Form.tsx:55       Label not associated with input
  ```

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-design.md` — write the consolidated review.
- `ai/dynamic/changelog.md` — one-line: `design review on <scope>: N violations across UX/DS/A11y`.

## Phase 6 — Validate
- Every UX finding tied to a heuristic (Nielsen, WCAG, or repo-declared style guide) — no "feels off" critiques.
- Each `[violation]` has a token or rule reference (not just a preference).
- Screenshot-only review explicitly noted as DOM-blind for a11y.

## Phase 7 — Improve
- `/learn-from-task` — capture recurring violations.
- If same token violation appears 3+ audits → queue ADR proposal: enforce token via lint plugin (e.g. `eslint-plugin-tailwindcss`).
- If new design pattern emerged organically → queue to `ai/patterns/component-library.md`.

## Output format
```
## /design-review — <N> violations + <M> opinions

Phase 1 (Understand): scope = <files | screenshot>
Phase 3 (Retrieved): tokens loaded; prior audits scanned
Phase 4 (Generated): UX + DS + A11y findings (grouped above)
Phase 5 (Updated): ai/audits/<date>-design.md, changelog
Phase 6 (Validated): every finding tied to heuristic/token; opinions labeled
Phase 7 (Improved): N recurring patterns queued

Status: COMPLETE | BLOCKED on <N> violations
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (a11y / broken-state / design-system violations) → **SHOULD FIX** (UX + consistency opinions) → **OPTIONAL** (polish nits) — each step carrying `<file:line>` + **Fix** (concrete; cite the token / component / WCAG rule) + **Verify**, then the closing steps (re-run `/design-review` to confirm it comes back clean, then ship). A clean run collapses to a single line ("No violations — clear to proceed"). The reader must never assemble the next steps themselves.

## Failure modes
- "Feels off" without grounding → noise; tie every UX finding to Nielsen / WCAG / declared style guide.
- Recently-introduced raw value flagged as violation → may be intentional; warn before treating as broken.
- Screenshot-only review claiming a11y compliance → impossible; DOM semantics need source files.
- Reviewing against guidelines that don't exist → propose adopting a design system and stop.
- Three reviewers contradict each other → orchestrator picks the strictest; don't average.

## Related

### Commands (finding-class → the command that fixes it)
- token / wrapper / hierarchy / state drift → `/ui-sweep` (project-wide, measured) or `/enhance-ui` (one surface).
- a mechanical a11y class across every route → `/ui-crawl` to detect, `/ui-crawl-fix` to close.
- the page needs rebuilding inside the existing language → `/redesign`.
- the language itself is the problem (generic / dated / un-ownable) → `/art-direct`.

### What this command does NOT own
It is **read-only** and it does not decide taste. It orchestrates `ux-reviewer` + `design-system-guardian` + the `a11y-quick-check` skill, then reconciles them: when two reviewers contradict each other, the **strictest CITED** finding wins and the uncited one is dropped into the `Dropped (uncited): <N>` count — never averaged.

### Rules
- `.claude/rules/ui-principles.md` — the closed 16-axis catalog every finding is named against.

## Related

Finding-class → the command that fixes it:
- `/align` — enforce a cited design-system / a11y violation against an existing token or rule (no creative work).
- `/enhance-ui` — fix a cited UX / design-system finding within the existing language.
- `/redesign` — when the finding is **structural** (broken IA, missing/broken states, wrong layout).
- `/art-direct` — when the review concludes the design has **no point of view** (generic / dated / forgettable). Which of the last two applies is decided by `redesign.md § Phase 1 — THE LANGUAGE-OR-COMPOSITION TEST`, never by asking the user.

Patterns: `ai/patterns/dark-mode.md` · `design-systems.md` · `motion.md` · `rtl.md` · `theming.md`. Rule: `.claude/rules/ui-principles.md`.
