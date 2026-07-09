---
name: reconciliation
kind: example
pack: distributed-systems
---

# Pattern: Reconciliation (anti-entropy repair of derived stores)

Every derived or replicated store — a read-model projection, a cache, a search index, a dual-written copy, a read replica — MUST have a job that detects and repairs divergence from the source of truth. If you can't answer "how would we know this copy diverged, and how would we fix it?", the copy is a latent incident.

## When to apply

- A store holds a *copy* of authoritative state and delivery is at-least-once / eventually-consistent (a dropped event, a failed dual-write, or a projection bug can leave it wrong).
- You need to bound worst-case staleness with a number and an alert, not "it usually catches up".

## When NOT to apply

- No derived store (a single source of truth read directly has nothing to reconcile).
- The copy is a pure function recomputed inline on every read — no persisted divergence to detect.

## Two repair modes (use both)

- **Read-repair (hot path)** — a read notices the copy disagrees with a cheap authoritative check, re-reads from source, overwrites, serves fresh. Self-heals hot keys; never touches cold data.
- **Background anti-entropy sweep (off hot path)** — a scheduled job walks source + derived and repairs divergence regardless of reads. The backstop for cold drift; its *absence* is the core defect.

## Drift detection (pick the cheapest signal that catches your failure mode)

- **Count** — `COUNT(*)` per side/partition. Catches whole-batch loss; misses per-row corruption.
- **Checksum / merkle** — hash a canonical projection per range; descend only into ranges that disagree.
- **Sample-diff** — compare a random / recently-changed sample field-by-field.
- **Watermark / lag** — max applied source sequence vs source head; the input to the lag SLO.

## The divergence metric + alert

Emit a gauge (`rows_diverged`, `keys_missing_in_derived`, `max_staleness_seconds`) from every sweep and alert on `> tolerance`. A repair job with no emitted metric is enforcement theater — you can't tell a healthy sweep from one that silently no-ops.

## Idempotent, resumable repair

Upsert-by-key (not blind insert); set-to-source-value (not increment). Checkpoint the cursor so a crash resumes; repair the drifted delta in bounded batches, not one giant scan.

## Forbidden

- A derived/replicated store with no rebuild or repair path.
- A dual-write with no periodic drift audit between the two stores.
- A sweep that emits no divergence metric; a repair that isn't idempotent or resumable.
- "Read-repair is enough" — it never touches cold data; a background sweep is mandatory.
- Reconciling toward the wrong direction — the source of truth wins, always.

## Boundary

`cqrs` / `event-sourcing` own the single-store projection *rebuild* (replay). This owns *cross-store divergence detect + repair* — for caches, indexes, dual-writes, and replicas that were never event-sourced. `outbox` is the *fix* for dual-writes; reconciliation is the audit where one still exists.
