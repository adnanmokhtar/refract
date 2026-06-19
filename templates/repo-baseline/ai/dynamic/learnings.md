# Learnings (raw observation sink)

Append-only sink for low-confidence raw observations and corrections gathered during AI-assisted work. This is the FIRST rung of the persistence pyramid (`session-context → ai/dynamic/learnings.md → ai/conventions.md`). Entries here are unproven — a single thing noticed once, or one "user told us no, do it this way" correction. Once the same learning recurs **3 times**, the `knowledge-curator` agent promotes it to a formal `ai/conventions.md` entry and marks the original `PROMOTED`.

Distinct from `learned-patterns.md` (which watches recurring *code shapes* for promotion to `ai/patterns/`). This file holds *observations + corrections* about how to work in this repo — lower confidence, higher churn.

## Format per entry

```
### <YYYY-MM-DD> — <short observation>
Source: <session ref / commit / PR / user correction>
Seen: <count of times observed>

Observation: <what was noticed, or the correction the user gave>
Where: <module / layer / file this applies to — or project-wide>

Status: RAW (1-2 occurrences) | PROMOTE_CANDIDATE (3+ occurrences) | PROMOTED → ai/conventions.md | DISCARDED
```

## Promotion threshold

- 3+ occurrences of the same learning → `PROMOTE_CANDIDATE`.
- `knowledge-curator` (or `/learn-from-task`) graduates candidates into `ai/conventions.md`, marks the entry `PROMOTED`.
- Observations that fade or prove wrong → `DISCARDED` with a reason.

## Written by

- `commands/learn-from-task.md` — persistence-pyramid step (session-context → here).
- `.claude/agents/knowledge-curator.md` — appends observations and promotes candidates.

## See also

- `ai/dynamic/learned-patterns.md` — recurring code shapes (→ `ai/patterns/`).
- `ai/dynamic/feedback-learned.md` — user corrections taken (project-scoped feedback mirror).
- `ai/conventions.md` — promotion destination for proven learnings.

## Log

_Empty until the curator agent runs or a human appends. The presence of this file is the invitation._
