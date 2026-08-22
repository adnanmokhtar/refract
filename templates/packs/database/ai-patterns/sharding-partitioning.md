---
name: sharding-partitioning
description: "Pattern: Partitioning (and the sharding threshold) — when splitting one table into partitions pays, the unique-key constraint that decides whether you can, and the measured signal that would ever justify sharding."
kind: ai-pattern
pack: database
---

# Pattern: Partitioning + the sharding threshold

> **Hard rule:** Partitioning is adopted for a *named* benefit — partition pruning on a query that is measurably scan-bound, or `DROP PARTITION` as a retention purge — never "for scale". Sharding is last-resort: vertical scaling, read replicas, and caching MUST be exhausted with measurements first, and the shard key is the system's hardest design constraint forever. Cite the benefit, the measurement, and the unique-key check at `<path:line>` — or halt.

**Ownership boundary:** read scaling is `read-replicas.md`; connection ceilings are `connection-pooling.md`; the retention *policy* a partition drop enforces is `data-retention-pii.md`. This pattern owns one decision — split the table or not — and the constraint that decides whether you can.

**When to apply**
- A large table is queried almost exclusively through a range of one column (usually time), and the plan reads far more of it than the query needs.
- Retention requires deleting old rows in bulk, and `DELETE` is producing lock storms, replication lag, or bloat.
- Regulatory data residency forces per-region storage.

**When NOT to apply**
- Queries span the whole key range uniformly — pruning never fires and you have added partitions to maintain for nothing.
- The pain is read throughput (replicas + caching are cheaper and reversible) or connection count (that is pooling).
- The table's uniqueness rules cannot accommodate the partition key (below) — that is a schema redesign, not a partition.

**Halt conditions / mandatory cites**
- MUST cite the plan showing the scan the partition would prune, or the retention `DELETE` it would replace.
- MUST cite the unique-key check below, resolved, before proposing a partition key.
- A sharding proposal MUST cite saturation evidence (write IOPS, CPU, replication lag) after tuning, and show how the top-N query patterns land on one shard.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "we've outgrown one DB".

## Partitioning vs sharding — one sentence each

**Partitioning** splits one table across parts inside one database; the engine routes, queries stay unchanged. **Sharding** splits data across separate database instances; the application routes, and cross-shard queries stop being possible. They are not two sizes of the same move. Partitioning is reversible and local. Sharding is neither.

## The check that decides whether you can partition at all

Run this before anything else, because it is the constraint that ends most partitioning proposals — and it is invisible until the `CREATE TABLE` fails:

**Every unique key on the table — the primary key included — must contain all the partition-key columns.**

- MySQL: "All columns used in the partitioning expression for a partitioned table must be part of every unique key that the table may have. In other words, every unique key on the table must use every column in the table's partitioning expression." ([MySQL § Partitioning Keys, Primary Keys, and Unique Keys](https://dev.mysql.com/doc/refman/8.4/en/partitioning-limitations-partitioning-keys-unique-keys.html))
- Postgres: "To create a unique or primary key constraint on a partitioned table, the partition keys must not include any expressions or function calls and the constraint's columns must include all of the partition key columns… the individual indexes making up the constraint can only directly enforce uniqueness within their own partitions." ([PostgreSQL § Partitioning Limitations](https://www.postgresql.org/docs/17/ddl-partitioning.html))

So a table with `PRIMARY KEY (id)` cannot be partitioned by `created_at` without changing the key to `(id, created_at)` — which changes every foreign key that references it, every ORM relation, and the meaning of "unique" (`id` is now only unique *within* a partition unless something else enforces it). **Resolve this first.** If the answer is "we would have to change the primary key of a table other tables reference", the honest verdict is: partitioning this table is a schema migration, not a configuration change — price it as such.

## What partitioning actually buys

Two benefits, both concrete. If neither applies, do not partition.

1. **Pruning** — the planner skips partitions the predicate excludes, so a query bounded by the partition key reads a fraction of the table. This only fires when the query carries the partition key. A query that filters on something else reads *every* partition, and now pays per-partition planning overhead on top. Check the plan before and after; pruning that does not appear in the plan is not happening.
2. **`DROP PARTITION` as the purge** — dropping a partition is a metadata operation: no row scan, no lock storm, no dead-row cleanup afterwards. This is the reason time-partitioning is the right default for append-heavy retention-bound data (events, logs, sessions), and `data-retention-pii.md` depends on it.

Range partitioning by a time column serves both. List partitioning suits a small, stable set of discrete values. Hash partitioning gives even distribution and parallel scans but **cannot prune a range query and cannot drop old data** — it buys neither of the two benefits above, so adopt it only for a measured write-contention or parallel-scan reason.

## Operational cost, stated up front

- **Partitions must be created before the data arrives.** A write with no matching partition fails (or lands in a catch-all that grows forever). Automate creation and alert on the horizon — "we ran out of partitions at 00:00 on the 1st" is the standard incident. `pg_cron`/`pg_partman` on Postgres, the event scheduler on MySQL, or a job in the app's own scheduler.
- **Every index is per-partition.** Smaller and faster individually; more objects to maintain, and a global uniqueness guarantee the engine will not give you.
- **Cross-partition queries get slower**, not faster, because planning now touches every partition.

## When sharding would ever be the answer

Sharding is justified by **write throughput a single primary cannot absorb after tuning**, or by data residency law. Not by storage size — a large table on one instance is a partitioning, archival, or storage-tier question, and storage is the cheapest axis to scale. Not by CPU — that is replicas, query fixes, or a bigger instance.

| Measured signal (after tuning) | The move it justifies |
|---|---|
| Read CPU saturated on the primary | replicas, caching, or fix the queries — see `read-replicas.md` |
| One query dominates total exec time | index or rewrite — see `indexing-strategy.md` |
| Storage growing, old rows never read | retention + time partitioning + archival tier |
| Working set no longer fits in RAM, cache hit rate falling | more RAM, or partition so the hot range fits |
| **Write IOPS saturated at the largest instance size, after tuning** | shard |
| Data must physically reside per region | shard by region |

Before proposing a shard key, produce three things or stop: the saturation measurement, the top-N query patterns with the shard each would land on, and the resharding plan. A shard key chosen without the query list is the mistake that cannot be undone — `tenant_id`/`user_id`/`account_id` are the usual right answers because they co-locate a customer's data; timestamps and auto-increment IDs are the usual wrong ones because all new writes land on one shard. If the workload has no key that keeps most queries on one shard, sharding makes the system slower, not faster.

**Do not hand-roll shard routing.** If the measurements say shard, the choice is between a distributed engine and a routing layer, and that choice is an ADR with an owner — not a paragraph in a pattern file.

## Forbidden

- Partitioning without naming which of the two benefits it buys, and showing it in a plan.
- Proposing a partition key before resolving the unique-key constraint.
- Hash partitioning adopted for "scale" — it prunes nothing and drops nothing.
- Partitioning with no automated partition creation and no horizon alert.
- Sharding as the first scaling move, or with a shard key chosen without the query list.
- Cross-shard transactions; auto-increment IDs across shards; shard routing written into individual queries.

## Related

- `data-retention-pii.md` — time-partitioning by `created_at` makes `DROP PARTITION` the cheapest retention purge: O(1), no row scan, no bloat.
- `read-replicas.md` — replicas scale reads; this pattern's sharding half is about writes. Exhaust replicas and caching first; write throughput exceeding one primary is the only performance signal that justifies sharding.
- `indexing-strategy.md` — a scan that an index would fix is not a partitioning problem. Rule that out first.
