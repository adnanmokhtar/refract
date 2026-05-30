---
description: Curator health audit of the ai/ knowledge layer. Invokes knowledge-curator to find stale dynamic/ entries (>30d, no progress), conventions the code no longer follows, patterns nothing references, dead ADRs, and Tier-1 derived files that drifted from their sources. Read-only — reports findings + recommended promotions/archivals; never rewrites without confirmation. Phase-6 maintenance.
kind: command
pack: learning
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

1. **Stale `dynamic/` entries** — `learned-patterns.md` / `decisions-pending.md` / `feedback-learned.md` rows older than 30d with no progress → recommend promote (`/promote-pattern` / `/promote-decision`) or archive to `ai/dynamic/changelog.md`.
2. **Unfollowed conventions** — for each rule in `ai/conventions.md`, spot-check the code still follows it (grep the cited idiom/path); flag conventions the code has drifted away from → recommend re-confirm or update.
3. **Unreferenced patterns** — `ai/patterns/<name>.md` that no code/rule/command references → flag as candidate for archival.
4. **Dead ADRs** — `ai/decisions/*` superseded by a later decision but not marked `superseded`.
5. **Derived-file drift** — `_session-digest.md` / `_convention-cheatsheet.md` / `_decision-index.md` older than their sources (`ai/conventions.md`, `ai/decisions/`, `ai/status.md`) → recommend regen (the `audit-setup.sh` C2f freshness check enforces this at gate time).
6. **Budget** — `ai/` ≤ 50 files, each ≤ 300 lines (M3 ceiling); flag files over budget for the curator to archive/split.

## Output (brief)

A categorized report: stale entries (with promote/archive recommendation), drifted conventions, unreferenced patterns, dead ADRs, derived-file staleness, budget breaches. With `--fix`: the safe actions taken + what was left for human judgement.

## Halts

- None — read-only by default. `--fix` only applies unambiguous mechanical actions (promotions of clearly-resolved items, derived-file regen, archival of >90d dead entries); anything requiring judgement is reported, not done.

## See also

- `/promote-pattern` · `/promote-decision` — the graduation actions this recommends.
- `/refresh-knowledge` — re-runs Phase 2 profiling when conventions have drifted materially.
- `knowledge-curator` agent · `ai/dynamic/` · `ai/_session-digest.md`.
