---
purpose: The ONE canonical learning sink set — the 8 append-only raw sinks `/learn-from-task` writes and `knowledge-curator` promotes from. Every consumer links here instead of restating the table, so the producer and the promoter can never silently diverge on WHERE an observation lands or WHAT it graduates to.
imported-by: commands/learn-from-task.md (root) + templates/packs/learning/commands/learn-from-task.md (pack mirror) + templates/packs/learning/agents/knowledge-curator.md (canonical curator) + templates/repo-baseline/.claude/agents/knowledge-curator.md (installed curator).
---

# Canonical learning sink set (shared, single source of truth)

The learning loop has ONE sink set. Every observation lands in exactly one of the
8 append-only `ai/dynamic/` files below (plus the single failure catalog). `/learn-from-task`
is the **producer** — it writes ONLY these raw sinks. `knowledge-curator` is the **promoter** —
it reads this same superset and graduates mature entries into the formal layer at the stated
threshold. The two writers never diverge on WHERE things go because they share this table.

| Sink (raw, append-only)           | Holds                                   | Promotes to (curator) + threshold |
|-----------------------------------|-----------------------------------------|-----------------------------------|
| `ai/dynamic/learnings.md`         | raw observations + corrections-as-notes | `ai/conventions.md` (managed section) at 3 sightings + ≥2 cited examples |
| `ai/dynamic/learned-patterns.md`  | recurring code shapes                    | `ai/patterns/<name>.md` at status `READY` (≥3 files, ≥2 weeks) |
| `ai/dynamic/feedback-learned.md`  | user corrections taken                   | `.claude/rules/<rule>.md` at `Repeated >= 2` |
| `ai/dynamic/decisions-pending.md` | informal decisions awaiting validation   | `ai/decisions/<NNNN>-<slug>.md` (ADR) at `VALIDATED` (≥2 weeks, ≥1 implementation) |
| `ai/dynamic/drift-log.md`         | code-vs-convention divergence            | mark `RESOLVED` / propose convention update |
| `ai/failures/_index.md`           | approaches that did NOT work             | stays (append-only don't-retry catalog — never delete) |
| `ai/dynamic/interaction-log.md`   | per-task summary (the spine)             | archive entries >90 days |
| `ai/dynamic/changelog.md`         | one-line activity log                    | prune at >200 lines |

If you change a sink here, it changes everywhere this snippet is linked (see `imported-by:`
above) — there is no second copy to keep in sync.
