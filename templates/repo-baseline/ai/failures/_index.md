# Failure catalog (don't-retry index)

Append-only catalog of approaches that were tried and **failed** — so future agents don't burn time and tokens repeating them. If an approach is listed here, it was already attempted in this repo and did not work; read the "What to do instead" before reaching for the same idea.

Written by `commands/execute-plan.md`, `commands/verify-plan.md` (on PLAN VIOLATED), and `commands/learn-from-task.md` (the failed-approach rung of the persistence pyramid).

## Format per entry

```
### <YYYY-MM-DD> — <short label for the failed approach>
Source: <session ref / commit / PR / plan id>
Where: <module / layer / file — or project-wide>

What was tried: <the approach, concretely>
Why it failed: <error / wrong result / contract violation / perf regression>
What to do instead: <the correct alternative, or "open question" if unknown>

Status: ACTIVE (still a trap) | RESOLVED (now works — see note) | SUPERSEDED
```

## Lifecycle

1. An approach fails during execution / verification → append entry with status `ACTIVE`.
2. Future agents read this index before planning the same area.
3. If the approach later becomes viable (dependency shipped, contract changed), mark `RESOLVED` with a note — keep the entry for history.

## See also

- `ai/dynamic/learnings.md` — raw observations + corrections.
- `ai/dynamic/drift-log.md` — convention divergence (related signal).
- `.claude/agents/knowledge-curator.md` — agent that curates these records.

## Catalog

_Empty until a failed approach is recorded. Append-only — entries are never deleted, only re-statused._
