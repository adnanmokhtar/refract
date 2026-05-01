---
name: multi-tenancy
description: Pattern: Multi-Tenancy (Request-Scoped Context)
kind: ai-pattern
---

# Pattern: Multi-Tenancy (Request-Scoped Context)

> **Hard rule** — `tenantId` is resolved server-side and propagated via `AsyncLocalStorage` (or equivalent); it is NEVER read from request body/query/header by feature code, NEVER passed as a controller arg from the client. A single leak = security incident.

**When to apply**
- Any system serving multiple tenants from shared infrastructure (DB, cache, queue, search).
- Webhooks / cron jobs / queue workers that must operate under a specific tenant's context.
- Internal admin tools that legitimately cross tenants — those use a SEPARATE explicit admin path.

**When NOT to apply**
- Single-tenant deployments (one customer, one DB) where `tenantId` is a constant — skip the ceremony.
- Truly global data (countries, currencies, system enums) — `skipTenantPrefix: true` with a comment.
- Pre-auth public endpoints (login, signup before tenant binding) — handle tenancy at resolution boundary.

**Halt conditions / mandatory cites**
- Cite the resolution chain (`TenantResolutionMiddleware` or webhook resolver) at `<path:line>`. No resolution = halt.
- Cite `TenantContext.run()` wrapping every async entry point (HTTP handler, queue worker, cron) at `<path:line>`. Missing on any path = leak.
- Cite the cross-tenant leak test for at least one repo at `<path:line>`. No test = halt.
- Cite cache-key construction with tenant prefix at `<path:line>`. String-concat keys without prefix helper = halt.
- Grep ban: "we filter by tenant" without file:line for resolver, context wrapper, repo filter, and leak test.

Each request carries tenant identity through every layer. A single leak = security incident.

## Tenant resolution chain

Order of resolution (first match wins):

1. **Domain** — `Host` header → `tenants.domain`
2. **Landing product** — path prefix → `tenants.landing_product_id`
3. **A/B test** — feature-flag cookie → experiment tenant
4. **`X-Product-Id` header** — explicit from admin portals
5. **`X-API-Key`** — server-to-server
6. **Webhook** — signed payload's phone_number_id / stripe_account / etc.

Resolution lives in `TenantResolutionMiddleware` (REST) or dedicated webhook resolver. Once resolved, tenant goes into `AsyncLocalStorage` via `TenantContext.run(tenant, handler)`.

## Context access

```ts
// Read anywhere downstream — services, repos, mappers
const { tenantId } = TenantContext.get();

// NEVER accept tenantId as a function arg from controllers.
// NEVER read it from request body / params / query.
```

## Repository auto-filter

Every repo extends `TenantScopedRepository<T>`. The base class injects `tenant_id` into every query builder:

```ts
protected scope<Q extends SelectQueryBuilder<T>>(qb: Q): Q {
  return qb.andWhere(`${qb.alias}.tenant_id = :tenantId`, {
    tenantId: TenantContext.get().tenantId,
  });
}
```

Raw SQL must apply this filter explicitly — no exceptions.

## Cache keys

Tenant-prefixed by default via `buildKey(namespace, key)`:
- `tenant:abc-123:products:all`
- `tenant:abc-123:settings:*`

`skipTenantPrefix: true` ONLY for truly global data (countries, currencies, static enums). Any other use requires a code-comment justification referencing this rule.

## Events

- Tenant ID lives in event metadata, NEVER payload.
- Receivers call `TenantContext.run(metadata.tenant, () => handler(payload))`.
- Payloads carry IDs, not cross-tenant data.

## Required tests

Every repo ships a cross-tenant leak test:

```ts
it('does not return tenant B rows to tenant A', async () => {
  await seed({ tenantId: 'A', ... });
  await seed({ tenantId: 'B', ... });
  const results = await TenantContext.run({ tenantId: 'A' }, () =>
    repo.findAll()
  );
  expect(results).toHaveLength(1);
});
```

## Forbidden

- Hardcoded tenant IDs.
- `tenantId` from request body/query — always from context.
- Cross-tenant foreign keys.
- Raw SQL without explicit tenant filter.
- Cache keys built by string concat.

## Common mistakes (named anti-patterns)

- **Client-supplied tenant id.** `req.body.tenantId` / `req.query.tenant_id` / `X-Tenant-Id` header read in feature code. Server decides tenant; client never does. The server-side resolution chain is the only authority.
- **Convenience cross-tenant repo method.** "Just for the admin job" — a method on a tenant-scoped repo that skips the filter. Soon a feature handler imports it. Cross-tenant access lives in a SEPARATE `*.admin-repository.ts` (or equivalent) so audits can grep for it.
- **Cache key string-concat.** `cache.get('products:' + id)` instead of `buildKey('products', id)` — sooner or later a tenant prefix is missed and tenant A's cache hit serves tenant B. Always go through the helper.
- **Missing context on async entry points.** HTTP middleware sets `TenantContext` correctly, but the queue worker / cron / webhook handler forgets to call `TenantContext.run()` — downstream repos throw `TenantContextMissing` or, worse, fall back to a default. Every async entry point wraps its work in `TenantContext.run()`.
- **Cross-tenant FK.** A `share_with_tenant_id` column "for collaboration" creates queries that legitimately need to cross. Separate model (`tenant_share` join table) with explicit admin-path access.
- **Tenant id load-bearing in payload.** Event payload carries `tenantId` at top level, handler trusts it without re-establishing context. Tenant id lives in event METADATA (envelope), not payload; receiver does `TenantContext.run(metadata.tenant, () => handler(payload))`.
- **Single-column index instead of composite.** `CREATE INDEX ON products (status)` instead of `(tenant_id, status)`. Query plan ignores it once the table is large; full-scan + filter spikes p95.
- **Global unique on natural keys.** `UNIQUE (slug)` instead of `UNIQUE (tenant_id, slug)` — tenant B can't pick a slug tenant A already used. Tenant uniqueness is per-tenant unless explicitly global.

## Cross-references

- `<rules-path>/multi-tenancy.md` — hard rules + review checklist + enforcement.
- `<patterns-path>/tenant-isolation.md` — sibling pattern: row-level enforcement at the repository layer (the "how" for shared-DB).
- `<commands-path>/tenant-leak-audit.md` — grep-based scanner for the leak surfaces named here.
- `<agents-path>/tenant-isolation-reviewer.md` — review gate that hard-fails on missing leak tests + client-supplied tenant ids.
- `<adr-path>/<NNN>-multi-tenant-shared-db-row-level.md` — ADR pinning the deployment shape (shared DB / row-level vs schema-per-tenant vs DB-per-tenant).
