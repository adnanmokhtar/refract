---
name: cache-aside
description: "Pattern: Cache-aside (scoped key, stampede-protected, invalidate-on-write)"
kind: ai-pattern
---

# Pattern: Cache-aside (scoped key, stampede-protected, invalidate-on-write)

> **Hard rule** — Every cache key for scoped data namespaces the caller's TENANT + PERMISSION/VISIBILITY scope + a SCHEMA VERSION (an unscoped shared key is a cross-tenant cache LEAK); every write INVALIDATES the derived keys (or the read carries a short TTL + freshness label); every entry has a BOUNDED TTL with JITTER; a miss on a hot key is STAMPEDE-PROTECTED by singleflight + a distributed lock so one loader hits the origin; negative results get a HARD-bounded short TTL; the cache is NEVER the source of truth and FAILS OPEN to the origin on a cache outage.

**When to apply**
- Read-heavy lookups over data that is expensive to compute/fetch and tolerates bounded staleness — entity-by-id, rendered views, aggregates, permission-filtered lists.
- Multi-tenant products where a cached value varies by tenant AND by the viewer's permissions/visibility, and must never cross either line.
- Hot keys with high read fan-out (a viral item, a popular config) where a single expiry would otherwise stampede the origin.

**When NOT to apply**
- Strongly-consistent / read-your-writes paths where any staleness is incorrect (a balance you just debited, an idempotency-key check) — read the origin, or use a write-through cache invalidated transactionally.
- Secrets and authorization *decisions* — cache the scoped *inputs*, never the secret in a shared store and never the allow/deny across principals.
- Tiny, cheap, already-fast origin reads where the cache round-trip + key machinery is pure overhead.

**Halt conditions / mandatory cites**
- Cite the key builder at `<path:line>` and confirm it includes tenant + permission scope + version. A key built from only an entity id for scoped data = halt (cross-tenant leak).
- Cite the scope source at `<path:line>` — tenant/permission must come from the auth context, not request input. Client-supplied scope = halt.
- Cite the TTL + jitter at `<path:line>`. Absent/infinite TTL, or identical TTL with no jitter = halt.
- Cite the stampede guard (singleflight + lock / early recompute) at `<path:line>` for any hot/expensive key. None = halt.
- Cite the write-path invalidation at `<path:line>`. A write with no eviction and no short-TTL-label = halt (stale-forever).
- Cite the negative-cache TTL cap and the fail-open fallback at `<path:line>`.
- Grep ban: "the cache is scoped/safe/protected" without file:line for the scoped key, the lock, the TTL, and the invalidation.

## Why

A cache is simultaneously a security boundary (a scoped value served to the wrong principal is a leak), an availability dependency (a herd on origin or a hard cache dependency takes the system down), and a correctness surface (stale-forever reads). The recurring failure modes:

