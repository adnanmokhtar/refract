---
description: After a task finishes, capture decisions made / patterns followed / patterns introduced / user corrections into the learning files. Run before `/clear` or end of session.
---

# /learn-from-task

Closes the learning loop. Without this, every session ends and the lessons evaporate. This is itself the canonical Phase 7 (Improve) implementation that other commands hand off to.

## Phases applied

1, 3, 5. The whole command IS Phase 7 (Improve) for the just-finished task; internally it still runs Understand → Retrieve → Update.

## When to use / NOT to use

- USE: after completing a feature / bug fix / refactor / spike.
- USE: before `/clear` or session end if the work was substantial.
- USE: after a user has corrected the AI multiple times in a session.
- USE: after making a decision in chat that wasn't yet recorded.
- NOT: after trivial sessions (one-line edits, lint fixes, formatting).
- NOT: mid-task (wait until the unit of work is done).

## Phase 1 — Understand (the just-completed task)

Reflect on the just-completed task. Answer (in your head as the AI):
- What was the goal?
- What was actually done? (Files touched, behavior changed, tests added.)
- What decisions were made along the way? (Approach choices, library picks, trade-offs.)
- Which existing patterns were followed?
- Did any new pattern emerge from this task?
- Did the user correct the approach? What was the correction?
- Is there a follow-up the next session should know about?

If the task was trivial (one-line edit, lint fix, formatting): refuse + suggest skipping. Don't pollute the learning log with noise.

## Phase 2 — N/A (no decomposition)

This is a reflection + write command, not a multi-step plan.

## Phase 3 — Retrieve (read the right context)

ALWAYS:
- `ai/dynamic/interaction-log.md` — recent entries (style, format).
- `ai/dynamic/learned-patterns.md` — does this new shape match an already-watching entry (increment count) or is it new (add)?
- `ai/dynamic/feedback-learned.md` — does this user correction repeat a known one (increment Repeated counter) or is it new?
- `ai/dynamic/decisions-pending.md` — does this decision relate to a pending one?
- `ai/status.md` current `Updated:` date for context.

## Phase 4 — N/A (no code generation)

This command produces knowledge entries, not code.

## Phase 5 — Update (persist changes to the knowledge base)

1. Append entry to `ai/dynamic/interaction-log.md` using the format:
   ```markdown
   ### <YYYY-MM-DD> — <task name>
   Type: feature | bug | refactor | spike | ops | review
   Status: COMPLETE | IN_PROGRESS | ABANDONED
   Files touched: <count> (<top paths>)

   What was done:
   <2-3 sentences>

   Decisions made:
   - <decision> (→ link if formal ADR planned)

   Patterns followed:
   - <link to ai/patterns/<name>.md>

   Patterns introduced:
   - <if any new shape emerged → entry to learned-patterns.md>

   User corrections / feedback:
   - <if user redirected → entry to feedback-learned.md>

   Open follow-ups:
   - <follow-up + owner + deadline>
   ```

2. If decisions emerged that aren't yet ADRs: append to `ai/dynamic/decisions-pending.md`.

3. If new patterns emerged: append to `ai/dynamic/learned-patterns.md` with status `WATCHING` (and occurrence path = the just-touched files). If a watching entry already covers this shape, increment its occurrence count.

4. If user corrected the AI: append to `ai/dynamic/feedback-learned.md` (with `Repeated: 1` or increment if existing).

5. If the task surfaced a drift between code and convention: append to `ai/dynamic/drift-log.md`.

6. Append a one-line summary to `ai/dynamic/changelog.md`.

## Phase 6 — Validate (verify correctness)

- New `interaction-log.md` entry has Type, Status, Files touched, all sections (even if empty placeholders).
- learned-patterns.md occurrence increments are correct (didn't double-count).
- feedback-learned.md `Repeated` counter is correctly incremented (not reset).
- changelog.md entry is a single line.

## Phase 7 — Improve (this command IS the loop closer)

After this runs, downstream automation handles propagation:
- Next session's `session-start.sh` surfaces the open follow-ups.
- The next session's agents read `feedback-learned.md` and don't repeat the corrected mistake.
- `pattern-emergence-watcher` sees the new entry and starts counting occurrences.
- `knowledge-curator` (on schedule) graduates anything that meets promotion criteria via `/promote-pattern`.
- `/refresh-knowledge` quarterly catches the long-term changes the per-task entries don't.

This command is the foundation; nothing further needed.

## Output

```
## /learn-from-task — captured

Phase 1 (Understand): reflected on task — feature/orders-perf, COMPLETE.
Phase 3 (Retrieved): interaction-log.md last 5 entries, learned-patterns.md (1 watching match), feedback-learned.md (no match).
Phase 5 (Updated):
  - interaction-log.md (+1 entry)
  - decisions-pending.md (+1: BullMQ over Redis Streams)
  - learned-patterns.md (+1 WATCHING: idempotency-key cache wrapper)
  - feedback-learned.md (no entries this task)
  - drift-log.md (+1: console.log in billing.service.ts)
  - changelog.md (+1 line)
Phase 6 (Validated): all entries shape-conformant.
Phase 7 (Improved): downstream handlers (session-start, watcher, curator) will pick up automatically.

Decisions queued for ADR consideration:
- "Prefer BullMQ over Redis Streams for our queue layer" (will graduate after 2 weeks if held)

Patterns queued for promotion watch:
- "Idempotency-Key + cache lookup wrapper" (1st occurrence: src/modules/orders/place-order.use-case.ts)

User corrections recorded:
- (none in this task)

Drift findings added:
- src/modules/billing/billing.service.ts:42 uses console.log (rule violation) — high severity, OPEN

Follow-ups for next session:
- TODO: complete the Stripe webhook handler — currently stubbed
- TODO: add e2e test for the new endpoint

Status: COMPLETE
```

## Failure modes

- **Task was trivial**: refuse + suggest skipping ("nothing meaningful to learn here").
- **Multiple unfinished tasks in session**: ask user which to learn from (or "all").
- **Decisions disagree with existing ADR**: flag conflict; either ADR is wrong, decision is wrong, or this is a deliberate supersession (write a new ADR).
- **Pattern entry duplicates an existing PROMOTED pattern**: don't add to learned-patterns; mention in interaction-log only.

## See also

- `ai/dynamic/interaction-log.md` — main destination.
- `ai/dynamic/learned-patterns.md`, `feedback-learned.md`, `decisions-pending.md`, `drift-log.md` — supporting destinations.
- `knowledge-curator` agent — graduates these entries to the formal layer over time.
- `/promote-pattern` — promotes ready patterns to formal docs.
