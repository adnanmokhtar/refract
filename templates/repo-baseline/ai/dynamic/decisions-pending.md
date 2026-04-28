# Decisions pending (informal → formal)

Decisions made in conversation, in PRs, or in standups that haven't yet been written as formal ADRs. This is the holding pen — entries graduate to `ai/decisions/<NNNN>-<slug>.md` once they prove durable.

## Why this exists

Many decisions are made informally and never recorded. Six months later, someone asks "why did we choose X?" and nobody remembers. This file catches them at the point of decision so they can graduate when ready (or be forgotten if they don't survive).

## Format per entry

```
### <YYYY-MM-DD> — <short decision title>
Made by: <person / pair / team>
Source: <conversation / PR #N / standup / Slack thread link>
Lifespan so far: <weeks since first decided>

Context: <what problem prompted this — 2-3 sentences>

Decision: <what was decided — one sentence>

Reasoning: <why this over alternatives>

Alternatives considered: <list>

Code changes that implement it: <file:line + commit refs as they happen>

Status: WATCHING (just decided) | VALIDATED (held up 2+ weeks + ≥2 implementations) | PROMOTED → ADR-NNNN | REVERSED (reason)
```

## Promotion criteria

A decision graduates to formal ADR (`ai/decisions/<NNNN>-<slug>.md`) when ALL of:
- Has held up at least 2 weeks (no reversal, no fundamental questioning).
- Has influenced **≥2** real code changes (same decision reflected in multiple commits or files — filters one-off spikes).
- Is durable enough to outlast people in the room (would survive team rotation).
- Reflects intentional architectural / strategic choice, not a one-off tactical call.

`/promote-decision <id>` triggers the graduation: writes the formal ADR with full structure (Context / Decision / Consequences / Alternatives / See also).

## Why not skip this and write ADRs immediately?

- Decisions are noisy at first; many get reversed within days. Writing an ADR for each = ADR clutter.
- The "incubation period" filters out tactical decisions that don't deserve formal status.
- Formal ADRs in `ai/decisions/` are append-only + numbered + load-bearing; treat them like first-class commits, not chat-room speculation.

## See also

- `ai/decisions/` — formal ADRs (graduation destination).
- `ai/dynamic/interaction-log.md` — task-level decisions referenced from here.
- `.claude/agents/knowledge-curator.md` — agent that prompts promotion when criteria met.
