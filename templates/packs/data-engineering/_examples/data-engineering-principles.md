---
name: data-engineering-principles
description: Data Engineering Principles
kind: example
pack: data-engineering
---

# Data Engineering Principles

> **Hard rule.** Every model declares its grain in one sentence and proves it with a uniqueness probe. Every model a human or dashboard reads ships assertions in the same commit. Every metric has one definition. Backfills write to a shadow target and cut over reversibly. A wrong number is a production incident.

## Must

- Declare the grain in words; prove it with a duplicate-key probe against the built table. A primary-key declaration is not proof — most analytical platforms do not enforce it.
- Classify every measure additive / semi-additive / non-additive next to the column; store ratios as numerator and denominator.
- Respect layer direction: staging reads sources only, intermediate reads staging, marts read intermediate. Nothing past staging reads a raw source.
- Reference upstream through the framework's reference function — a hardcoded table name is invisible to the dependency graph.
- Every incremental model states its merge key, its event-time predicate, its late-arrival lookback, and its full-refresh trigger.
- Ship assertions with the model: uniqueness on the grain, not-null on join/filter columns, referential integrity, accepted values on branched enums.
- Monitor arrival: a freshness threshold tied to the load cadence, and a volume band from trailing history.
- Reconcile money- and count-bearing facts against the source system on a stated cadence and tolerance.
- Give every severity-`error` assertion an owner and a route.
- Backfills go to a shadow target, bounded to a named range with a cost estimate, preceded by a snapshot of live aggregates, cut over in one reversible step.

## Must not

- Aggregate over an unprobed grain, or join without a proven cardinality.
- Ship `SELECT *` outside a dated staging passthrough.
- Update a dimension row in place when facts reference it as-of an earlier date.
- Let two models define the same business metric.
- Overwrite a live table during a backfill, or run one concurrently with the normal schedule.
- Set retries on a task whose write is not proven idempotent.
- Configure a downstream task to run regardless of upstream state.
- Filter an incremental model on load time, or on the high-water mark with no lookback.
- Disable an assertion with a "temporary" comment and no expiry.
- Fix a wrong number in the BI layer — the fix must live in the model.

## Should

- Keep a versioned data contract per source and per published model, including units, timezone, and semantics.
- Give every model a named consumer and owner; check query history over a full reporting cycle before deleting an apparent orphan.
- Partition on the column queries filter (usually event date, not load date).
- Keep an unknown member in every dimension so facts never vanish on an inner join.
- Route data assertions through the observability pack's existing alert and runbook conventions.

## Review checklist

- [ ] Grain declared and probed in this change.
- [ ] Additivity recorded; no semi-additive measure summed across time.
- [ ] Layer direction respected; no hardcoded references introduced.
- [ ] Incremental: key, predicate, lookback, full-refresh trigger all present.
- [ ] Assertions in the same commit and executed at least once.
- [ ] Freshness and volume monitors exist for anything scheduled.
- [ ] Money- or count-bearing: a reconciliation check exists.
- [ ] Backfill: shadow target, bounded range, before-snapshot, rollback window.
