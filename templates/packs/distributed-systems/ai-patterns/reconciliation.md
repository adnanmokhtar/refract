---
name: reconciliation
description: "Pattern: Reconciliation (anti-entropy repair of derived stores)"
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Reconciliation (anti-entropy repair of derived stores)

> **Hard rule:** Every derived or replicated store — a projection, a cache, a search index, a dual-written copy — MUST have a job that detects and repairs divergence from the source of truth. A derived store with no rebuild/repair path silently drifts, and drift is invisible until a user sees stale or wrong data. If you can't answer "how would we know this copy diverged, and how would we fix it?", the copy is a latent incident.

**When to apply**
- Any store holds a *copy* of authoritative state: a read-model projection, a cache, a search/analytics index, a replicated table, a materialized aggregate, a copy written by a dual-write.
- Delivery is at-least-once / eventually-consistent, so a dropped event, a failed dual-write, a poisoned message, or a bug in the projection code can leave the copy wrong.
- You need to bound worst-case staleness with a number and an alert, not "it usually catches up".

**When NOT to apply**
- There is no derived store — a single source of truth, read directly, has nothing to reconcile.
- The copy is trivially rebuildable on every read (a pure function of the source computed inline) — there is no persisted divergence to detect.
- A lossy soft-signal store where divergence has no correctness cost (analytics breadcrumbs) — a periodic full rebuild is cheaper than a diff.

**Halt conditions / mandatory cites**
- Every derived store MUST cite its source of truth at `<path:line>` AND its repair path (read-repair, sweep, or full rebuild).
- The divergence metric MUST be cited (the checksum/count/sample-diff query) AND the alert threshold — a repair job with no divergence metric is unfalsifiable; you can't tell if it's working.
- The repair job MUST be shown to be idempotent AND resumable (a checkpoint/cursor) — a repair that isn't safe to re-run or resume after a crash is a bug; reject.
- A doc claiming "the projection stays in sync" without extracting the detection query is a bug — reject. Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "they can't diverge".
- If a dual-write exists with no drift audit between the two stores, halt — dual-writes diverge by construction (one write can succeed while the other fails).

## Boundary — what this owns vs cqrs / event-sourcing

`cqrs` and `event-sourcing` both say a projection *can* be rebuilt by replaying events — that is the **single-store rebuild** primitive, and it stays theirs. This pattern owns the discipline those two do NOT: **detecting that a derived store has silently diverged from its source, and repairing it** — across stores that were never event-sourced at all (a cache, a search index, a dual-written table, a read replica). Reconciliation *consumes* event-sourcing's replay as one repair mechanism (a full projection rebuild) but adds the parts replay alone can't give you: the cross-store divergence detector (checksum/count/sample-diff), the divergence metric + alert, read-repair, and the resumable partial repair that fixes only the drifted rows instead of rebuilding everything. If the store isn't a replayable projection, event-sourcing's rebuild doesn't apply and reconciliation is the only path.

## Two repair modes

Reconciliation happens at two time scales — use both; they cover different failure envelopes.

### Read-repair (on the hot path)

When a read observes an inconsistency (the cached row disagrees with a cheap authoritative check, a version tag is stale, the source's `updated_at` is newer than the copy's), repair it inline: re-read from the source, overwrite the copy, serve the fresh value. Cheap, self-healing for hot keys, but only fixes what someone happens to read — cold data stays wrong. Read-repair is necessary but never sufficient.

### Background anti-entropy sweep (off the hot path)

A scheduled job walks the source and the derived store and repairs divergence regardless of whether anyone read it. This is the backstop that catches cold drift, dropped events, and dual-write gaps. It is the job whose *absence* is the core detector below.

## Drift detection (how the sweep knows)

You cannot repair what you can't detect. Pick the cheapest signal that catches your failure mode:

- **Count check** — `COUNT(*)` (or per-partition counts) on source vs derived. Cheap, catches whole-batch loss; misses per-row corruption where counts match.
- **Checksum / merkle** — hash a canonical projection of each side (or per-range merkle trees so you only descend into ranges that disagree). Catches per-row divergence in bounded work; the standard anti-entropy primitive for replicated stores.
- **Sample-diff** — compare a random or recently-changed sample of keys field-by-field. Catches subtle field-level drift (a projection bug that mis-maps one column) that a checksum over the wrong fields would miss.
- **Watermark / lag** — compare the max source sequence/`updated_at` applied to the derived store vs the source's head. Bounds staleness; the input to the lag SLO.

