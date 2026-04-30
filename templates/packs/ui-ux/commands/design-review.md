---
description: Review UI changes for UX, design system compliance, and accessibility in parallel.
---

# /design-review [path|screenshot]

Audit command. Three reviewers run in parallel against changed UI files (or a provided screenshot). Phases 1-3 + 6 dominate; Phase 4 produces findings; Phase 5 logs the review.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves.** A design review's value is the **ratio of findings to citations**. A finding without a `<file:line>` or `<token>` reference is noise — the implementer cannot act on it, the reviewer cannot defend it, the audit log cannot verify it next pass. "This feels off" is not a finding; it is a smell that the reviewer failed to convert into a fact.

**The agent's job is exactly this:**
1. Walk the changed UI files (or screenshot DOM if available) line by line.
2. For each candidate finding, **cite-or-halt**: produce a `<file:line>` for source-based findings, a `<token-name>` for design-system findings, or a WCAG criterion ID + element selector for a11y findings.
3. If a finding cannot be cited — drop it. Do not promote it to `[opinion]` to keep it on the list. Opinions also need a heuristic anchor (Nielsen N, WCAG SC, declared style guide section).
4. Reviewers contradict — orchestrator picks the strictest cited finding. Never average to make peace.

**The agent does NOT:**
- Write findings like "consider better contrast" without contrast ratio + element + token.
- Flag a token violation without naming the token (e.g., `color.brand.500`) and the raw value (`#336699`).
- Flag an a11y issue from a screenshot alone — DOM semantics need source. Screenshot review explicitly notes "DOM-blind for a11y."
- Fabricate criteria when the repo has no design system. Propose adopting one and stop.
- Pad blocker counts with opinions. Opinions tagged `[opinion]`, violations tagged `[violation]`, never blurred.

**Mechanical halt — hand-wave grep + cite-or-halt rule (mandatory before Phase 5 write):**

Before writing the audit to `ai/audits/<date>-design.md`, the agent MUST grep its own findings for hand-wave language and reject any line that:
- Contains `feels`, `seems`, `might be`, `could be cleaner`, `better UX`, `nicer`, `polish`, `improve` — without a cited token / file:line / heuristic.
- Lacks a `<file:line>` for source-grounded findings.
- Lacks a `<token>` reference for design-system violations.
- Lacks a WCAG SC ID or Nielsen heuristic number for UX/a11y findings.

Any finding that fails the grep is **dropped**, not softened. The audit's value is its citation density; uncited findings dilute it. Report the dropped count in the output (`Dropped (uncited): <N>`) so the user sees what was filtered.

## When to use / NOT to use
- USE: before shipping a new page / component / flow.
- USE: after visual changes that span ≥ 2 components.
- NOT: when there is no design system — propose adopting one and stop (review against undefined criteria = noise).
- NOT: as a substitute for a real design partner on net-new flows; this is a check, not the design itself.

## Phase 1 — Understand
- Resolve scope: `git diff --name-only` for UI extensions, plus any provided screenshot path.
- Confirm intent: full-flow review vs single-component compliance check.

## Phase 2 — Organize
- Decide reviewers: `ux-reviewer`, `design-system-guardian`, `accessibility-auditor` — dispatch in parallel.
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
  - `ux-reviewer` — task flow, affordance, error/empty/loading states, microcopy.
  - `design-system-guardian` — token usage (colors, spacing, typography), reuse vs duplication, naming.
  - `accessibility-auditor` — semantics, focus, contrast, labels.
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

## Failure modes
- "Feels off" without grounding → noise; tie every UX finding to Nielsen / WCAG / declared style guide.
- Recently-introduced raw value flagged as violation → may be intentional; warn before treating as broken.
- Screenshot-only review claiming a11y compliance → impossible; DOM semantics need source files.
- Reviewing against guidelines that don't exist → propose adopting a design system and stop.
- Three reviewers contradict each other → orchestrator picks the strictest; don't average.

## Related

### Patterns
- `ai/patterns/dark-mode.md`
- `ai/patterns/design-systems.md`
- `ai/patterns/motion.md`
- `ai/patterns/rtl.md`
- `ai/patterns/theming.md`

### Rules
- `.claude/rules/ui-principles.md`
