---
description: Curator health audit of the ai/ knowledge layer. Invokes knowledge-curator to find stale dynamic/ entries (>30d, no progress), conventions the code no longer follows, patterns nothing references, dead ADRs, and Tier-1 derived files that drifted from their sources. Read-only — reports findings + recommended promotions/archivals; never rewrites without confirmation. Phase-6 maintenance.
kind: command
pack: learning
allowed-tools: [Read, Grep, Glob, Bash]
---

# /audit-knowledge

**One command. Find where the `ai/` knowledge layer has gone stale or drifted from reality.** Knowledge rots silently: a convention the code abandoned, a pending decision nobody resolved, a pattern no module uses. This surfaces all of it so it can be promoted, refreshed, or archived.

## When to use

- Periodically (or via the Phase-6 curator schedule) to keep `ai/` honest.
- Before relying on `ai/` for a big task — confirm it reflects current reality.
- After a burst of feature work that may have outpaced the docs.

## Args

```
/audit-knowledge            # full audit, report only
/audit-knowledge --fix      # additionally apply the safe, unambiguous actions (promotions /
                            #   archivals / derived-file regen) with a summary; never rewrites
                            #   user-authored prose
```

## What happens (via knowledge-curator) — read-only by default

**Dispatch `knowledge-curator` and run its `## Curation duties` 1-6 plus its `## Budgets you enforce`
table. Do not restate them here.** This command's job is *scope*, not method: it is the only entry
point that sweeps the **full** sink set in one pass — `/promote-pattern` and `/promote-decision` each
graduate one named entry, and `/refresh-knowledge` re-derives the profile, so removing this command
removes the sweep. The duties themselves have one owner, and a second copy of "≤ 50 files, each ≤ 300
lines" in this file is a second number to forget to update.

What this command adds on top of the agent:

- **Full-sweep scope** — every sink the curator reads, in one run, rather than one entry by name.
- **The `--fix` boundary** below: which of the curator's recommendations may be applied without a human.
- **The `## What to do next` contract** below: the recommendations re-expressed as an ordered to-do.
- **One report, ranked** — the curator emits findings per duty; this command orders them by what the
  user should do first.

## Output (brief)

A categorized report: stale entries (with promote/archive recommendation), drifted conventions, unreferenced patterns, dead ADRs, derived-file staleness, budget breaches. With `--fix`: the safe actions taken + what was left for human judgement.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the recommendations re-expressed as ONE ordered, numbered to-do — **DO NOW** (clearly-resolved items to promote, dead entries to archive, derived files to regen) → **REVIEW** (drifted conventions / unreferenced patterns needing judgement) → **OPTIONAL** (budget tidy-ups) — each step carrying the `ai/` file + **Action** as a paste-ready command where one exists (`/promote-pattern <name>`, `/promote-decision <id>`, `/refresh-knowledge`) per [`actionable-next-steps.md`](../../../snippets/actionable-next-steps.md), then the closing step (re-run `/audit-knowledge` to confirm the layer is honest). A clean run collapses to a single line ("ai/ is honest — nothing stale"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Halts

- None — read-only by default. `--fix` only applies unambiguous mechanical actions (promotions of clearly-resolved items, derived-file regen, archival of >90d dead entries); anything requiring judgement is reported, not done.

## See also

- `/promote-pattern` · `/promote-decision` — the graduation actions this recommends.
- `/refresh-knowledge` — re-invokes the extraction engine and rewrites the oracle when conventions have drifted materially.
- `knowledge-curator` agent · `ai/dynamic/` · `ai/_session-digest.md`.
