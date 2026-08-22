---
name: consistency-models
description: 'Pattern: Consistency Models (CAP / PACELC / delivery semantics)'
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Consistency Models

> **Hard rule:** Every cross-node read/write path names the consistency level it actually provides and the datastore that enforces it. "Strong consistency" across independent services with no shared coordinator, "exactly-once" delivery claims, and a read that expects its own just-written value off an async replica are forbidden — each is a physics violation, not a config knob.

**When to apply**
- Designing any read/write that crosses a replication boundary (replica, region, cache, another service's DB).
- Choosing a datastore or a per-query consistency level (quorum, `LOCAL_ONE`, `linearizable`).
- A user-visible anomaly is reported ("I saved it but it's gone", "counter went backwards", "double-charged").

**When NOT to apply**
- Single node, single writer, one datastore, synchronous read of the same connection — you already have linearizable-within-the-transaction; don't over-model it.

## CAP — only decides behaviour *during a partition*

You never choose P; partitions happen to you. CAP says: **when a partition occurs**, a node either refuses to answer to stay consistent (**CP**) or answers with possibly-stale data to stay available (**AP**). That is the whole theorem. Outside a partition CAP says nothing — which is why CAP alone is a weak design tool.

## PACELC — the useful superset

> **if Partition → trade Availability vs Consistency; Else → trade Latency vs Consistency.**

The "Else" clause is where systems actually live 99.9% of the time: even with no partition, a strongly-consistent write must reach a quorum (or the leader) before acking — that costs latency. Naming a system as, e.g., **PA/EL** (available under partition, low-latency otherwise — Dynamo, Cassandra, Riak, Cosmos DB in its default configuration) or **PC/EC** (consistent always, pays latency always — VoltDB/H-Store, MySQL Cluster, PostgreSQL, Bigtable/HBase) is far more precise than "CP vs AP". The two mixed quadrants are the ones worth knowing exist: **PA/EC** (MongoDB — consistent in the normal case, availability-first under partition) and **PC/EL** (PNUTS), which is rare enough that seeing it claimed is usually a sign the classification was guessed. Classification source: Abadi's PACELC taxonomy. **Verify against the deployment, not the vendor page** — most of these are tunable per query, and a per-query consistency flag overrides whatever quadrant the product ships in.

## The consistency ladder (strongest → weakest)

| Level | Guarantee | Pick when |
|---|---|---|
| **Linearizable** | Every read sees the latest committed write, single global order — as if one copy | Leader election, locks, uniqueness, balances that must never go negative |
| **Sequential** | All nodes see operations in the *same* order, not necessarily real-time | Replicated state machines where wall-clock recency isn't required |
| **Causal** | Effects never appear before their causes (happened-before preserved) | Comments/replies, collaborative edits — cheap to scale, kills "reply before post" |
| **Read-your-writes / monotonic-reads** | A session sees its own writes; never goes backwards in time | User editing their own profile/settings; session-scoped correctness |
| **Eventual** | Replicas converge *if writes stop*; no ordering promise meanwhile | Like-counts, view counts, DNS, caches — anomalies are tolerable |

Weaker = cheaper + more available + lower latency. Pick the **weakest level that still prevents a real anomaly**, and pin it per read path — not one global setting.

## Delivery semantics (folded in — same physics)

- **At-most-once** — send and forget; may lose messages. Fine for lossy telemetry.
- **At-least-once** — retry until acked; may duplicate. The only honest network default.
- **Exactly-once *delivery* is impossible** over an unreliable channel (two-generals). What people call "exactly-once" is **effectively-once = at-least-once delivery + idempotent processing** (dedup on a business key). See `idempotency.md`.

## Per-datastore reality (verify the actual config, versions drift)

- **CP by default:** PostgreSQL (single primary), etcd / ZooKeeper (Raft/ZAB), Spanner, MongoDB `majority`.
- **Tunable:** DynamoDB (eventual vs strongly-consistent read flag), Cassandra / ScyllaDB (per-query `ONE`/`QUORUM`/`ALL`; `R+W>N` for quorum overlap).
- **Nuanced:** Redis — single instance is linearizable-ish; async replication + failover can silently lose acked writes (do not treat as a correctness store without care — see `distributed-lock.md`).

## Detectors (cite-or-halt)

- A design claiming **"strong consistency" across ≥2 services** with independent DBs and **no shared coordinator / saga / 2PC** cited at `<path:line>` — impossible; halt and name the real level or the coordinator.
- Any **"exactly-once"** claim in a queue/consumer path — reject the wording; require at-least-once + a cited idempotency key, or downgrade to at-most-once explicitly.
- A **read-your-writes violation**: a write to primary immediately followed by a read routed to an **async replica / eventually-consistent path** cited at `<path:line>` — halt; route the read to primary or add read-your-writes stickiness.
- A datastore's consistency level **asserted but not verified** against its actual config (quorum settings, replica read flags) — hand-wave (`etc.`, `appears to`, `roughly`) on a consistency claim is forbidden; cite the config.
- A per-query **`ONE`/eventual read** on a correctness-critical value (balance, inventory, auth) — halt; escalate the level or justify the anomaly tolerance.

## Related

- `idempotency.md` — the processing half of effectively-once.
- `distributed-lock.md` — linearizability as a service; why Redis alone isn't enough.
- `saga.md` — the coordinator that makes cross-service "all-or-nothing" possible without 2PC.
- `event-sourcing.md`, `cqrs.md` — read models are eventually consistent by construction.
