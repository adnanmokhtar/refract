---
name: sharding-partitioning
description: 'Pattern: Sharding & Partitioning (partition keys, consistent hashing, hot partitions)'
kind: ai-pattern
pack: distributed-systems
---

# Pattern: Sharding & Partitioning

> **Hard rule:** Sharding requires a stated partition key with **high cardinality, even distribution, and alignment to the dominant query pattern**, plus a documented rebalancing plan. Sharding a small table, a low-cardinality or monotonic partition key, and designs that routinely need cross-shard transactions/joins are forbidden. Exhaust vertical scale and read replicas first.

**When to apply**
- A single node genuinely cannot hold the dataset or sustain the write throughput, *proven with numbers*.
- Write volume (not just reads) is the bottleneck — read replicas already absorb read load; sharding is the tool for **write** scaling (the scale-cube **Z-axis**: split data by attribute).

**When NOT to apply**
- The table is small / the load fits one node — sharding is premature and adds permanent operational cost. Scale **up** (bigger box) and **out reads** (replicas) first.
- Query patterns require frequent cross-entity joins/transactions — sharding turns those into distributed joins/2PC. Reconsider the boundary.

## Choosing the partition key (the one decision that matters)

A good key is:
1. **High cardinality** — many distinct values, so data spreads across shards.
2. **Evenly distributed** — no single value dominates (avoid `country`, `status`, `tenant` when one tenant is 90% of traffic).
3. **Query-aligned** — the key most reads filter by, so a query hits **one** shard, not a scatter-gather across all of them.
4. **Non-monotonic** — a timestamp/auto-increment key sends *every new write to the newest shard* (a moving hot spot). Hash it or prefix it.

Tension: a key great for spread may be bad for queries. When they conflict, pick per the dominant access pattern and accept scatter-gather (or a secondary index / global table) for the rest.

## Hashing strategies

- **Range partitioning** — contiguous key ranges per shard. Great for range scans; prone to hot spots on monotonic keys.
- **Hash partitioning** — `hash(key) mod N`. Even spread, but changing N (add/remove a shard) **remaps almost every key** — a full data migration.
- **Consistent hashing** — keys and shards placed on a hash ring; adding/removing a shard only moves the keys between adjacent points, so ~`1/N` of data moves instead of everything. Use **virtual nodes** (each physical shard owns many ring points) to smooth distribution and make rebalancing incremental and even.

## Hot partitions

Even with a decent key, one partition can overheat (a celebrity user, a viral item). Mitigations: **salt/split the hot key** (suffix `#0..#k`, fan-in on read), add a **cache** in front, isolate the hot tenant to dedicated capacity, or use **write-sharding** for the specific hot key only.

## Resharding is the pain you're signing up for

Adding shards means **moving live data** while serving traffic: dual-write + backfill + cutover, or consistent-hashing incremental migration. Design the key and shard count with headroom so you reshard rarely. Cross-shard transactions/joins are the recurring tax — keep entities that are mutated together in the **same** partition.

## Detectors (cite-or-halt)

- Sharding proposed for a **small / low-volume table** with no measured single-node limit cited at `<path:line>` — premature; halt and require the numbers, replicas, and vertical-scale ceiling first.
- A **low-cardinality or skewed partition key** (status, boolean, dominant-tenant id) — guaranteed hot partition; halt.
- A **monotonic partition key** (timestamp, auto-increment id) with no hashing/salting — all writes land on one shard; halt.
- The design requires **cross-shard transactions or joins** on the hot path — cite them; either co-locate the entities or justify the distributed cost.
- **Hash `mod N`** used where shards will be added later, with no consistent-hashing/rebalancing plan — every resize is a full remap; halt.
- Hand-wave (`etc.`, `appears to`, `roughly`) on "the key spreads evenly" — forbidden without a cardinality/distribution argument.

## Related

- `distributed-principles.md` — the scale cube (X/Y/Z axes) this sits on.
- `consistency-models.md` — cross-shard reads are the eventual-consistency boundary.
- `distributed-lock.md` — single-writer-per-partition removes contention.
- `cqrs.md` — a read model can denormalize across shards for scatter-free queries.
