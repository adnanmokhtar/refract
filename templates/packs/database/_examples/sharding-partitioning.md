---
name: sharding-partitioning
kind: example
pack: database
---

# Pattern: Sharding + Partitioning

Last-resort scaling. Try vertical scaling + read replicas + caching first. Sharding is operationally expensive forever.

## Partitioning vs Sharding

- **Partitioning** — one DB, table split into parts. Engine handles routing. Queries still simple.
- **Sharding** — multiple DB instances. Application routes. Queries constrained.

Partitioning first. Sharding only when a single DB can't keep up.

## Partitioning (single DB)

### Range partitioning
Split by value range — typical for time-series.
```sql
CREATE TABLE events (
  id bigserial,
  tenant_id uuid,
  created_at timestamptz NOT NULL,
  payload jsonb
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2026_01 PARTITION OF events
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE events_2026_02 PARTITION OF events
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
```

Benefits:
- Old partitions pruned at query time (scans only relevant months).
- DROP old partitions instead of DELETE (much faster).
- Indexes per-partition (smaller, faster).

### List partitioning
Split by discrete values — e.g., tenant_id for a small number of tenants.

### Hash partitioning
Even distribution when no natural range exists.
```sql
CREATE TABLE orders (...) PARTITION BY HASH (tenant_id);
CREATE TABLE orders_p0 PARTITION OF orders FOR VALUES WITH (MODULUS 8, REMAINDER 0);
-- repeat 0..7
```

Benefits: parallel scans, balanced write load.

### Operational automation

- Pre-create partitions ahead of time (cron job or pg_partman).
- Monitor for missing partitions (writes fail if the range isn't created).
- Drop old partitions per retention policy.

## Sharding (multiple DBs)

### When
- Single DB write capacity exceeded after tuning.
- Single DB storage exceeded (can scale up with managed services, eventually not).
- Regulatory data residency requires per-region storage.

### Shard key choice
The #1 decision. Wrong choice = cross-shard queries forever.

**Good shard keys:**
- `tenant_id` in multi-tenant SaaS — each tenant's data stays on one shard.
- `user_id` in user-centric apps — user's data co-located.
- `account_id` in B2B.

**Bad shard keys:**
- Timestamps (hot spot on newest shard).
- Auto-increment IDs (hot spot).
- Low-cardinality values (gender, status).

### Shard routing

Strategies:
- **Hash-based** — `shard = hash(tenant_id) % N`. Simple, even distribution. Hard to reshard.
- **Range-based** — map tenant ranges to shards. Easier to move data. Hot-spot risk.
- **Directory service** — lookup table: `tenant_id → shard`. Flexible, adds a hop.

Directory service is the most flexible for SaaS — lets you migrate tenants between shards.

### Cross-shard operations

- **Single-shard query** — always preferred. Route by key, done.
- **Scatter-gather** — query every shard, merge. Slow, complex, error-prone.
- **Aggregation** — use a separate analytics DB (read replicas → data warehouse).

Design schema so 99% of queries are single-shard.

### Rebalancing

Inevitably: some shards grow faster than others.
- Split a hot shard → smaller shards.
- Move tenants between shards via backfill + switchover.
- Dual-write during migration, cut over, backfill stragglers.

Plan rebalancing tools BEFORE you shard. Don't improvise it at 2am.

## Read replicas (before sharding)

- Route reads to replicas, writes to primary.
- Replication lag: measure it, surface to app ("must read own write" = use primary).
- Horizontally scales READS only. Writes are still bottlenecked by primary.

## When to shard vs scale up

| Signal | Action |
|---|---|
| CPU on primary > 70% | Add read replicas for queries OR scale up |
| Write latency growing | Batch writes, add partitioning, tune indexes |
| Storage > 1 TB | Partition by range/time |
| Storage > 10 TB | Partition or shard |
| Write IOPS saturated after tuning | Shard |

## Tools / managed services

- **Citus (Postgres)** — distributed Postgres, transparent sharding.
- **Vitess (MySQL)** — used by YouTube, Slack. Proxy-based sharding.
- **CockroachDB, YugabyteDB** — distributed by design, no manual sharding.
- **Planetscale** — hosted Vitess.
- **Spanner, Aurora** — cloud-managed horizontal scale.

Prefer these over hand-rolling sharding. Years of engineering.

## Forbidden

- Sharding as the first scaling move (try vertical + replicas + caching first).
- Picking a shard key without modeling your queries.
- Cross-shard transactions (use sagas or redesign).
- Auto-increment IDs across shards (use UUIDs or snowflake IDs).
- Manual shard routing in every query (centralize in a data access layer).
- Partitioning without automating partition creation (writes fail when range ends).
- Rebalancing improvised under fire.
