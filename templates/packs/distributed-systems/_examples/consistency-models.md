---
name: consistency-models
kind: example
pack: distributed-systems
---

# Pattern: Consistency Models

Name the consistency level each cross-node read/write actually provides. "Strong consistency" across services with no coordinator, "exactly-once" delivery, and reading your own write off an async replica are physics violations, not config knobs.

## CAP vs PACELC

- **CAP** only decides behaviour *during a partition*: stay Consistent (**CP**, refuse) or Available (**AP**, serve stale). You never choose P.
- **PACELC** is the useful superset: `if Partition → A vs C; Else → Latency vs C`. The "Else" is where you live 99.9% of the time — strong consistency costs latency even with no partition. Classify systems as e.g. **PC/EL** (Dynamo-tunable) or **PC/EC** (etcd/Spanner).

## The ladder (strongest → weakest, pick the weakest that prevents a real anomaly)

| Level | Pick when |
|---|---|
| Linearizable | locks, leader election, uniqueness, balances |
| Sequential | replicated state machines |
| Causal | comments/replies, collaborative edits |
| Read-your-writes / monotonic-reads | user editing their own data |
| Eventual | like counts, caches, DNS |

## Delivery semantics

- **At-most-once** — may lose. **At-least-once** — may duplicate (honest default).
- **Exactly-once delivery is impossible.** "Effectively-once" = at-least-once + idempotent processing (dedup on a business key). See `idempotency.md`.

## Per-datastore

```
CP by default: Postgres (single primary), etcd/ZooKeeper, Spanner, Mongo majority
Tunable:       DynamoDB (read flag), Cassandra/Scylla (per-query ONE/QUORUM/ALL, R+W>N)
Nuanced:       Redis — async replication + failover can lose acked writes
```

## Forbidden

- "Strong consistency" across services with independent DBs and no coordinator.
- "Exactly-once" anywhere in a queue path.
- A write to primary immediately read back from an async replica (read-your-writes violation).
- Asserting a datastore's level without checking its actual quorum/replica config.
