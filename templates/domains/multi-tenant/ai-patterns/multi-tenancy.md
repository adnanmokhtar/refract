# Pattern: Multi-Tenancy (Request-Scoped Context)

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
