---
description: Probe a specific cache usage — key scope (tenant/permission/version), TTL (bounded? jittered?), invalidation-on-write, stampede protection, and whether authz/PII is cached — from real source, never an assumed key shape.
---

# /probe-cache

Diagnose whether a specific cache usage is safe + sound: what scope is baked into the key, whether it has a bounded jittered TTL, whether writes invalidate it, whether a hot-key miss is stampede-protected, and whether it caches anything it must not — from the REAL key builder + read + write sites, not a guess.

## Premise

Real signals only. Cite the actual cache key construction at `<path:line>`, the read site (`getOrLoad` / raw `redis.get`) at `<path:line>`, the TTL argument at `<path:line>`, the write/invalidation site at `<path:line>`, and the scope source (auth context vs. client input) at `<path:line>` — never narrate a key shape you didn't read. Read before probing: locate the key builder in source and trace what dimensions actually go into the key BEFORE judging it.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the key construction at `<path:line>` and the literal key shape, (2) the scope baked into the key — tenant + permission/visibility + schema version, or "MISSING — cross-tenant cache leak", (3) the TTL at `<path:line>` — bounded? jittered? or "NONE/UNBOUNDED", (4) the write-path invalidation at `<path:line>` or "NONE — stale-forever", (5) the stampede protection (singleflight / lock / early recompute) at `<path:line>` or "NONE", and (6) whether an authz decision or PII/secret is cached. If any cannot be produced from real source, HALT and say which — never an assumed key, never an assumed TTL.

READ-ONLY. This probe never writes to, flushes, or mutates the cache; it reads source and (optionally) inspects key metadata (`TTL <key>`) against a NON-PROD instance only — never flush, never against production.

## What it does

1. **Locate the read** — find where the value is read from cache; cite `<path:line>` and whether it goes through the cache facade (`getOrLoad`) or a raw `redis.get` with a hand-built key.
2. **Resolve the key** — trace the key builder; print the literal key shape (`app:product:v3:t<tenant>:s<scope>:<id>`). Identify every dimension actually in the key.
3. **Check the scope** — does the key namespace tenant + permission/visibility + a schema version? Is the tenant/scope sourced from the auth context or from client input (`req.query`/`req.body`/header)? Cite `<path:line>`. Missing scope or client-supplied scope = CROSS-TENANT CACHE LEAK.
4. **Check the TTL** — is there a TTL? Is it bounded (finite, not `set` with no expiry)? Is it jittered? Cite the TTL argument at `<path:line>`. None/unbounded/un-jittered = finding.
5. **Check invalidation** — find the write path for this entity; does it evict/update the derived keys (and aggregates) after persisting? Cite `<path:line>`. No invalidation behind a long TTL = stale-forever finding.
6. **Check stampede protection** — for a hot/expensive key, is the miss guarded by singleflight + a distributed lock / early recompute / stale-while-revalidate? Cite `<path:line>`. None = herd finding.
7. **Check forbidden caching** — is an authorization *decision* cached across principals? Is a secret or unscoped PII in a shared store? Cite `<path:line>`.
8. **Check fail-open** — on a cache backend error, does the read fall through to the origin (fail open) or fail the request (fail closed)? Cite `<path:line>`.
9. **Report** — key-scope verdict, TTL verdict, invalidation verdict, stampede verdict, forbidden-cache verdict, fail-open verdict, and the top fix.

## Flow

```text
locate read site (<path:line>)                              [finding if raw client + hand-built key]
  -> resolve key builder -> print literal key shape
  -> scope in key? tenant + permission + version            [BLOCKER if missing]
  -> scope source: auth context vs client input             [BLOCKER if client-supplied]
  -> TTL bounded + jittered?                                 [finding if none/unbounded/un-jittered]
  -> write path invalidates derived keys?                   [finding if none behind long TTL]
  -> hot-key miss stampede-protected?                       [finding if none]
  -> authz decision / secret / unscoped PII cached?         [BLOCKER if yes]
  -> fail open to origin on cache outage?                   [finding if fail-closed]
  -> report: scope + TTL + invalidation + stampede + verdict + top fix
```

## Output

```
/probe-cache — <entity> @ <path:line>

Read site (<path:line>):     cache.getOrLoad(key, loader, { ttlMs: 60000 })   [or: raw redis.get — finding]
Key shape (<path:line>):     app:product:v3:t<tenant>:s<scopeHash>:<id>

Scope in key:     tenant=YES  permission=YES  version=v3                 [or: MISSING — cross-tenant cache leak]
Scope source:     ctx.tenantId (auth context) @ product.service.ts:22   [or: req.query.tenantId — BLOCKER]
TTL:              60000ms, jitter ±10% @ cache-aside.ts:71              [or: NONE / UNBOUNDED — finding]
Invalidation:     deleteByPattern on update @ product.write.ts:14       [or: NONE — stale-forever finding]
Stampede:         singleflight + lock @ cache-aside.ts:48               [or: NONE — herd finding]
Forbidden cache:  none                                                   [or: authz decision / secret / PII — BLOCKER]
Cache outage:     fail-open to origin @ cache-aside.ts:34               [or: fail-closed — finding]

Verdict: OK | NEEDS-SCOPE | NEEDS-TTL | NEEDS-INVALIDATION | NEEDS-STAMPEDE | BLOCKER(leak)

Top recommendation:
  - <e.g. add tenant+permission scope to the key; or add invalidation on the write path; or wrap the miss in singleflight+lock>
```

## Rules

- READ-ONLY. Never flush, never write the cache, never inspect a production instance. Key-TTL inspection (`TTL <key>`) is non-prod only.
- Cite-or-halt: real key builder, real read site, real TTL argument, real invalidation, real scope source — or halt naming what's missing.
- Always print the scope verdict first; a missing or client-supplied scope is a CROSS-TENANT CACHE LEAK, reported first.
- A cached authorization decision across principals, or a secret / unscoped PII in a shared store, is a BLOCKER, not an aside.
- Never report a key shape, TTL, or invalidation you didn't read from source.

## Cross-references

- `.claude/rules/caching-discipline.md` — the hard-rule list this command enforces (scoped key, bounded TTL + jitter, invalidate-on-write, stampede protection, no cached authz, fail-open).
- `ai/patterns/cache-aside.md` — the scoped key builder + singleflight/lock read-through + invalidation shapes this probe checks against.
- `<agents-path>/caching-reviewer.md` — review gate that consumes these findings.
