---
purpose: Canonical closing section for read-only REVIEW / feedback commands (review-changes, design-review, security-audit, db-audit, perf-audit, a11y-audit, i18n-audit, threat-model, migration-review, audit-*). These commands produce FINDINGS the user must act on by hand — so the review is not finished until it ends with a clear, ordered "What to do next" to-do list. Sibling to actionable-next-steps.md (which routes DEFERRED findings of FIX-commands into follow-up slash commands); this snippet orders the FINDINGS THEMSELVES into a fix-list.
---

# What to do next — review action-plan contract

A read-only review's whole value is the list of things to fix. The reader must never have to scroll back through severity groups and assemble their own to-do. So **every review/feedback command MUST end with a section titled `## What to do next`** — the findings re-expressed as one ordered, numbered sequence of actions.

## Required shape

```markdown
## What to do next  (do these in order)

MUST FIX — <gate consequence, e.g. "merge is blocked until these are done">:
1. <path>:<line> — <one-line issue in plain words>.
   Fix: <concrete fix — snippet / command / named pattern>.
   Verify: <test name or command that proves it's fixed>.
2. ...

SHOULD FIX — fix now unless you have a reason not to:
3. <path>:<line> — <issue>.
   Fix: <fix>.

OPTIONAL — safe to defer:
4. <path>:<line> — <issue>.
   Fix: <fix>.

Then:
5. Re-run `/<this-command>` — confirm the verdict / report comes back clean.
6. Run `/learn-from-task` to capture what was learned.
7. <ship step — open the PR / proceed with the change>.
```

## The rules

1. **Order by priority, not by severity-group.** MUST FIX (every blocker) → SHOULD FIX (every request) → OPTIONAL (every nit). Number continuously (1, 2, 3 …) so it reads as one sequence, not three lists.
2. **Each step is self-contained:** the `<path>:<line>`, the **Fix** (concrete — never "consider X"), and the **Verify** (required on every MUST-FIX step; a check or test that proves it's done).
3. **End with the closing steps:** re-run this command to confirm it comes back clean, `/learn-from-task`, then the ship step.
4. **Clean run → one line, not an empty section:** e.g. `What to do next: No blockers — clear to proceed. Optional: <nit> at <path>:<line>.`
5. **No new advice.** The action plan is a re-ordering of findings that already passed the command's `cite-or-drop` / cite-or-halt discipline — never a place to add un-cited suggestions.
6. **When a finding is better handed to another command** (e.g. a deferred refactor batch), the step IS a paste-ready slash command per [`actionable-next-steps.md`](actionable-next-steps.md) — the two contracts compose (fix-list for the by-hand work, follow-up commands for the rest).

## Why this is separate from `actionable-next-steps.md`

- `actionable-next-steps.md` → for commands that **fix most things and defer the rest**; its section lists **follow-up slash commands** for the leftovers (`/refactor src/... --focus=...`).
- **this snippet** → for **read-only reviews that fix nothing**; its section orders the **findings themselves** into a by-hand fix-list with file:line + fix + verify.

A command may use both: the `## What to do next` fix-list for the work the human does now, with individual steps that are slash commands where a sibling command does it better.
