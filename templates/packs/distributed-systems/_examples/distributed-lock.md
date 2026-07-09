---
name: distributed-lock
kind: example
pack: distributed-systems
---

# Pattern: Distributed Lock

A correctness lock must issue a monotonic **fencing token** that the protected resource checks and uses to reject stale holders. A lock alone can't stop a GC-paused holder from acting after its lease expired and another worker took over.

## The failure a lock can't prevent

```
A acquires (token 33) ──▶ A stalls (GC pause) ──▶ lease expires
                                                   B acquires (token 34), writes → resource sees 34
A resumes, writes with token 33 ──▶ resource REJECTS (33 ≤ 34)   ✅ correctness at the resource
```

The resource stores the highest token seen and refuses anything `≤` it. No fencing = both A and B act = corruption.

## Leases / TTL

- TTL is mandatory (reclaim a dead holder) but must **exceed worst-case work**; renew/heartbeat if work runs long.
- Renewal fails → assume lock lost → stop touching the resource.

## Redlock caveat (Kleppmann vs Antirez)

Multi-node Redis Redlock has **no fencing token** and relies on bounded clocks/pauses it can't guarantee — unsafe for **correctness**. Prefer:

1. A single-source-of-truth DB lock (Postgres advisory / `SELECT … FOR UPDATE`) — the transaction *is* the fence.
2. A consensus lease (etcd/ZooKeeper) using its monotonic revision as the token.

Redlock is OK only for the efficiency case (duplicate work is merely wasteful).

## Prefer lock-free

```sql
-- optimistic concurrency: the version IS the fence
UPDATE account SET balance = :new, version = version + 1
WHERE id = :id AND version = :expected;   -- 0 rows updated → retry
```

Also: `INSERT … ON CONFLICT`, DynamoDB condition expressions, unique constraints, single-writer-per-partition.

## Forbidden

- Correctness lock with no fencing token checked at the resource.
- Lock TTL shorter than the protected work; no heartbeat.
- Redlock for correctness-critical mutual exclusion.
- "Check-then-act" with no lock, `FOR UPDATE`, or CAS.
