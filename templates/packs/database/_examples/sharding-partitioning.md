---
name: sharding-partitioning
kind: example
pack: database
---

# Pattern: Partitioning + the sharding threshold

> **Hard rule:** Partitioning is adopted for a *named* benefit — partition pruning on a query that is measurably scan-bound, or `DROP PARTITION` as a retention purge — never "for scale". Sharding is last-resort: vertical scaling, read replicas, and caching MUST be exhausted with measurements first, and the shard key is the system's hardest design constraint forever. Cite the benefit, the measurement, and the unique-key check at `<path:line>` — or halt.

**Ownership boundary:** read scaling is `read-replicas.md`; connection ceilings are `connection-pooling.md`; the retention *policy* a partition drop enforces is `data-retention-pii.md`. This pattern owns one decision — split the table or not — and the constraint that decides whether you can.

**Halt conditions / mandatory cites**
- MUST cite the plan showing the scan the partition would prune, or the retention `DELETE` it would replace.
- MUST cite the unique-key check below, resolved, before proposing a partition key.
- A sharding proposal MUST cite saturation evidence (write IOPS, CPU, replication lag) after tuning, and show how the top-N query patterns land on one shard.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "we've outgrown one DB".

## Partitioning vs sharding

**Partitioning** splits one table across parts inside one database; the engine routes, queries stay unchanged. **Sharding** splits data across separate database instances; the application routes, and cross-shard queries stop being possible. Partitioning is reversible and local. Sharding is neither.

## The check that decides whether you can partition at all

**Every unique key on the table — the primary key included — must contain all the partition-key columns.** Both major engines say so: MySQL, "every unique key on the table must use every column in the table's partitioning expression" ([MySQL 8.4](https://dev.mysql.com/doc/refman/8.4/en/partitioning-limitations-partitioning-keys-unique-keys.html)); Postgres, "the constraint's columns must include all of the partition key columns" ([PG 17](https://www.postgresql.org/docs/17/ddl-partitioning.html)).

So a table with `PRIMARY KEY (id)` cannot be partitioned by `created_at` without changing the key to `(id, created_at)` — which changes every foreign key referencing it, every ORM relation, and the meaning of "unique". Resolve this before proposing a partition key; if the answer is "we would have to change a primary key other tables reference", partitioning this table is a schema migration, not a configuration change.

## What partitioning actually buys

Two benefits. If neither applies, do not partition.

1. **Pruning** — the planner skips partitions the predicate excludes. This only fires when the query carries the partition key; a query filtering on anything else reads *every* partition and pays per-partition planning on top. Confirm it in the plan.
2. **`DROP PARTITION` as the purge** — a metadata operation: no row scan, no lock storm, no dead-row cleanup. This is why time-partitioning is the default for append-heavy retention-bound data, and `data-retention-pii.md` depends on it.

Range partitioning by time serves both. List partitioning suits a small stable value set. Hash partitioning **prunes no range query and drops no old data** — it buys neither benefit, so adopt it only for a measured write-contention or parallel-scan reason.

**Operational cost:** partitions must exist before the data arrives (automate creation, alert on the horizon); every index is per-partition, so global uniqueness is not on offer; cross-partition queries get slower, not faster.

## When sharding would ever be the answer

Justified by **write throughput one primary cannot absorb after tuning**, or by data residency law. Not by storage size, and not by CPU.

| Measured signal (after tuning) | The move it justifies |
|---|---|
| Read CPU saturated on the primary | replicas, caching, or fix the queries — `read-replicas.md` |
| One query dominates total exec time | index or rewrite — `indexing-strategy.md` |
| Storage growing, old rows never read | retention + time partitioning + archival tier |
| Working set no longer fits in RAM | more RAM, or partition so the hot range fits |
| **Write IOPS saturated at the largest instance size** | shard |
| Data must physically reside per region | shard by region |

Before proposing a shard key, produce three things or stop: the saturation measurement, the top-N query patterns with the shard each lands on, and the resharding plan. `tenant_id`/`user_id`/`account_id` co-locate a customer's data; timestamps and auto-increment IDs put every new write on one shard. If no key keeps most queries on one shard, sharding makes the system slower. Do not hand-roll routing — that choice is an ADR with an owner.

## Forbidden

- Partitioning without naming which of the two benefits it buys, and showing it in a plan.
- Proposing a partition key before resolving the unique-key constraint.
- Hash partitioning adopted for "scale" — it prunes nothing and drops nothing.
- Partitioning with no automated partition creation and no horizon alert.
- Sharding as the first scaling move, or with a shard key chosen without the query list.
- Cross-shard transactions; auto-increment IDs across shards; shard routing written into individual queries.

## Related

- `data-retention-pii.md` — time-partitioning makes `DROP PARTITION` the cheapest retention purge.
- `read-replicas.md` — replicas scale reads; this pattern's sharding half is about writes.
- `indexing-strategy.md` — a scan an index would fix is not a partitioning problem. Rule that out first.
