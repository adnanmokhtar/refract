# distributed-systems pack — changelog

Release history for `templates/packs/distributed-systems/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.3.0 — 2026-07-10

- add-event-handler + add-saga Phase 6: HALT precondition requiring the dedupe/reserve be cited at
  path:line and be ATOMIC (compensations keyed by (sagaId, stepName)); scenarios now cover
  concurrent duplicate delivery, crash between effect-commit and ack, and redelivered compensation —
  not a sequential twice-call.
- resilience-reviewer: halt conditions — an idempotency claim resting on check-then-act or an
  in-memory map is NOT idempotent.

## 1.2.1 — 2026-07-10

- add-saga + add-event-handler: Phase-6 now enforces scenarios_green == scenarios_required OR HALT —
  the per-scenario tests (happy/failure/timeout/crash/idempotency/DLQ/replay) must actually run
  green or the success block is not emitted; per-scenario PASS/FAIL rendered, not an asserted
  checklist.

## 1.2.0 — 2026-07-10

- ai-patterns +1: reconciliation (cross-store anti-entropy — divergence detection + resumable repair +
  divergence metric for projections/caches/indexes/dual-writes; consumes event-sourcing replay as
  one repair mode).

## 1.1.0 — 2026-07-09

- CORRECTNESS: idempotency.md — fencing-token requirement on distributed locks (Redlock controversy) +
  corrected DELETE idempotency (state-effect not status code; 404/410 on repeat is valid) + RFC
  7231->9110. distributed-principles.md — exactly-once-delivery-is-impossible / effectively-once =
  at-least-once + idempotent processing.
- NEW ai-patterns: consistency-models (CAP/PACELC, linearizable->sequential->causal->RYW->eventual
  ladder with pick-criteria, delivery semantics, per-datastore CP/AP table), distributed-lock
  (fencing tokens, lease/TTL, Redlock/Kleppmann-vs-Antirez, lock-free CAS alternatives),
  sharding-partitioning (key selection, consistent hashing + vnodes, hot-partition, resharding,
  scale-cube Z, when-NOT), backpressure (bounded queues, load-shedding 503+Retry-After, AIMD
  adaptive concurrency, credit flow control, bulkhead — closes the dangling backend bulkhead
  pointer). saga.md +Saga-isolation section (semantic lock / commutative / pessimistic view /
  reread-version / by-value).
- NEW agents/capacity-planner.md (model:opus) — the quantitative system-design specialist: capacity
  model (Littles Law L=lambda*W, storage/bandwidth/cache/connection budgets) -> bottleneck ledger
  1x/10x/100x -> scaling axis (vertical->horizontal->read-replicas->shard) ->
  data-migration-at-scale cutover (dual-write->backfill->shadow-read->expand-contract->flip); 7
  detectors + capacity/bottleneck/scaling/partition-ADR output. commands/design-system.md +Phase-3.5
  capacity+scaling dispatch; dangling event-bus.md/replication.md refs fixed. This is the
  system-design EXPANSION (boundary call: expand, not a new pack).
- House-contract: all 4 pre-existing agents +hand-wave hard-halt clause +### Skills subsection
  +@capacity-planner sibling; resilience-reviewer + system-architect promoted sonnet->opus (were
  inverted) +verdict-matches-body; system-architect +datastore-selection table +C4
  (container/component/deployment + sequence) diagrams; add-saga +Premise/Mechanical-halt.
  Registered consistency-models/distributed-lock/sharding-partitioning/backpressure +
  capacity-planner in _topics/_essentials.
