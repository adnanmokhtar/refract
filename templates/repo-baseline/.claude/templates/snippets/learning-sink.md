---
purpose: The ONE canonical learning sink set — the 9 append-only raw sinks `/learn-from-task` writes and `knowledge-curator` promotes from. Every consumer links here instead of restating the table, so the producer and the promoter can never silently diverge on WHERE an observation lands or WHAT it graduates to.
imported-by: templates/packs/learning/commands/learn-from-task.md (the command; pack-scoped, there is no root commands/learn-from-task.md — verify-global-scope keeps pack commands out of the global surface) + templates/packs/learning/agents/knowledge-curator.md (the curator — one copy since Phase 6; installed by the always-on learning pack).
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
| `ai/dynamic/decisions-pending.md` | informal decisions awaiting validation   | `<ADR home>/<NNNN>-<slug>.md` at `VALIDATED` (≥2 weeks, ≥1 implementation); the home is the one `adr-index.py --list` detects, `ai/decisions/` only when the project has none |
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

## Additional writers: review dismissals (calibration half of the loop)

`ai/dynamic/review-dismissals.jsonl` holds every dismissed review finding: refuted by the verifier
(`persist-verdict.sh` writes it as the refute verdict lands) or dismissed by a human as `accepted-risk` /
`false-positive` (`.claude/scripts/review-dismissals.py dismiss`, which `test-lock.sh` asks you to
approve). Like `_scorecard.md` it is NOT in the sink set above: machine-written JSONL (record format in
the script's docstring), never hand-edited, and nothing is promoted from it directly.
`review-dismissals.py propose --write` derives `ai/dynamic/calibration-proposals.md` (precedent
candidates, detector-demotion candidates), and those reach the formal layer only through the
confirm-list below.

## Confirm-list and the promotion audit line

Every promotion (a pattern, an ADR, a convention, a glossary term, a rule, a sensor, a precedent) passes
one human confirmation and leaves one audit line. Candidates come from three places: the run's diary
(`ai/runs/<run>/ledger.md` § Diary: Deviations, Tradeoffs, Open), the sinks above at their thresholds,
and `calibration-proposals.md`. `/learn-from-task` shows them as a **confirm-list**, one numbered line
each (candidate · proposed target · evidence); the human keeps, edits or drops each, and only kept
items are written.

A **rule** is prose an agent reads (`.claude/rules/<rule>.md`); a **sensor** is a check that runs (a
hook, a lint script, a test). A lesson whose subject a script can check (`memory-hygiene-scan` §7,
KN-26) is proposed as a sensor first; prose is the fallback, not the default.

Each kept item appends ONE line to `ai/dynamic/promotions.md` (append-only and never pruned, unlike
`changelog.md`, whose 200-line prune would lose the trail):

```
- <YYYY-MM-DD> · by <who confirmed> · <rule|sensor|precedent|pattern|adr|convention|glossary> <target path> ← <source: <sink>:<line> | ai/runs/<run>/ledger.md#Diary | calibration-proposals.md:<line>> · evidence: <file:line>[, …] · confirmed: "<the human's words>"
```

Who (`by`: the human's name, `git config user.name` when unstated), when (the date), from which
evidence (source and evidence), what (kind and target). A promotion without its line is half-done:
the promote commands' Validate phase greps for it.

## Reading the sinks back

Since learning pack v1.4.0 these files are also **indexed for retrieval**: `/recall <query>` (and
the opt-in `recall-inject.sh` hook) run BM25 over this same set plus the formal layer and return
ranked `path:line` pointers. That adds **no sink and no store** — the index is a derived cache at
`.claude/_memory-index.json`, gitignored and rebuilt from these files, and the table above is
unchanged. Retrieval is what makes the curator's archival budgets affordable: with `ai/audits/**`
indexed, "archived" stops meaning "gone".

If you change a sink here, it changes everywhere this snippet is linked (see `imported-by:`
above) — there is no second copy to keep in sync.
