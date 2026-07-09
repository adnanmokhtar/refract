---
name: sharding-partitioning
kind: example
pack: distributed-systems
---

# Pattern: Sharding & Partitioning

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
