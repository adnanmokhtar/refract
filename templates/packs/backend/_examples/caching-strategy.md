---
name: caching-strategy
kind: example
pack: backend
---

# Pattern: Caching Strategy

> **Hard rule:** Every cached resource has ONE documented invalidation strategy (TTL, explicit, version, tag, or write-through+TTL) and a tenant-scoped, versioned key. Cache is acceleration only — never source of truth, never the only writer of any field, never used for auth tokens or correctness-critical state.

**Halt conditions / mandatory cites**
- Any "add a cache here" proposal MUST cite the read site at `<path:line>` AND the write site(s) that must invalidate.
- TTL choices MUST cite the data class row in the table or justify a deviation with measured staleness tolerance.
- A cache key without tenant prefix in a multi-tenant codebase is a bug — reject the diff.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is safe to cache".
- If hit-rate / eviction metrics aren't already wired, halt and add observability before shipping the cache.

## Cache read patterns

One table. The load-bearing column is the third — the pattern's own failure mode is what tells you when it is the wrong one, and it is the column every textbook version of this list omits.

| Pattern | What it costs | When it is the wrong choice |
|---|---|---|
| **Read-through / cache-aside** (app or library fills on miss) | One extra round-trip on miss. | Almost never wrong — this is the default. It is wrong only when the miss is so expensive that a herd of them is itself the outage, at which point you have not outgrown the pattern, you need § Stampede protection on top of it. |
| **Write-through** (write DB, then write cache) | Every write pays the cache write, including writes to keys nobody will ever read. | On write-heavy data with a low read/write ratio you are paying to warm entries that expire unread. Prefer invalidate-on-write and let the next read fill. |
| **Write-behind** (write cache, flush to DB async) | Acknowledged writes can be lost on crash. | **Effectively always, in a backend.** It makes the cache the only writer of a field, which the Hard rule forbids outright. It earns its place in OS page caches and storage engines, where the durability contract is different. Named here so it can be recognised and rejected, not adopted. |
| **Refresh-ahead** (refresh before TTL expires) | Backend load for entries that may never be read again. | On a large key space — you are refreshing the long tail forever. Correct only for a small, known-hot key set where you can name the keys. |

Cache is a distributed data store with its own consistency model. Serving stale data is not a performance bug, it is a correctness one, which is why the invalidation section below carries the weight in this file.

## Cache invalidation

The "hard problem". Pick ONE strategy per resource:

### TTL only (time-based expiry)
- Simple. Cache holds for N seconds.
- Stale window = up to TTL.
- Good for: data where stale-for-a-minute is OK.

### Explicit invalidation on write
- On write to entity X, delete cache keys for X.
- Tight consistency. Requires knowing every key X might be in.
- Good for: tenant settings, user profile.

### Versioning
- Cache key includes version: `tenant:42:products:v17`.
- Write bumps version. Old keys naturally age out.
- Good for: compound keys where explicit invalidation is hard.

### Tag-based
- CDN-level: tag cached response with `tags: [tenant-42, products]`.
- Purge by tag: `cdn.purge-tag(tenant-42)`.
- Cloudflare Cache API, Fastly Surrogate Keys.

### Write-through + TTL (belt-and-suspenders)
- On write, update cache AND invalidate.
- TTL as fallback if invalidation missed a key.

## Stampede protection

Classic problem: hot cache key expires → 1000 requests all miss → 1000 hit DB → DB melts.

### Single-flight (recommended)
```ts
cache.getOrSet(key, ttl, async () => {
  // only ONE caller runs this; others wait for the result
  return db.get(key);
})
```
Libraries: `singleflight` (Go), `lru-cache` with pending promises (Node), `redis-lock`.

### Stale-while-revalidate
Return stale value immediately; refresh asynchronously.
```
if cache.age(key) > ttl and cache.age(key) < ttl + grace:
  return cache.value(key)        # stale but fine
  async_refresh(key)
else if cache.age(key) > ttl + grace:
  return db.get(key)              # must refresh
```

### Probabilistic early expiration
Chance of refreshing grows as TTL approaches. Smooths load.

### Jittered TTL
Randomize TTL per key (`ttl ± 10%`). Prevents synchronized expiry across keys.

## Key design

- **Namespaced** — `<tenant>:<entity>:<id>`. Never just `id`.
- **Versioned** — append schema/logic version: `:v2`. Lets you bump all keys at once.
- **Bounded length** — Redis + Memcached have key-length limits.
- **Hashable** — long structured queries hash to fixed-length key (`sha1:abc...`).

```
tenant:42:products:list:filters:eyJjYXQiOiJqYWNrZXQifQ==:v3
└─────────────┬──────────────┘ └─────────┬──────────┘ └┬┘
       namespace + entity          filter payload   version
```

## What NOT to cache

- Authentication tokens / session content (security).
- Payment state (correctness).
- Stock counts at checkout (over-sell).
- Real-time metrics.
- Anything > 1 MB per entry (Redis is not a document store).

## TTL defaults by data class

| Data | TTL |
|---|---|
| User profile (non-sensitive) | 5 min |
| Product catalog (reads >> writes) | 1 h |
| Settings / config | 10 min |
| Search results | 60 s |
| Aggregations / analytics | 5 min |
| i18n translations | 1 h (until deploy) |
| Static reference data (countries, timezones) | 24 h |

## Observability

- **Cache hit rate per namespace.** There is no universal target — the right hit rate depends on key cardinality and the read/write ratio, and a high-cardinality cache can be doing its job at 40%. Derive the threshold instead of adopting one: the hit rate is high enough when `misses/sec × miss cost` fits inside the origin's spare capacity with headroom for a cold start. If a number goes on a dashboard, write the derivation next to it.
- Evictions per minute (high = size too small OR TTL too short).
- Redis memory usage + fragmentation.
- Slow-path latency (cache miss + DB fetch + set).

## When cache becomes a DB

You've over-indexed on cache if:
- You rebuild cache state on deploy.
- Cache is the source of truth for ANY field.
- You write to cache without writing to DB.
- Downtime of Redis = downtime of app.

Stop. Rearchitect. Cache should be pure acceleration.

## Forbidden

- Unbounded caches (no TTL + no size limit = memory leak).
- Cache key without tenant prefix in multi-tenant systems.
- Caching responses from authenticated endpoints with a shared key.
- `if cache.has(k): return cache.get(k) else cache.set(...)` — race; use getOrSet.
- Caching without a clear invalidation strategy.
- Stale data silently served where correctness matters (inventory, payment).
- Redis memory policy = `noeviction` with no size cap (OOM + crash).
