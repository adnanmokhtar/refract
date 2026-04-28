---
description: Run accessibility-auditor against current UI changes; ground with axe if installed.
---

# /a11y-audit [path]

Audit command. Static + (optional) automated a11y pass on changed UI files. Phases 1-3 + 6 dominate; Phase 4 produces findings (no code edits); Phase 5 logs the audit; Phase 7 captures patterns.

## When to use / NOT to use
- USE: after any visible UI change (component, page, modal, form).
- USE: before merging a PR that adds new interactive elements.
- NOT: backend-only / tooling-only changes — no UI surface to audit.
- NOT: as a substitute for manual keyboard + screen-reader walkthrough — automated tools cover ~30%.

## Phase 1 — Understand
- Resolve scope: `git diff --name-only` filtered to UI extensions (`.tsx`, `.vue`, `.svelte`, `.html`, framework-specific). If a path arg is given, use that.
- Confirm intent: full audit vs incremental on this change-set.

## Phase 2 — Organize
- Decide automated tooling: `@axe-core/playwright` if in deps AND a Playwright config exists.
- Decide reviewer: `accessibility-auditor` agent for semantics/flow; axe for ground-truth contrast/ARIA.

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
- If axe is present, run automated pass on affected routes:
  ```bash
  npx playwright test --grep "@a11y" || npx playwright test tests/a11y/
  ```
- Merge agent findings + axe violations. Dedupe (axe is ground truth on contrast / ARIA names; agent catches semantics + flow).
- Print findings table grouped by severity:
  ```
  file:line     severity   rule                fix
  Button.tsx:24 blocker    button-name         Add aria-label or visible text
  Modal.tsx:18  serious    focus-trap          Trap focus inside modal while open
  Form.tsx:55   moderate   label-association   <label htmlFor> must match input id
  ```

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-a11y.md` — write the findings report (timestamped, append-only history).
- `ai/dynamic/changelog.md` — one-line: `a11y audit on <scope>: N blockers, M serious`.

## Phase 6 — Validate
- Each blocker has a concrete fix proposal (not just a finding).
- Footer reminder is present: `Automated coverage ~30%. Run keyboard-only walkthrough + screen reader (VoiceOver / NVDA) before shipping.`
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

## Failure modes
- Axe in headless Chrome misses focus order — manual keyboard walk is non-negotiable; never claim "all clear" on axe alone.
- `aria-label` on a `<div>` doesn't make it a button. Use semantic HTML first; ARIA is patching, not the cure.
- Color-contrast checked only on default theme → re-test ALL themes (dark mode, high-contrast, brand variants).
- Dynamic content (toasts, dialogs) without `aria-live` → axe won't flag missing announcements; agent must.
- Auto-suggesting fake alt text → hallucination risk; leave decorative images empty, ask user for real alt otherwise.
