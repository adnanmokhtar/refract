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

## Chat findings shape

When the findings are printed in chat (no report file could be written, or the user asked for them
in chat), each finding is **one line** that opens with its own `path:line`:

```markdown
1. src/billing/invoice.service.ts:42 — <class> · <mechanism: the symbol or value at fault, what goes wrong, and when>.
   Fix: <concrete fix>.
   Verify: <the test or command that proves it>.
```

1. **The line opens with the finding's own site.** A list marker, bold or a severity word may come
   first; nothing else does. The site is the line that is wrong (the handler, the faulty branch, the
   rule line), not the file that loads, calls or configures it, and not the function's first line.
2. **Class and mechanism go on that same line.** Say what goes wrong and when. Never print a headline
   on one line and the mechanism on a *What goes wrong* bullet under it.
3. **Evidence from other files never opens a line.** Put it on the finding's line or after it,
   mid-sentence: "the schema declares it at `config/schema.ts:7`", not "`config/schema.ts:7` declares
   it". A line that opens with a path is a new finding to its reader. The same goes for a bare member
   expression such as `order.total`: start the line with words.
4. **One finding per root cause per site.** Merge sibling sites into one finding with N locations
   (`refute-before-report.md` § 6) only when the root cause **and** the fix are the same. Two health
   checks that fail for different reasons (a missing binary, a wrong port) are two findings, each
   opening with its own `path:line`.
5. **`Fix:` and `Verify:` are indented continuation lines,** as in the required shape above.

The report file keeps the shape its command's Output format defines; this section governs chat.

## Why this is separate from `actionable-next-steps.md`

- `actionable-next-steps.md` → for commands that **fix most things and defer the rest**; its section lists **follow-up slash commands** for the leftovers (`/refactor src/... --focus=...`).
- **this snippet** → for **read-only reviews that fix nothing**; its section orders the **findings themselves** into a by-hand fix-list with file:line + fix + verify.

A command may use both: the `## What to do next` fix-list for the work the human does now, with individual steps that are slash commands where a sibling command does it better.
