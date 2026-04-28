# Interaction log

High-level summary of completed AI-assisted tasks across sessions. Different from `session-log.md` (raw branch + files-changed dump): this is the curated "what was actually accomplished + what was decided + what was learned" record.

## Why this exists

Without it, every session starts cold. With it, the next session knows: this feature was attempted last week and the user wanted approach X, this bug was hit twice and the fix is Y, this refactor is in progress at file Z.

## Format per entry

```
### <YYYY-MM-DD> — <task name / one-line summary>
Type: feature | bug | refactor | spike | ops | review
Status: COMPLETE | IN_PROGRESS | ABANDONED
Files touched: <count + top paths>

What was done:
<2-3 sentences>

Decisions made:
- <decision> (→ if formal, link to ADR or pending-decision entry)
- ...

Patterns followed:
- <pattern from ai/patterns/ or learned-patterns.md>

Patterns introduced:
- <if any new pattern emerged → link to entry in learned-patterns.md>

User corrections / feedback:
- <if user redirected the AI → link to feedback-learned.md entry>

Open follow-ups:
- <issue / PR / TODO with owner + deadline>
```

## Curation rules

- Append after each significant task (`/learn-from-task` does this automatically).
- Don't log trivial sessions (one-line edits, formatting fixes).
- Aim for 3-7 entries per week of active development.
- Archive entries older than 90 days to `ai/audits/interaction-log-archive-YYYY-Q.md`.

## What this enables

- "Did we try this approach before?" → grep here first.
- New team member's first read → 90 days of decisions in one place.
- `business-auditor` agent → cross-references interactions against project goals to find drift.
- Performance review for AI-assisted work → measurable record of what shipped.

## See also

- `ai/dynamic/session-log.md` — raw per-session diff record (lower abstraction).
- `ai/status.md` Recent Changes — even higher-level (formal release-notes-shaped).
- `ai/dynamic/decisions-pending.md` — informal decisions awaiting formalization.
