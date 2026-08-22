---
description: Run accessibility-auditor against current UI changes; ground with axe if installed.
---

# /a11y-audit [path]

Audit command. Static + (optional) automated a11y pass on changed UI files. Phases 1-3 + 6 dominate; Phase 4 produces findings (no code edits); Phase 5 logs the audit; Phase 7 captures patterns.

## The Premise (read this first, internalize, do not deviate)

**Find real issues. No hand-waves.** An audit's job is to surface concrete, fixable a11y violations — each one cited at `<path:line>` with the failing rule named and a concrete fix proposed. Vague gestures ("review focus management overall", "consider improving ARIA usage") are forbidden — they do nothing for the user and burn audit budget.

**The agent's job is exactly this:** resolve the file scope (changed UI files OR an explicit path arg); run the agent + axe (if present) and produce a findings table where every row has `<path:line>`, severity, rule name, concrete fix; group by severity, blockers first; append-only audit log to `ai/audits/<date>-a11y.md`.

**The agent ONLY asks the user when:** an image is decorative-vs-informative ambiguous (never auto-suggest fake alt text); dynamic-content semantics are unclear (`role="status"` vs `role="alert"`); the theme palette is missing token definitions (contrast cannot be verified without them). Everything else — focus order, label association, ARIA name presence, keyboard reachability — is mechanical. Run it, report.

**Lightweight default.** The incremental audit on changed UI files is the default tier: static pass + axe → findings table → audit log entry, no ADR and no rule promotion. Promote to an ADR only on a repeat systemic issue (a rule recurring ≥3× across audits).

## When to use / NOT to use
- USE: after any visible UI change (component, page, modal, form).
- USE: before merging a PR that adds new interactive elements.
- NOT: backend-only / tooling-only changes — no UI surface to audit.
- NOT: as a substitute for a manual keyboard + screen-reader walkthrough. Automation is a **floor**, not a coverage percentage — do not quote a "tools catch N%" figure you have not opened the source for.

## Phase 1 — Understand
- Resolve scope: `git diff --name-only` filtered to UI extensions (`.tsx`, `.vue`, `.svelte`, `.html`, framework-specific). If a path arg is given, use that.
- Confirm intent: full audit vs incremental on this change-set.

## Phase 2 — Organize
- Decide automated tooling: the in-pack **`a11y-scan` skill** owns the axe run (`@axe-core/playwright` if in deps AND a Playwright config exists) — its WCAG 2.2 tag set, its `target-size` enable, its review-items handling. Do not hand-roll a second axe invocation here.
- Decide reviewer: `accessibility-auditor` agent for semantics/flow; axe (via `a11y-scan`) for ground-truth contrast/ARIA.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

A11y-specific:
- Project's design tokens (themes / dark-mode files) — contrast must hold across ALL themes.
- Any prior `ai/audits/<date>-a11y-*.md` — repeat findings = systemic issue.

## Phase 4 — Generate (findings, not code)
- Dispatch `accessibility-auditor` with the resolved file list.
- If axe is present, dispatch the `a11y-scan` skill on the affected routes and consume its report. **Do not write an axe invocation here** — Phase 2 already assigned that run to the skill, which owns the WCAG 2.2 tag set, the `target-size` enable and the route x theme x locale matrix. A second invocation in this file is a second tag set: the two runs disagree, and the disagreement reads as a flaky scanner rather than as two different configurations.
  Carry the skill's **review items** (`results.incomplete`) into the report as their own block — axe could not decide those, and an unresolved review item is not a pass.
  If `a11y-scan` reports `RENDER BLOCKED` (its login-wall halt), this command halts with it. A merged report built on an unauthenticated render grades the login page and calls it the app.
- Merge agent findings + axe violations. Dedupe (axe is ground truth on contrast / ARIA names; agent catches semantics + flow).
- Print findings table grouped by severity:
  ```
  file:line     severity   rule                fix
  Button.tsx:24 blocker    button-name         Add aria-label or visible text
  Modal.tsx:18  serious    focus-trap          Trap focus inside modal while open
  Form.tsx:55   moderate   label-association   <label htmlFor> must match input id
  ```

