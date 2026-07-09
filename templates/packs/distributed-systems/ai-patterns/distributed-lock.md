---
name: distributed-lock
description: 'Pattern: Distributed Lock (fencing tokens, leases, Redlock caveat)'
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Distributed Lock

> **Hard rule:** A distributed lock used for **correctness** MUST hand out a monotonically increasing **fencing token** that the protected resource checks and uses to reject stale holders. A lock without fencing, a lock TTL shorter than the work it protects, and Redlock-for-correctness are forbidden. If mutual exclusion isn't actually required, prefer a lock-free conditional write instead.

**When to apply**
- Exactly one worker may run a job / touch a resource at a time (leader-only cron, single-writer migration).
- A shared external resource has no built-in optimistic concurrency and cannot tolerate concurrent mutation.

**When NOT to apply**
- The datastore already supports conditional writes / compare-and-set / unique constraints — use those (lock-free) instead; they're correct without a lock service.
- The lock is only a *performance* optimization (avoid duplicate work, duplicates are harmless) — then a best-effort lock is fine and fencing is optional. Be explicit which case you're in.

## Why a lock alone is not enough

Any lease-based lock can fail the same way: holder A acquires the lock, then **stalls** (GC pause, VM freeze, network delay) past its TTL. The lock expires, holder B acquires it legitimately, and now **both** A (resuming, still believing it holds the lock) and B act on the resource. No lock service can prevent this — the pause is invisible to it.

## Fencing tokens — the actual fix

The lock service issues a **monotonically increasing token** with each grant (A gets 33, B gets 34). Every write to the protected resource carries its token; **the resource rejects any token ≤ the highest it has seen**. When stalled A resumes and writes with token 33, the resource — having already accepted B's 34 — refuses it. Correctness lives at the resource, not at the lock. A lock you cannot fence gives you an illusion of safety.

## Leases / TTL

- A lock MUST have a TTL (lease) so a dead holder's lock is reclaimed — but the **TTL must exceed the worst-case protected work**, and the holder should renew (heartbeat) if the work runs long.
- Renewal failure = you may have lost the lock = stop touching the resource.

## The Redlock controversy (know both sides)

Redlock acquires a lock across N independent Redis nodes (majority = held). **Antirez** designed it for distributed mutual exclusion; **Kleppmann's critique** shows it's unsafe for correctness because it relies on bounded clocks and process pauses it cannot guarantee, and it provides **no fencing token** — so a GC-paused holder still double-acts. For **correctness-critical** mutual exclusion, prefer:
1. A **single-source-of-truth DB lock** (Postgres advisory lock / `SELECT … FOR UPDATE`) whose transaction *is* the fence, or
2. A **fencing-token-checked resource** backed by a consensus store (etcd/ZooKeeper lease + monotonic revision as the token).

Redlock is acceptable only for the *efficiency* case (duplicate work is merely wasteful, never incorrect).

## Lock-free alternatives (prefer when available)

- **Optimistic concurrency**: read a `version`/`etag`, write with `WHERE version = :expected`, retry on conflict. No lock service, no fencing needed — the version *is* the fence.
- **Conditional / compare-and-set writes**: DynamoDB condition expressions, `INSERT … ON CONFLICT`, unique constraints, etcd `CAS`.
- **Idempotent single-writer via partitioning**: route all keys for an entity to one consumer (partition key) so no cross-writer contention exists — see `sharding-partitioning.md`.

## Detectors (cite-or-halt)

- A distributed lock guarding **correctness** with **no fencing token** checked at the resource — cite the acquire site AND the resource write at `<path:line>`; if the token isn't threaded through, halt.
- A lock **TTL shorter than the protected work's worst case**, or no heartbeat/renewal — halt; the lease can expire mid-work.
- **Redlock (or multi-node Redis lock) used for correctness-critical mutual exclusion** — halt; require a DB/consensus lock + fencing, or reclassify as efficiency-only in writing.
- A **"check-then-act"** sequence (read-decide-write) with no lock, no `FOR UPDATE`, and no CAS/conditional write cited — race condition; halt.
- Hand-wave (`etc.`, `appears to`, `roughly`) when claiming "only one worker can hold this" — forbidden without the fencing/CAS mechanism cited.

## Related

- `consistency-models.md` — linearizability is what a correct lock service actually needs.
- `idempotency.md` — often removes the need for a lock entirely.
- `sharding-partitioning.md` — single-writer-per-partition as a lock-free alternative.
- `outbox.md` — `FOR UPDATE SKIP LOCKED` as a per-row work lock.
