---
purpose: The ONE canonical learning sink set — the 9 append-only raw sinks `/learn-from-task` writes and `knowledge-curator` promotes from. Every consumer links here instead of restating the table, so the producer and the promoter can never silently diverge on WHERE an observation lands or WHAT it graduates to.
imported-by: templates/packs/learning/commands/learn-from-task.md (the command; pack-scoped, there is no root commands/learn-from-task.md — verify-global-scope keeps pack commands out of the global surface) + templates/packs/learning/agents/knowledge-curator.md (canonical curator) + templates/repo-baseline/.claude/agents/knowledge-curator.md (installed curator).
---

# Canonical learning sink set (shared, single source of truth)

The learning loop has ONE sink set. Every observation lands in exactly one of the
9 append-only `ai/dynamic/` files below (plus the single failure catalog). `/learn-from-task`
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
| `ai/dynamic/vocabulary.md`        | project terms whose meaning is not the obvious one | `ai/core/glossary.md` at 2 independent sightings + ≥1 cited `<file:line>` |

### Why vocabulary is its own sink

A term is not a convention, a code shape, a decision, a drift, or a failure — the other eight sinks
each reject it, and before this row existed a new domain term had nowhere to land. It went into
`learnings.md`, whose promotion target is `ai/conventions.md` (naming *style*), so the project's
`ai/core/glossary.md` was written once at `/setup-project` from the business-domain pack and never
updated again. A glossary that only moves at setup is stale by the second sprint, and every agent
reading it inherits the stale reading.

What belongs here is narrow: a term the codebase uses in a sense the plain English reading would get
wrong, or two terms that look like synonyms and are not. Not every noun in the domain — the entity
table already holds those. The promotion target is the glossary's `## Vocabulary distinctions
(don't conflate)` section, which is exactly the shape this sink produces.

Threshold is **2** independent sightings, not the 3 used for patterns: a code shape needs a third
occurrence to prove it is not coincidence, whereas a term either carries a project-specific meaning
or it does not. The `<file:line>` citation is what separates a real term from a remembered one.

## Additional writer: `/eval` (measurement half of the loop)

`/eval` is the grade to `/learn-from-task`'s capture. It writes exactly ONE sink above —
`ai/dynamic/learnings.md` — and only on failure: every FAIL/REGRESS in an eval run appends a
`RAW` observation naming the GUARD (rule/convention/pattern) the AI broke, so `knowledge-curator`
picks it up on the normal promotion path. `/eval` never writes any other sink and never promotes;
its own recorded outcome is `ai/evals/_scorecard.md` (append-only run history), which is NOT part
of this sink set — it is the regression record, not a promotion source.

## Reading the sinks back

Since learning pack v1.4.0 these files are also **indexed for retrieval**: `/recall <query>` (and
the opt-in `recall-inject.sh` hook) run BM25 over this same set plus the formal layer and return
ranked `path:line` pointers. That adds **no sink and no store** — the index is a derived cache at
`.claude/_memory-index.json`, gitignored and rebuilt from these files, and the table above is
unchanged. Retrieval is what makes the curator's archival budgets affordable: with `ai/audits/**`
indexed, "archived" stops meaning "gone".

If you change a sink here, it changes everywhere this snippet is linked (see `imported-by:`
above) — there is no second copy to keep in sync.
