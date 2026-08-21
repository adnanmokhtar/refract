---
name: sharding-partitioning
kind: example
pack: distributed-systems
---

# Pattern: Sharding & Partitioning

> **Hard rule:** Sharding requires a stated partition key with **high cardinality, even distribution, and alignment to the dominant query pattern**, plus a documented rebalancing plan. Sharding a small table, a low-cardinality or monotonic partition key, and designs that routinely need cross-shard transactions/joins are forbidden. Exhaust vertical scale and read replicas first.

Sharding scales **writes** (scale-cube Z-axis). It needs a partition key with high cardinality, even distribution, and query alignment — plus a rebalancing plan. Exhaust vertical scale + read replicas first.

## Choosing the partition key

1. **High cardinality** — many distinct values.
2. **Even** — no dominant value (avoid `status`, `country`, a 90%-tenant id).
3. **Query-aligned** — most reads filter by it → one shard, not scatter-gather.
4. **Non-monotonic** — a timestamp/auto-increment key sends every new write to the newest shard (moving hot spot); hash it.

Tension: a spread-friendly key may be query-hostile. Pick per the dominant access pattern.

## Hashing

```
range     → contiguous ranges; great for scans, hot-spots monotonic keys
hash modN → even spread, but changing N remaps ~everything (full migration)
consistent hashing → ring; add/remove shard moves only ~1/N of keys
                     + virtual nodes = even distribution + incremental rebalance
```

## Hot partitions

Celebrity/viral key overheats even with a good key → salt/split the hot key (`#0..#k`, fan-in on read), cache in front, or isolate to dedicated capacity.

## Resharding is the tax

Adding shards = moving live data (dual-write + backfill + cutover). Keep entities mutated together in the same partition to avoid cross-shard transactions/joins.

## Forbidden

- Sharding a small/low-volume table with no measured single-node limit.
- Low-cardinality or skewed partition key (hot partition).
- Monotonic key with no hashing (all writes to one shard).
- Cross-shard transactions/joins on the hot path.
- Hash `mod N` with no consistent-hashing/rebalancing plan.

## Detectors (cite-or-halt)

- Sharding proposed for a **small / low-volume table** with no measured single-node limit cited at `<path:line>` — premature; halt and require the numbers, replicas, and vertical-scale ceiling first.
- A **low-cardinality or skewed partition key** (status, boolean, dominant-tenant id) — guaranteed hot partition; halt.
- A **monotonic partition key** (timestamp, auto-increment id) with no hashing/salting — all writes land on one shard; halt.
- The design requires **cross-shard transactions or joins** on the hot path — cite them; either co-locate the entities or justify the distributed cost.
- **Hash `mod N`** used where shards will be added later, with no consistent-hashing/rebalancing plan — every resize is a full remap; halt.
- Hand-wave (`etc.`, `appears to`, `roughly`) on "the key spreads evenly" — forbidden without a cardinality/distribution argument.