State which signal, over which fields, at what cadence — an undefined "we compare them" is not detection.

## Projection rebuild (cross-ref event-sourcing)

When the derived store is a replayable projection and divergence is broad (a projection-code bug corrupted many rows), the repair is a **full rebuild**: replay the event log into a fresh v2 projection, verify it against the detector, cut over. This is `event-sourcing` § Rebuilding projections / `cqrs` § Rebuilding projections — reconciliation's contribution is *deciding to trigger it* (the detector fired) and *verifying it worked* (the detector is green post-rebuild), not the replay mechanism itself. Prefer a targeted partial repair (below) when only a bounded set of keys drifted; a full rebuild is the sledgehammer.

## Dual-write divergence audit

A dual-write — the same fact written to two stores in the request path (DB + cache, DB + search index, two DBs) — is **not atomic**; one write can commit while the other fails, silently. The `outbox` pattern is the correct *fix* (write once transactionally, relay to the copy). Where a dual-write already exists, reconciliation is the *safety net*: a periodic audit that diffs the two stores and repairs the loser toward the source of truth. A dual-write with no such audit is a latent divergence generator — flag it, and prefer migrating it to outbox.

## Cache / index staleness repair

- **Cache**: an invalidation message can be dropped, so TTL-plus-invalidation is not enough on its own. Back it with read-repair (revalidate against source on read when a version tag mismatches) and a sweep that samples keys for staleness. The client-side analog is the `frontend` pack's `realtime-client` cache reconcile (re-sync client cache to server on reconnect / version skew).
- **Search / analytics index**: an indexing event can be lost or a mapping change can leave old docs in the old shape. Reconcile by diffing indexed-id set vs source-id set (missing/extra docs) and re-indexing the delta; for shape drift, reindex by version.

## The divergence metric + alert

Detection is worthless if silent. Emit a **divergence gauge** — `rows_diverged`, `keys_missing_in_derived`, `checksum_mismatch_ranges`, `max_staleness_seconds` — from every sweep run, and alert when it crosses the store's tolerance (ideally: it should be `0`, alert on `> 0`; for lag, alert on `> SLO`). A repair job with no emitted metric is enforcement theater — you cannot tell a healthy sweep from a sweep that silently no-ops. The metric is the mandatory cite above.

## Idempotent, resumable repair

- **Idempotent** — applying the same repair twice leaves the same state (upsert by key, not blind insert; set-to-source-value, not increment). At-least-once sweeps and retries WILL re-apply.
- **Resumable** — the sweep checkpoints its cursor (key range / sequence / last-scanned id) so a crash mid-sweep resumes instead of restarting, and a large store reconciles in bounded batches rather than one giant scan that never finishes or locks the source.
- **Bounded blast radius** — repair the drifted delta, not the whole store, when detection localized it; rate-limit writes so the repair doesn't overwhelm the derived store or the source.

## Forbidden

- A derived/replicated store (projection, cache, index, dual-written copy, replica) with no rebuild or repair path.
- A dual-write with no periodic drift audit between the two stores.
- A repair/sweep job that emits no divergence metric (undetectable success/failure).
- A repair that isn't idempotent (double-apply corrupts) or isn't resumable (a crash restarts from zero, or a full-store scan that can't complete).
- "Read-repair is enough" — read-repair never touches cold data; a background sweep is mandatory.
- Reconciling toward the wrong direction (repairing the source from the copy) — the source of truth wins, always.

## Related

- `cqrs` — owns the read-model/write-model split and the single-store projection-rebuild primitive this pattern triggers and verifies.
- `event-sourcing` — owns replay-based rebuild; reconciliation consumes it as one repair mode and adds cross-store detection.
- `outbox` — the *fix* for dual-write divergence (write-once + relay); reconciliation is the audit where a dual-write still exists.
- `consistency-models` — names the staleness the sweep bounds (eventual consistency is a promise to reconcile, not a promise to never diverge).
- `@resilience-reviewer` — flags derived stores with no repair path during review.
- cross-pack `frontend` / `realtime-client` — the client-side cache reconcile (re-sync to server on reconnect / version skew).
- cross-pack `database` / `read-replicas` — replication lag + replica divergence is this pattern applied to a physical replica.
