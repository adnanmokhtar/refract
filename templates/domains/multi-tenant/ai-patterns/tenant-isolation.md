---
name: tenant-isolation
description: Pattern: Tenant isolation (shared-DB, row-level)
kind: ai-pattern
---

# Pattern: Tenant isolation (shared-DB, row-level)

## Decision summary

Every tenant-scoped table has `tenant_id uuid NOT NULL`. Every query filters by it. The filter is enforced at the **repository layer**, never trusted from controllers.

See ADR `0002-multi-tenant-shared-db-row-level.md`.

## How `tenant_id` is carried

We use Node's `AsyncLocalStorage` via a `TenantContext` service. The webhook guard/controller resolves the tenant from `phone_number_id`, then:

```ts
await tenantContext.run({ tenantId }, async () => {
  return this.handleIncomingMessageUseCase.execute(input);
});
```

Everything inside the callback — repos, use-cases, Claude client logging — can call `tenantContext.getTenantId()` and get the right value.

## Repository rule (HARD)

Every tenant-scoped repository method:

1. Accepts `tenantId` as the first parameter, OR pulls it from `TenantContext` and throws `TenantContextMissingError` if absent.
2. Adds `WHERE tenant_id = :tenantId` on every SELECT/UPDATE/DELETE. No exceptions.
3. Sets `tenant_id` on every INSERT from context — never from a DTO.

Forbidden: any method on a tenant-scoped repo that omits `tenant_id`. If you need cross-tenant access (admin/ops), put it in a separate `*.admin-repository.ts` with explicit naming and restricted injection.

```ts
// GOOD
async listActive(tenantId: TenantId): Promise<Product[]> {
  return this.orm.find({ where: { tenantId: tenantId.value, isActive: true } });
}

// FORBIDDEN — a leak waiting to happen
async listActive(): Promise<Product[]> {
  return this.orm.find({ where: { isActive: true } });
}
```

## Schema rules

- `tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE` on every tenant-scoped table.
- Composite index `(tenant_id, <filter_column>)` on every list query shape.
- Unique constraints within a tenant: `UNIQUE (tenant_id, natural_key)` — never global unique on natural keys.

## Tests (required)

For every new tenant-scoped repo, add to its `.spec.ts`:

```ts
it('filters by tenant_id — does not return other tenants rows', async () => {
  const t1 = await seedTenant();
  const t2 = await seedTenant();
  await seedProduct(t1, 'A');
  await seedProduct(t2, 'B');

  const result = await repo.listActive(t1.id);
  expect(result).toHaveLength(1);
  expect(result[0].name).toBe('A');
});
```

## Phase progression

- **P1:** shared-DB, `tenant_id` filter, app-layer enforcement.
- **P3:** consider enabling Postgres Row-Level Security (RLS) as a belt-and-braces layer. Keep app-layer filters even with RLS on.
- **Never (for this product):** per-tenant schemas or per-tenant databases. Cost + ops overhead don't justify it at our expected scale.

## Anti-patterns

- Taking `tenantId` from a controller DTO / query param / header. **Never.** The server decides tenant, not the client.
- A "convenient" repo method that skips the filter for "internal" use. Make a separate admin repo.
- Joining across tenants "just this once". Write a new query with explicit `IN (:...tenantIds)` and code-review it.
- Relying on RLS instead of app-layer filters. Defense in depth — run both.
