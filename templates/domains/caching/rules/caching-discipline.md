---
name: caching-discipline
description: Caching discipline
kind: rule
---

# Caching discipline

## Hard rule

Every cache key for per-tenant / per-user / permission-scoped data MUST namespace the **tenant + the permission/visibility scope + a schema/version tag** into the key — an unscoped shared key for scoped data is a CROSS-TENANT CACHE LEAK (user A's value served to user B), the single most damaging caching bug. Every write that changes cached data MUST invalidate (evict or update) the affected keys, or the read MUST carry a short bounded TTL with an explicit freshness label — stale-forever reads are forbidden. Every entry MUST have a BOUNDED TTL with jitter (no infinite/absent TTL, no synchronized expiry). A popular key's miss MUST be stampede-protected (singleflight / lock / early recompute) so N concurrent misses don't hammer the origin. Authorization decisions are NEVER cached across principals; PII/secrets are NEVER placed in a shared, served-back store without scoping. Negative results (errors/empties) get a HARD-bounded short TTL. The cache is NEVER the source of truth: it MUST be reconstructible from the origin, fail OPEN to the origin on a cache outage (never fail-closed), and never hold an un-persisted write.

A caching bug is a silent cross-tenant leak, a melted origin under a thundering herd, or numbers that are stale forever — each erodes trust far more than a cache miss.

## Must

- **Scope every key**: keys for scoped data are namespaced `<app>:<entity>:v<schema>:t<tenantId>:<scopeHash>:<id>` where `<scopeHash>` derives from the caller's permission/visibility set (role, ABAC attributes, feature flags that change the value). The tenant id comes from the AUTH CONTEXT, never from client input. A key built from only an entity id, for data that varies by tenant or permission, is forbidden.
- **Version-tag the key**: bake a schema/serializer version into the key (`v3`). A value-shape change bumps the tag so old and new shapes never collide — this is how you invalidate "everything of this shape" in one deploy without a flush.
- **Invalidate on write**: the write path evicts or updates every key derived from the mutated entity (and its derived/aggregate keys) in the same transaction boundary as the write, or publishes an invalidation event the cache layer consumes. If precise invalidation is infeasible, the read MUST use a short TTL + a freshness label — never an unbounded TTL with no invalidation.
- **Bounded TTL + jitter**: every entry sets an explicit TTL; the TTL carries randomized jitter (e.g. `ttl * (1 ± 0.1)`) so a batch of keys written together do not all expire on the same tick and stampede the origin simultaneously.
- **Stampede protection on hot keys**: a miss on a popular/expensive key is guarded by singleflight (in-process dedupe) AND a distributed lock / early-recompute so exactly one loader hits the origin while the rest wait for the result or briefly serve the stale value. N concurrent misses MUST NOT become N origin calls.
- **Read-through, write-aware**: reads go through a cache-aside / read-through helper that owns the key build + lock + TTL + negative-cache; feature code calls `cache.getOrLoad(scope, id, loader)`, not raw `redis.get` with a hand-built key.
- **Authz is per-request**: an allow/deny decision is computed per request against the live principal; it is never cached under a key that another principal can hit. Cache the *inputs* (a user's role set, a resource's owner) with their own scoped keys + invalidation — never the *decision* across principals.
- **PII/secret handling**: secrets are never cached in a shared store. PII cached for a scoped key is scoped to the owning principal, has a short TTL, and the store's encryption-at-rest + access posture is considered explicitly (see `<rules-path>/secrets-handling.md`-style policy).
- **Negative cache is hard-bounded**: caching "not found" / "empty" / a transient error is allowed only with a SHORT capped TTL (seconds), distinct from the positive TTL, so a momentary origin blip or a race doesn't pin an empty/error value as authoritative.
- **Fail open to origin**: on a cache backend outage (timeout, connection error), the read falls through to the origin (degraded latency) rather than failing the request. The cache is a latency optimization, not an availability dependency on the hot path.
- **Cache is reconstructible**: the entire cache can be cold-flushed and rebuilt from the origin with no data loss. No write is acknowledged to the client until it is durable in the origin; the cache only ever reflects already-persisted state.
- **Observe it**: emit hit/miss/load-latency/stampede-suppressed/eviction metrics per key prefix; alert on hit-rate collapse, origin-call spikes on a single key (herd), and any key prefix with an unbounded/absent TTL.

## Must not

- Cache per-tenant or per-user data under a key that omits the tenant + permission scope — cross-tenant cache leak.
- Build the tenant/scope portion of a key from client-supplied input (`req.query.tenantId`) instead of the auth context.
- Write to the origin and not invalidate (or short-TTL-label) the derived cache entries — stale-forever reads.
- Set no TTL / an infinite TTL on cached data, or give a batch of keys an identical TTL with no jitter (synchronized expiry → herd).
- Let N concurrent misses on one hot key become N origin loads (no singleflight / no lock / no early recompute).
- Cache an authorization decision (allow/deny) under a key reachable by a different principal.
- Put secrets, or unscoped PII, into a shared cache that can be served back to another principal.
- Cache a transient error or empty result with the positive TTL (or no cap) — negative-cache poisoning pins the bad value.
- Treat the cache as the source of truth: acknowledge a write that lives only in the cache, or fail the request closed when the cache is down.
- Hand-build cache keys inline across the codebase with `redis.get('user:' + id)` — drift in key shape silently fragments the cache and re-introduces the scope bug.

## Should

- Wrap all caching behind a project-internal `<Cache>` / `<CacheAside>` facade that owns key construction (scope namespacing), TTL + jitter, singleflight + distributed lock, negative-cache, and fail-open — so the discipline is enforced in one place, not re-derived per call site.
- Prefer event-driven invalidation (publish on write, subscribe in the cache layer) over pure TTL when correctness matters; reserve TTL-only for data where bounded staleness is acceptable and labeled.
- Co-locate the key builder with the entity so the scope dimensions (tenant, permission, version) are declared once and every read/write/invalidate uses the same builder.
- For cached aggregates / reports, carry an explicit freshness label ("data as of <ts>") and invalidate on the underlying event — never serve a stale aggregate as if live (see `<patterns-path>/report-generation.md`).
- Rate-limit / coalesce origin loads triggered by cache misses so a cache flush or cold start can't melt the origin (see `<rules-path>/rate-limit-enforcement.md`).
- Use a stale-while-revalidate window for read-heavy hot keys: serve the slightly-stale value instantly while one background loader refreshes — bounds tail latency and herd at once.
- Log structured `{ keyPrefix, hit, loadMs, stampedeSuppressed, ttlMs, scope }` per cache op; alert on per-prefix hit-rate, herd events, and TTL anomalies.

## Review checklist (PRs touching cache reads / writes / keys / invalidation)

- [ ] Every key for scoped data namespaces tenant + permission/visibility scope + schema version; cite the key builder at `<path:line>`.
- [ ] The tenant/scope portion of the key derives from the auth context, not client input.
- [ ] The write path invalidates (or short-TTL-labels) every derived key; cite the invalidation at `<path:line>`.
- [ ] Every entry has a bounded TTL with jitter — no infinite/absent TTL, no synchronized expiry.
- [ ] Hot/expensive keys have stampede protection (singleflight + lock / early recompute); cite it at `<path:line>`.
- [ ] No authorization decision is cached across principals; only scoped inputs are cached.
- [ ] No secrets / no unscoped PII in a shared, served-back store.
- [ ] Negative results use a short, hard-capped, distinct TTL.
- [ ] The read fails OPEN to the origin on a cache outage (not fail-closed); cite the fallback at `<path:line>`.
- [ ] No write is acknowledged that lives only in the cache; cache reflects already-persisted state.
- [ ] Keys are built via the shared builder/facade, not hand-concatenated at the call site.

## Anti-patterns

- **Unscoped shared key** — `cache.get('profile:' + userId)` for data that also varies by the *viewer's* permission → viewer B gets viewer A's permission-filtered value. The #1 caching security bug. Namespace tenant + permission scope into the key.
- **Client-supplied scope** — `key = 'orders:t' + req.query.tenantId` → set it to anyone's tenant and read their cache. Scope comes from the verified auth context only.
- **Write without invalidation** — `await db.update(user); /* cache untouched */` → the next read serves the pre-update value forever (infinite TTL) or for the full TTL window. Evict/update on write, or short-TTL + label.
- **Infinite TTL** — `redis.set(key, val)` with no expiry → memory grows unbounded and a stale value can pin permanently. Always set a bounded TTL.
- **Synchronized expiry** — warming 10k keys at deploy with identical TTL → they all expire on the same second → 10k simultaneous misses stampede the origin. Add jitter.
- **Thundering herd** — a viral item's key expires; 5,000 concurrent requests all miss and all call the origin → origin falls over. Singleflight + lock so one loads, the rest wait.
- **Cached authz decision** — `cache.set('can:' + resourceId, allowed)` → user A's allow is served to user B for the same resource. Authz is per-request; cache only the scoped inputs.
- **Secret in shared cache** — an API token cached under a shared key and served back to another tenant. Secrets never enter a shared, served-back store.
- **Negative-cache poison** — a transient 500 from the origin cached as "empty" with the positive TTL → every reader gets "empty" for an hour after a one-second blip. Hard-cap negative TTL to seconds.
- **Cache as source of truth** — acknowledging a write that only landed in the cache, or failing the request when Redis is down → data loss / availability coupling. Persist to origin first; fail open to origin.
- **Hand-built keys everywhere** — `'user:'+id` in one file, `'users:'+id` in another → two caches for one entity, and the scope bug re-appears wherever someone forgets the tenant prefix. Build keys through one shared builder.

## Enforcement

- `<commands-path>/probe-cache.md` (slash: `/probe-cache`) — inspects a specific cache usage from real source: the key construction at `<path:line>`, what scope is baked into the key (tenant/permission/version — or MISSING = cross-tenant leak), the TTL (bounded? jittered? or none), the invalidation path on write, the stampede protection, and whether authz/PII is cached — cite-or-halt, never an assumed key shape.
- `<agents-path>/caching-reviewer.md` — review gate hard-failing on unscoped shared keys, missing invalidation, absent/unbounded TTL, missing stampede protection, cached authz decisions, secrets/PII in a shared cache, negative-cache poisoning, and cache-as-source-of-truth.
- CI lint MUST reject raw `redis.get` / `redis.set` (or the project's client) called with a string-concatenated key outside the cache facade — keys must go through the builder (AST heuristic; flag for review).
- CI lint MUST reject `set`/`setex` calls on the cache client with no TTL argument for cacheable data.
- CI lint SHOULD flag any cache key builder for scoped entities that does not reference a tenant + permission scope parameter.
- TODO: `scripts/validate-cache-keys.sh` to AST-walk cache key builders and assert each scoped-entity key includes a tenant + permission + version dimension, and that each cached read site has a bounded TTL and a fail-open fallback.

## Cross-references

- `<patterns-path>/cache-aside.md` — scoped key builder + read-through/cache-aside with singleflight + lock + bounded TTL + jitter + write invalidation + negative-cache code shapes.
- `<rules-path>/multi-tenant-isolation.md` — tenant scoping as the security boundary; the cache key must carry the same tenant predicate the query does.
- `<rules-path>/rate-limit-enforcement.md` — coalesce / rate-limit origin loads on cache miss so a cold cache can't melt the origin.
- `<rules-path>/audit-log-integrity.md` — invalidation/flush of sensitive cached data is an audited operational event.
- `<patterns-path>/report-generation.md` — cached aggregates carry a freshness label + event-driven invalidation; never serve a stale aggregate as if live.
- `<commands-path>/probe-cache.md` — per-usage cache diagnostic.
- `<agents-path>/caching-reviewer.md` — review gate.
- `<adr-path>/<NNN>-cache-topology.md` — ADR pinning the cache backend, scope/key convention, invalidation strategy (event-driven vs. TTL), and the fail-open contract.
