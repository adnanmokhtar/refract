---
name: multi-tenancy
kind: example
pack: backend
---

# Pattern: Multi-Tenancy (Request-Scoped Context)

Each request carries tenant identity through every layer. A single leak = security incident.

**When NOT to apply — this pattern assumes ONE topology.** Everything here is written for **shared-schema, row-scoped** multi-tenancy, where a `tenant_id` predicate is what separates tenants. Cargo-culting it into a codebase built the other way produces a filter that is at best redundant and at worst a second, weaker isolation mechanism sitting where the real one already is.

| Topology | Where isolation actually lives | What this pattern still owns |
|---|---|---|
| Shared schema, `tenant_id` column | the row predicate | all of it |
| Schema-per-tenant | the `search_path` / database bound at connection checkout | resolution, context propagation, cache keys, event metadata, `TenantContext.run` in consumers. **Not** the row-predicate detector — it is a false positive here; the real detector is *a connection checked out without the tenant's schema bound* |
| Database-per-tenant | connection routing (which DSN the pool hands you) | as above, plus a failure nothing else names: a **connection leaked across tenants** by a pooler that reuses one without re-binding. Row filters cannot see it and report clean |
| Platform-global tables (countries, plans, the tenant registry) | nothing — they are not tenant data | nothing; this is what the bypass rules exist for. A `tenant_id` on a currency table is a modelling error, not a control |

**State the topology before applying any detector below.** A finding that does not know which row it is in cannot know whether the thing it flagged is a bug — and on a schema-per-tenant codebase the query detector fires on every query in the repo, which is how a security scan gets muted.

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

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the rule above it violates. "Tenant isolation looks weak" without a cited query / key / handler is not a finding. Every detector below is derived from a rule already stated in this file — none invents new doctrine.

### 1. Tenant id sourced from the request

A handler reading `tenantId` from body / query / route param, or from a bare header on an internet-reachable route, and using it as the *resolution* input rather than the resolved context → cite the read site → `resolve-from-context`.

### 2. Tenant-scoped query with no tenant predicate

A data-layer query against a table carrying `tenant_id` that neither goes through the scoped base class nor states the predicate explicitly, and carries no documented bypass → cite the query → `scope-the-query`.

### 3. Undocumented bypass

A `skipTenantScope` / `skipTenantPrefix` / raw-SQL escape hatch with no justifying comment naming the global data it reads (§Manual bypass rules) → cite the bypass site → `justify-or-remove-bypass`. **A bypass in review is a BLOCKER until justified** — this detector never downgrades to a nit.

### 4. Async handler that never re-establishes context

A queue consumer / job handler / webhook handler whose entry point does not wrap the work in `TenantContext.run(...)` from the job or event **metadata** (§Events) → cite the handler → `rebind-tenant-context`. This is the one that fails silently in dev (single-tenant seed data) and leaks in prod.

### 5. Cache key with no tenant segment

A cache `get`/`set` on tenant-scoped data whose key is built without the tenant prefix — typically string concatenation that bypasses `buildKey()` → cite the key construction → `prefix-cache-key`.

### 6. Cross-tenant join or FK  `[self-policed]`

A join or foreign key that crosses the tenant boundary. grep cannot decide this from a query alone — it needs the schema's tenant ownership map. Mark `[self-policed]`: the reviewer asserts it was checked, or the finding is not emittable. (Same precedent as `api-reviewer`'s TXN row — a detector that cannot be mechanised says so rather than pretending.)

**Closure verbs:** `resolve-from-context`, `scope-the-query`, `justify-or-remove-bypass`, `rebind-tenant-context`, `prefix-cache-key`.
