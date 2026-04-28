---
artifact: import-tiers
purpose: Define what HOT / WARM / COLD mean for orchestrator imports, so the model can load only what's needed for the active phase.
imported-by: commands/setup-project.md (frontmatter), every phase that loads files.
---

# Import tiers

A tiered loader is the difference between "every session pays for everything" and "every session pays for the floor + what's relevant." This file is the contract.

## Tier definitions

| Tier  | When loaded                          | What goes here                                              | Budget |
|-------|--------------------------------------|-------------------------------------------------------------|--------|
| HOT   | Every session, before any phase      | Rules that gate ALL phases; cheap to load; high-leverage    | ≤ 600 lines combined |
| WARM  | When the relevant phase is active    | Phase files; track loader; persona; capabilities index      | per-phase ≤ 600 lines |
| COLD  | Only on explicit demand              | Reference templates; canonical examples; appendices         | unbounded |

## Why tier matters

Without tiers, "imports: [list of 26 files]" loads 26 files. With tiers:

- A simple `/setup-project` invocation in CREATE mode loads HOT (5 files) + WARM phase 1, 2, 3, 4, 5, 6 (the phases that actually run). Skips Phase 4-DEEP variants (REFINE-only). Skips appendices. Skips canonical-command-template (only consumed BY phase 4 when generating commands).
- A `/setup-project --refine` run loads HOT + WARM 1-6 + WARM 4.6-DEEP, 4.7-DEEP, 4.8-DEEP.
- `/setup-project-health` loads only HOT + the checklist + observability.

## How loading actually works (today)

The Claude Code agent reads `commands/setup-project.md`'s frontmatter and inlines the `@-import` references it encounters in the prose. Tier annotation is a HINT to the agent: "if your task doesn't touch phase X, don't read its file."

Today, agents may still load all imports if the prose references them indirectly. Future work (M5+):

- A loader script that strips out non-active-tier imports before the model sees the document.
- Per-phase manifest files that declare exactly which tier-2/3 files they need.

For now: tiers are documented intent. The model is expected to honor them.

## Hard rules (tier discipline)

- HOT must be ≤ 600 lines combined. Crossing that = a tier-2 candidate is mis-classified as tier-1.
- A WARM file pulling a COLD file at runtime is fine; doing so AT IMPORT TIME defeats the tier.
- Phase X must NEVER load Phase Y's file directly — always go through the orchestrator.

## Tier audit

`/setup-project-health` includes a tier-budget check (C7 — knowledge-base discipline). If HOT exceeds the budget, the report flags it; the user re-classifies one rule down to WARM.

## Adding a new import

1. Decide tier based on these questions:
   - Does it gate every phase? → HOT
   - Does only one phase need it? → WARM
   - Is it a reference / template / example? → COLD
2. Add to the appropriate list in `commands/setup-project.md` frontmatter.
3. If HOT: confirm the combined HOT line count stays ≤ 500 by running `wc -l` on the HOT files.