1. **It leaks across principals** — one key that omits the tenant or the viewer's permission scope serves tenant A's (or role A's) value to B. Endpoint auth doesn't help; the KEY is the boundary, namespaced from the auth context.
2. **It melts the origin** — a hot key expires and N concurrent misses all call the origin at once (thundering herd), or 10k keys warmed together expire on the same tick. Singleflight + lock + jitter so exactly one loader runs per key per moment.
3. **It serves stale forever** — a write that doesn't invalidate, behind an infinite TTL, pins the pre-write value indefinitely. Invalidate on write, or bound the TTL and label freshness.
4. **It becomes a dependency / a source of truth** — failing the request when Redis is down, or acknowledging a write that only landed in the cache. The cache is a latency optimization over a durable origin; fail open, persist first.

The pattern: build a scoped, versioned key; read through a cache-aside helper that owns the singleflight + lock + TTL + jitter + negative-cache + fail-open; invalidate on every write.

## Scoped, versioned key builder

```ts
// src/cache/cache-key.ts

/** Bumped whenever the cached value's SHAPE changes — old/new shapes never collide. */
const SCHEMA_VERSION = 'v3';

export interface CacheScope {
  tenantId: string;                      // from the AUTH CONTEXT, never request input
  /** Stable digest of the dimensions that change the value: role set, ABAC attrs, locale, flags. */
  permissionScope: ReadonlyArray<string>;
}

/** Deterministic, order-independent digest of the permission/visibility dimensions. */
function scopeHash(scope: CacheScope): string {
  const parts = [...scope.permissionScope].sort();      // order-independent
  return sha256(parts.join('|')).slice(0, 16);          // short, stable
}

/**
 * Key shape: <app>:<entity>:<ver>:t<tenant>:s<scope>:<id>
 * The tenant + permission scope + version are ALWAYS in the key for scoped data.
 * A key without t<tenant>:s<scope> for scoped data is a cross-tenant leak.
 */
export function cacheKey(entity: string, scope: CacheScope, id: string): string {
  return `app:${entity}:${SCHEMA_VERSION}:t${scope.tenantId}:s${scopeHash(scope)}:${id}`;
}

/** Pattern to invalidate every scoped variant of one entity id, across all viewers. */
export function entityKeyPattern(entity: string, tenantId: string, id: string): string {
  return `app:${entity}:${SCHEMA_VERSION}:t${tenantId}:s*:${id}`;
}
```

> The examples below use a Redis-style client + a TypeScript idiom for illustration. Substitute your project's actual cache client and helpers from `.claude/_extracted-codebase.md` — the SHAPE (scoped/versioned key → lock-guarded single load → bounded TTL+jitter → negative-cache → fail-open) is universal, not the specific client names.

## Read-through / cache-aside with singleflight + lock (stampede-protected)

```ts
// src/cache/cache-aside.ts

interface CacheAsideOpts {
  ttlMs: number;                 // bounded — never Infinity / absent
  jitter?: number;              // fraction, default 0.1 → ±10%
  negativeTtlMs?: number;       // hard-capped short TTL for misses/errors, default 5_000
  lockTtlMs?: number;           // distributed lock lease, default 5_000
}

const NEGATIVE = Symbol('negative-cache-sentinel');

export class CacheAside {
  constructor(
    private redis: RedisClient,            // distributed cache
    private locks: LockClient,             // SET NX PX distributed lock
    private inflight = new Map<string, Promise<unknown>>(),   // in-process singleflight
  ) {}

  /** Read-through: serve from cache, else load ONCE through a lock, then populate. */
  async getOrLoad<T>(
    key: string,
    load: () => Promise<T | null>,
    opts: CacheAsideOpts,
  ): Promise<T | null> {
    // 1. Try the cache (fail OPEN to origin on a cache outage — never fail-closed).
    let raw: string | null;
    try {
      raw = await this.redis.get(key);
    } catch (err) {
      metrics.inc('cache.backend_error', { key });
      return load();                        // cache down → degrade to origin, request still succeeds
    }
    if (raw === NEGATIVE_MARKER) return null;        // honored negative cache
    if (raw !== null) { metrics.inc('cache.hit', { key }); return deserialize<T>(raw); }
    metrics.inc('cache.miss', { key });

    // 2. In-process singleflight — dedupe concurrent misses in THIS process to one promise.
    const existing = this.inflight.get(key);
    if (existing) { metrics.inc('cache.stampede_suppressed', { key, kind: 'singleflight' }); return existing as Promise<T | null>; }

    const work = this.loadUnderLock(key, load, opts).finally(() => this.inflight.delete(key));
    this.inflight.set(key, work);
    return work;
  }

  /** Across processes: a distributed lock so exactly ONE node loads the origin per key. */
  private async loadUnderLock<T>(key: string, load: () => Promise<T | null>, opts: CacheAsideOpts): Promise<T | null> {
    const lockKey = `lock:${key}`;
    const token = randomToken();
    const got = await this.locks.acquire(lockKey, token, opts.lockTtlMs ?? 5_000);   // SET NX PX

    if (!got) {
      // Someone else is loading — wait briefly for them to populate, then re-read; don't pile onto origin.
      metrics.inc('cache.stampede_suppressed', { key, kind: 'lock' });
      await sleep(jitteredBackoff(50, 250));
      const filled = await this.redis.get(key).catch(() => null);
      if (filled !== null && filled !== NEGATIVE_MARKER) return deserialize<T>(filled);
      return load();                        // lock holder slow → fall through to origin (bounded), don't hang
    }

    try {
      const value = await load();           // the ONE origin call
      if (value === null) {
        // Negative cache: short, hard-capped TTL distinct from the positive TTL.
        await this.redis.set(key, NEGATIVE_MARKER, 'PX', opts.negativeTtlMs ?? 5_000);
        return null;
      }
      await this.redis.set(key, serialize(value), 'PX', withJitter(opts.ttlMs, opts.jitter ?? 0.1));
      return value;
    } finally {
      await this.locks.release(lockKey, token);   // release only if we still own the lease
    }
  }
}

/** Bounded TTL + jitter so a batch written together does not expire on the same tick. */
function withJitter(ttlMs: number, jitter: number): number {
  if (!Number.isFinite(ttlMs) || ttlMs <= 0) throw new Error('cache TTL must be bounded and positive');
  const delta = ttlMs * jitter;
  return Math.round(ttlMs - delta + Math.random() * 2 * delta);   // ttl * (1 ± jitter)
}
```

One miss → one origin load. The rest are suppressed in-process (singleflight) and across processes (lock). The TTL is bounded and jittered. A cache outage degrades to the origin instead of failing the request.

## Call site: scope from the auth context, never client input

```ts
// src/modules/catalog/product.service.ts

async getProduct(ctx: AuthContext, productId: string): Promise<Product | null> {
  const scope: CacheScope = {
    tenantId: ctx.tenantId,                                  // auth context — NOT req.query.tenantId
    permissionScope: [ctx.role, ...ctx.visibilityTags],     // dimensions that change the value
  };
  const key = cacheKey('product', scope, productId);

  return this.cache.getOrLoad(
    key,
    () => this.repo.findProductForViewer(ctx, productId),   // origin: itself tenant + permission filtered
    { ttlMs: 60_000, jitter: 0.1, negativeTtlMs: 5_000 },
  );
}
```

The origin loader is itself tenant + permission scoped — the cache never widens what the query would return. The key carries the same scope, so two viewers with different permissions never share an entry.

## Write path: invalidate every derived key

```ts
// src/modules/catalog/product.write.service.ts

async updateProduct(ctx: AuthContext, productId: string, patch: ProductPatch): Promise<void> {
  // 1. Persist to the ORIGIN first — the cache is never the source of truth.
  await this.repo.update(ctx.tenantId, productId, patch);

  // 2. Invalidate EVERY scoped variant of this entity for this tenant (all viewers).
  await this.cache.deleteByPattern(entityKeyPattern('product', ctx.tenantId, productId));

  // 3. Invalidate derived/aggregate keys this entity feeds (lists, counts, rollups).
  await this.cache.delete(cacheKey('product-list', { tenantId: ctx.tenantId, permissionScope: [] }, patch.categoryId));

  // 4. (Optional) publish an invalidation event so other nodes/regions evict too.
  await this.events.publish('product.changed', { tenantId: ctx.tenantId, productId });
}
```

The write commits to the origin, then evicts the cached entity AND its derived keys. If precise invalidation of a derived key is infeasible, that read MUST instead use a short TTL + a freshness label — never an unbounded TTL with no invalidation.

## Negative cache (bounded, distinct TTL)

```ts
// A "not found" or a transient origin error is cached only with a SHORT, hard-capped TTL —
// distinct from the positive TTL — so a one-second blip can't pin an empty/error value for an hour.
const NEGATIVE_MARKER = ' NEG';     // sentinel distinguishable from any real serialized value

// In loadUnderLock above:
//   value === null  -> redis.set(key, NEGATIVE_MARKER, 'PX', negativeTtlMs ?? 5_000)
// On a thrown origin error you may negative-cache for an even shorter window, or not at all —
// NEVER with the positive TTL, NEVER unbounded.
```

A transient error must not become authoritative. Negative TTL is seconds, never the positive TTL, never unbounded.

## Stale-while-revalidate (hot read-heavy keys)

```ts
// For a hot key, serve the slightly-stale value instantly while ONE background loader refreshes —
// bounds tail latency AND herd at once. Store a soft-expiry alongside the value.
async getSWR<T>(key: string, load: () => Promise<T>, opts: { freshMs: number; staleMs: number }): Promise<T> {
  const entry = await this.redis.get(key).catch(() => null);
  if (entry) {
    const { value, freshUntil } = deserialize<{ value: T; freshUntil: number }>(entry);
    if (Date.now() < freshUntil) return value;                  // still fresh
    void this.refreshInBackground(key, load, opts);            // stale-but-usable: refresh async, one loader
    return value;                                              // serve stale now, no herd
  }
  return this.loadUnderLock(key, load, { ttlMs: opts.staleMs }) as Promise<T>;
}
```

Read-heavy hot keys serve instantly and refresh once in the background — the origin sees one load per refresh window, not one per request.

## Common mistakes

### Unscoped shared key
`cache.get('product:' + id)` for data that varies by viewer permission → viewer B gets viewer A's filtered value. Namespace tenant + permission scope + version into the key.

### Client-supplied scope
`key = 'product:t' + req.query.tenantId + ':' + id` → settable to any tenant. Scope comes from the verified auth context only.

### Write without invalidation
`await repo.update(...)` with the cache untouched behind an infinite TTL → the pre-update value is served forever. Evict the entity + derived keys on write, or short-TTL + label.

### Infinite / absent TTL
`redis.set(key, val)` with no expiry → unbounded memory + permanent staleness risk. Every entry gets a bounded TTL.

### Synchronized expiry
Warming 10k keys with identical TTL → they expire on the same second → 10k simultaneous misses. Add ±jitter to every TTL.

### Thundering herd
A viral key expires; 5,000 requests all miss and all call the origin → origin falls over. Singleflight + distributed lock: one loads, the rest wait or serve stale.

### Cached authz decision
`cache.set('can:' + resourceId, allowed)` → A's allow served to B. Cache the scoped inputs (role set, owner), compute the decision per request.

### Secret / unscoped PII in a shared cache
An API token or unscoped PII in a shared, served-back store → leaks to another principal. Secrets never enter a shared cache; PII is scoped + short-TTL.

### Negative-cache poison
A transient 500 cached as "empty" with the positive TTL → every reader gets empty for an hour. Hard-cap the negative TTL to seconds, distinct from positive.

### Cache as source of truth
Acknowledging a write that only hit the cache, or failing the request when Redis is down → data loss / availability coupling. Persist to origin first; fail open to origin.

### Hand-built keys scattered
`'user:'+id` in one file, `'users:'+id` in another → fragmented cache + the scope bug recurs wherever a prefix is forgotten. Build every key through the shared builder.

## Cross-references

- `<rules-path>/caching-discipline.md` — the hard-rule list (scoped key, invalidate-on-write, bounded TTL + jitter, stampede protection, no cached authz, negative-cache cap, fail-open).
- `<rules-path>/multi-tenant-isolation.md` — tenant scope is the security boundary; the cache key carries the same tenant predicate the query does.
- `<rules-path>/rate-limit-enforcement.md` — coalesce / rate-limit origin loads on cache miss so a cold cache can't melt the origin.
- `<rules-path>/audit-log-integrity.md` — flush/invalidation of sensitive cached data is an audited operational event.
- `<patterns-path>/report-generation.md` — cached aggregates carry a freshness label + event-driven invalidation; never serve a stale aggregate as if live.
- `<commands-path>/probe-cache.md` — inspect a specific cache usage (key scope, TTL, invalidation, stampede protection).
- `<agents-path>/caching-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-cache-topology.md` — ADR pinning the cache backend, key/scope convention, invalidation strategy, and the fail-open contract.