### Hand-wave mechanical halt (mandatory, all tiers)

Before declaring the report complete, scan every finding for hand-wave language. For each finding, return one of: `closed` (cites `<path:line>` with a concrete fix), `still-open` (vague), `regressed` (claim made without evidence).

**Halt if any finding contains:**

- `etc.`, `...`, `and similar`, `and others`, `various` — open-ended gestures with no enumerated targets.
- `N+` style ranges (`3+ violations`, `multiple issues`) without listing each `<path:line>`. Either enumerate or don't claim.
- `consider`, `might want to`, `could be improved`, `review overall`, `look into` — non-actionable verbs.
- `generally`, `mostly`, `seems to` — hedges. Either the rule fails at `<path:line>` or it doesn't.
- A finding without a `<path:line>` anchor, or without a named rule (axe rule id OR WCAG SC number OR named heuristic).
- A blocker without a concrete fix proposal — the actual replacement code or attribute, not "fix this".
- Auto-suggested fake `alt` text on a non-decorative image — hallucination risk; ask the user, never invent.
- An "all clear" claim based on axe alone, or **any "automation covers N%" figure quoted to justify it**. State the floor, cite no percentage, and run the manual keyboard + screen-reader walk regardless.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-a11y.md` — write the findings report (timestamped, append-only history).
- `ai/dynamic/changelog.md` — one-line: `a11y audit on <scope>: N blockers, M serious`.

## Phase 6 — Validate
- Each blocker has a concrete fix proposal (not just a finding).
- Footer reminder is present, and carries **no** coverage percentage: `Automated coverage is a floor, not a percentage — no scanner judges announcement order, keyboard interaction quality, or context. Run a keyboard-only walkthrough + screen reader (VoiceOver / NVDA) before shipping.`
- No fabricated `alt` text — decorative images stay `alt=""`; ask user for real alt otherwise.

## Phase 7 — Improve
- `/learn-from-task` — capture recurring rule violations.
- If same rule fails 3+ times across audits → queue to `ai/dynamic/learned-patterns.md` as a candidate for a `.claude/rules/a11y-checklist.md` rule.
- If theme contrast fails repeatedly → queue an ADR proposal: token palette overhaul.

## Output format
```
## /a11y-audit — <N> findings (<B> blockers, <S> serious, <M> moderate)

Phase 1 (Understand): scope = <N files>
Phase 3 (Retrieved): siblings + tokens read; axe present = <yes|no>
Phase 4 (Generated): findings table (see above)
Phase 5 (Updated): ai/audits/<date>-a11y.md, changelog
Phase 6 (Validated): each blocker has a fix; manual-walk reminder printed
Phase 7 (Improved): N recurring patterns queued

Status: COMPLETE | BLOCKED on <B> blockers
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (WCAG A/AA failures, keyboard traps, missing labels) → **SHOULD FIX** (AA edge cases / best practice) → **OPTIONAL** (AAA / nice-to-have) — each step carrying `<file:line>` + **Fix** (concrete; cite the WCAG criterion) + **Verify** (the axe rule and/or the keyboard/SR check that proves it), then the closing steps (re-run `/a11y-audit` to confirm it comes back clean, then ship). A clean run collapses to a single line ("No violations — clear to proceed"). The reader must never assemble the next steps themselves.

## Failure modes
- Axe in headless Chrome misses focus order — manual keyboard walk is non-negotiable; never claim "all clear" on axe alone.
- `aria-label` on a `<div>` doesn't make it a button. Use semantic HTML first; ARIA is patching, not the cure.
- Color-contrast checked only on default theme → re-test ALL themes (dark mode, high-contrast, brand variants).
- Dynamic content (toasts, dialogs) without `aria-live` → axe won't flag missing announcements; agent must.
- Auto-suggesting fake alt text → hallucination risk; leave decorative images empty, ask user for real alt otherwise.
