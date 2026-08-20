---
name: data-engineering-principles
description: Data Engineering Principles
kind: rule
pack: data-engineering
severity: must
applies-to: data-engineering-track, every-code-writing-task-in-data-engineering
---

# Data Engineering Principles

> **Hard rule.** Every model declares its grain in one sentence and proves it with a uniqueness probe before it is exposed. Every model that a human or a dashboard reads ships assertions in the same commit. Every metric has exactly one definition. Backfills write to a shadow target and cut over reversibly — never in place. A wrong number is a production incident, not a data-team chore.

Prevents the failure that has no stack trace: the pipeline is green, the tests pass, the dashboard trends, and the number is wrong. Code defects announce themselves; data defects are believed.

## Must

- **Declare the grain** of every model in one sentence, in the model's own documentation: "one row per `<entity>` per `<qualifier>`". Prove it with a duplicate-key probe against the built table before the model is consumed. The primary-key declaration is not proof — most analytical platforms do not enforce it.
- **Classify every measure** as additive, semi-additive, or non-additive next to the column. Aggregate semi-additive measures with a period-end rule across time; store ratios as numerator and denominator, never pre-divided.
- **Respect layer direction**: staging reads sources only (rename, cast, coerce sentinels, dedupe — no joins across sources, no business logic); intermediate reads staging and intermediate; marts read intermediate and staging. Nothing reads a raw source past the staging layer.
- **Reference upstream through the framework's reference function.** A hardcoded fully-qualified table name is invisible to the dependency graph, so build order and lineage are both silently wrong.
- **Every incremental model states four things next to the code**: its unique/merge key, its incremental predicate on the *event* timestamp, its late-arrival lookback window, and the condition that requires a full refresh. Merge on the key so a reprocessed row replaces rather than duplicates.
- **Ship assertions with the model, in the same commit**: uniqueness on the declared grain, not-null on every join/filter column, referential integrity to every dimension referenced, accepted values on every enum a `CASE` branches on.
- **Monitor arrival, not just content**: a freshness threshold tied to the load cadence and a volume band derived from trailing history. A successful run that loaded zero rows must fail loudly.
- **Reconcile money- and count-bearing facts against the source system** on a stated cadence within a stated tolerance. This is the only check that catches corruption which preserves shape and changes values.
- **Give every severity-`error` assertion an owner and a route.** An unrouted failure is not a control.
- **One definition per metric**, at one altitude. If a metric is defined in the semantic layer, no mart re-derives it; if it is defined in a mart, no BI tool redefines it.
- **Backfills go to a shadow target** (separate table, versioned dataset, or isolated partition set), are bounded to a named partition range with a cost estimate, are preceded by a snapshot of the live aggregates, and cut over in one reversible step with a stated rollback window.
- **Pause the normal schedule** for any model while a backfill writes its partitions.
- **Store money as integer minor units or exact decimal with a currency column.** Store timestamps in UTC and name the timezone convention of every derived date column.

## Must not

- Aggregate over a model whose grain has not been probed in the current change.
- Join a fact to a dimension without a proven cardinality. Every unproven join is a fan-out waiting to be discovered by finance.
- Ship `SELECT *` outside a staging passthrough that is annotated as temporary with a date. It amplifies scan cost at every layer and lets an upstream column change a mart's shape.
- Update a dimension row in place when facts already reference it as-of an earlier date. That is a Type 2 requirement, not a preference.
- Let two models define the same business metric. Two defensible numbers is worse than one wrong one, because neither can be retired.
- Overwrite a live table during a backfill, or run a backfill concurrently with the model's normal schedule.
- Set retries on a task whose write is not proven idempotent — each retry writes the duplicate again and the graph turns green.
- Configure a downstream task to run regardless of upstream state. A transform over a failed load republishes yesterday as today.
- Filter an incremental model on load time, or on `max(event) already loaded` with no lookback. Late rows are lost permanently and silently.
- Disable an assertion with a "temporary" comment and no expiry date.
- Leave a quarantine table with no reader and no retention policy. Diverted rows that nobody reads are deleted rows with extra storage cost.
- Print sampled row values from a table whose PII classification is unknown, or copy production data to a lower environment without masking.
- Fix a wrong number in the BI layer. The fix must live in the model, or it does not exist for any other consumer.

## Should

- Keep a data contract per source and per published model: fields, types, nullability, accepted values, units, semantics, grain, freshness, version. Classify every change as additive, breaking, or semantic-breaking, and treat the third class as the dangerous one — same name, same type, new meaning, nothing fails, every number moves.
- Give every model a named consumer and a named owner. A model with neither is a deletion candidate; check the platform's query history over a full reporting cycle before removing it.
- Partition on the column queries actually filter (usually the event date, not the load date), and revisit cluster/sort keys against observed predicates rather than the ones chosen at creation.
- Prefer a bounded, chunked backfill that can be retried per chunk over one long job that must be restarted from zero.
- Keep an unknown/late-arriving member row in every dimension so facts never vanish on an inner join.
- Route data assertions through the same alerting and runbook conventions the observability pack already establishes, rather than inventing a second paging path.

## Review checklist

- [ ] Grain declared in words and probed unique in this change.
- [ ] Measure additivity recorded; no semi-additive measure summed across time.
- [ ] Layer direction respected; no hardcoded table references introduced.
- [ ] If incremental: key, predicate, lookback, and full-refresh trigger all present.
- [ ] Assertions present in the same commit and executed at least once.
- [ ] Freshness and volume monitors exist for anything on a schedule.
- [ ] If money- or count-bearing: a reconciliation check exists.
- [ ] If a metric changed: one definition remains, and the historical-series effect is stated.
- [ ] If a backfill: shadow target, bounded range, before-snapshot, rollback step, and window.

## Enforcement

- The transformation framework's own test runner executes the model assertions on every build; a failing severity-`error` assertion stops downstream models rather than warning.
- The dependency graph is built in CI; a hardcoded table reference is detectable as a model with fewer upstream edges than it has source mentions.
- Grain uniqueness, referential integrity, freshness, and volume are standing assertions in the suite, not review-time opinions.
- Reconciliation runs on its own schedule and pages its owner; it is the check that survives everything else being green.
- Backfill safety (shadow target, before-snapshot, rollback window) is enforced by the `/backfill-plan` closure gate, which is agent-side — there is no external validator for it.
