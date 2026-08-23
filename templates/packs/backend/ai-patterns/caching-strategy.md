---
name: caching-strategy
description: "Pattern: Caching Strategy"
kind: ai-pattern
pack: backend
---

# Pattern: Caching Strategy

> **Hard rule:** Every cached resource has ONE documented invalidation strategy (TTL, explicit, version, tag, or write-through+TTL) and a tenant-scoped, versioned key. Cache is acceleration only — never source of truth, never the only writer of any field, never used for auth tokens or correctness-critical state.

**When to apply**
- A read path has p95 latency dominated by a deterministic compute or DB fetch and the staleness window is acceptable.
- A hot key triggers thundering-herd traffic on miss (use single-flight + jittered TTL).
- A multi-tenant read where the same logical query repeats across requests within seconds.

**When NOT to apply**
- Auth tokens, session content, payment state, stock counts at checkout, real-time metrics — correctness > latency.
- Entries > 1 MB or unbounded growth — Redis is not a document store.
- Read paths where you cannot articulate the invalidation rule in one sentence.

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
age = cache.age(key)

if age <= ttl:                    # fresh — the common case, and it needs a branch
  return cache.value(key)

if age < ttl + grace:             # stale but inside the grace window
  async_refresh(key)              # KICK THE REFRESH FIRST…
  return cache.value(key)         # …then serve stale. Order is the whole pattern.

return db.get(key)                # past grace — nothing to serve but truth
```

Two things in that ordering carry the entire value of the pattern, and both are easy to get backwards:

- **The refresh is dispatched before the return, not after.** Statements after `return` never execute. Written the other way round this is stale-while-*never*-revalidate: it serves stale for the whole grace window and only refreshes once `age > ttl + grace` — which is the synchronous DB hit the pattern exists to avoid, now arriving later and colder.
- **The `age <= ttl` branch has to exist.** Without it the fresh path falls through with no return value, and the caller gets `undefined` on a cache *hit*.

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

- Authentication tokens / session content **as a cache** — see the distinction below.
- Payment state (correctness).
- Stock counts at checkout (over-sell).
- Real-time metrics.
- Anything > 1 MB per entry (Redis is not a document store).

**Redis-as-store vs Redis-as-cache — the distinction that stops this section contradicting `backend-principles` PERF-6.** PERF-6 requires sessions, rate-limit counters, locks and dedupe sets to live in a *shared store* (Redis / DB) rather than process memory. That is Redis as the **source of truth** for that data: there is no DB row behind it, losing it means the session is gone, and that is the accepted design. This section forbids the other thing: Redis holding a **copy** of data whose truth lives in the DB — a cached auth decision, a cached permission set, a cached token-validity flag. The copy is what goes stale after a revocation, which is why Detector 4 fires on it. Same technology, opposite roles. State which role a given key plays and the two rules stop fighting.

## TTL defaults by data class

**These are starting points, not a spec.** Every row is an *order-of-magnitude* guess at a staleness tolerance that is actually a product decision. The "why" column is the load-bearing one: it tells you when the number does not apply, which a bare number never can. Replace any row the moment you can measure the real tolerance.

| Data | Starting TTL | Why that order of magnitude — and what breaks if it is too long |
|---|---|---|
| User profile (non-sensitive) | 5 min | The user edits their own profile and expects to see it change. Longer, and they see the old avatar after saving and hit save again. |
| Product catalog (reads >> writes) | 1 h | Catalogue edits are deliberate, batched, and rare. Longer is usually fine; **shorten it hard for anything price-bearing** — a stale price is a chargeback, not a nit. |
| Settings / config | 10 min | The window between "operator flips a flag" and "the flag takes effect". Too long turns an incident mitigation into a deploy. |
| Search results | 60 s | A user re-running the same query within a minute expects the same result set. Longer, and a record they just created looks lost. |
| Aggregations / analytics | 5 min | Aggregates are already approximations and expensive to compute. Too long and a dashboard contradicts the detail view a user can open beside it. |
| i18n translations | 1 h (until deploy) | Changes ship with a release; the TTL is a safety net for the cache, not the invalidation mechanism. Bust on deploy. |
| Static reference data (countries, timezones) | 24 h | Genuinely near-immutable. Failure mode is a legislated timezone change arriving a day late. |

**When you cannot justify a row, that is the finding.** "Cite the table" is compliance theatre if the table is nine unexplained numbers; cite the *reason*, and if none of the reasons match your data class, measure the tolerance instead of borrowing a number.

## Observability

- **Cache hit rate per namespace.** There is no universal target — the right hit rate depends entirely on key cardinality and the read/write ratio, and a high-cardinality cache can be doing its job at 40%. Compute the threshold instead of adopting one: the hit rate is high enough when `misses/sec × miss cost` fits inside the origin's spare capacity with headroom for a cold start. If a number must go on a dashboard, derive it from that inequality and write the derivation next to it.
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

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the matched pattern + the fix. "Caching looks risky" without a cited read/write site is not a finding.

### 1. Cache write with no TTL and no size cap

```
BAD:   cache.set(key, value);      // no expiry → unbounded growth
GOOD:  cache.set(key, value, ttl);
```
Flag a `.set(` / `.put(` with no TTL/expiry arg (and a `noeviction` policy with no `maxmemory`) → `add-ttl`.

### 2. Cache key missing the tenant prefix

```
BAD:   cache.get(`products:${id}`)                         // cross-tenant collision
GOOD:  cache.get(`tenant:${tenantId}:products:${id}:v3`)
```
In a multi-tenant codebase, flag any key built without the `<tenant>:` segment (and version suffix) → `namespace-key`.

### 3. No stampede protection on a hot key

```
BAD:   if (cache.has(k)) return cache.get(k); else cache.set(k, load());   // race → thundering herd
GOOD:  cache.getOrSet(k, ttl, load);                                        // single-flight
```
Flag a check-then-set (`has`/`get` then `set`) on a hot read with no single-flight / stale-while-revalidate / jittered TTL → `add-stampede-protection`.

### 4. Caching correctness-critical state

A cache read/write holding a **copy** of correctness-critical state whose truth lives elsewhere — a cached auth/permission decision, a cached token-validity flag, payment or stock-at-checkout state, real-time metrics → `do-not-cache`. **Does not fire** on a shared store that is the source of truth for that data (session store, rate-limit counter, distributed lock) — that is `backend-principles` PERF-6 being satisfied, not violated. Cite which of the two roles the key plays; a finding that cannot say is not emittable.

**Closure verbs:** `add-ttl`, `namespace-key`, `add-stampede-protection`, `do-not-cache`.

## Forbidden

- Unbounded caches (no TTL + no size limit = memory leak).
- Cache key without tenant prefix in multi-tenant systems.
- Caching responses from authenticated endpoints with a shared key.
- `if cache.has(k): return cache.get(k) else cache.set(...)` — race; use getOrSet.
- Caching without a clear invalidation strategy.
- Stale data silently served where correctness matters (inventory, payment).
- Redis memory policy = `noeviction` with no size cap (OOM + crash).
