---
name: caching-strategy
description: Pattern: Caching Strategy
kind: ai-pattern
pack: backend
---

# Pattern: Caching Strategy

Cache is a distributed data store with its own consistency model. Get the semantics wrong → serve stale data → users lose trust.

## Layers (outside → inside)

```
1. Browser cache          (HTTP headers, Service Worker)
2. CDN / Edge cache       (Cloudflare, Fastly, CloudFront)
3. Reverse proxy          (Varnish, nginx, Fastify cache)
4. Application cache      (Redis, Memcached, in-process LRU)
5. Database query cache   (Postgres shared_buffers, MySQL query cache)
6. Database (source of truth)
```

Hit a cache layer before hitting the one below. Miss cascades downward + fills upward.

## Cache read patterns

### Read-through
```
get(key):
  value = cache.get(key)
  if value is None:
    value = db.get(key)
    cache.set(key, value, ttl)
  return value
```
Simple, safe. Used for most reads.

### Cache-aside (look-aside)
Same as read-through, but the APP does the logic. Library handles write.

### Write-through
```
set(key, value):
  db.set(key, value)
  cache.set(key, value, ttl)
```
Cache is always consistent with DB write. But double write cost.

### Write-behind (write-back)
Write to cache → async flush to DB. Fast but risk of data loss on crash. Rare in backends, common in OS page caches.

### Refresh-ahead
Cache refreshes before TTL expires. Fewer cache misses, more backend load. Good for hot keys.

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

- Cache hit rate per namespace (target > 90% for hot data).
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
