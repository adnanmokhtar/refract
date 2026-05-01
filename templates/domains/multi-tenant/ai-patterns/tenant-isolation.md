---
name: tenant-isolation
description: Pattern: Tenant isolation (shared-DB, row-level)
kind: ai-pattern
---

# Pattern: Tenant isolation (shared-DB, row-level)

> **Hard rule** — Every tenant-scoped table has `tenant_id NOT NULL`; every repo method on it filters by `tenant_id` from `TenantContext`, never from a DTO. Cross-tenant access lives in a separately-named `*.admin-repository.ts` with restricted DI binding.

**When to apply**
- Shared-DB SaaS where tenants share schemas/tables but never see each other's rows.
- Webhooks where the tenant is resolved from a provider identifier (e.g. `phone_number_id` → `tenants`).
- Background workers acting on tenant-scoped rows — wrap the work in `TenantContext.run()`.

**When NOT to apply**
- Per-tenant DB / per-tenant schema deployments — isolation is at infra, not row level (different pattern).
- Genuinely tenant-agnostic tables (system config, public catalogs) — keep them out of the scoped repo base class.
- Admin/ops paths that must aggregate across tenants — explicit admin repo, never a "convenient" override on the scoped repo.

**Halt conditions / mandatory cites**
- Cite the `TenantScopedRepository` base class + the `andWhere('tenant_id = :tenantId')` injection at `<path:line>`. Per-method filters with copy-paste = halt.
- Cite a per-repo cross-tenant leak test (`spec.ts`) at `<path:line>`. No test = halt.
- Cite composite indexes `(tenant_id, <filter>)` in migrations at `<path:line>` for every list query. Single-column indexes = halt.
- Cite the schema `FOREIGN KEY ... REFERENCES tenants(id) ON DELETE CASCADE` at `<path:line>`. Missing FK = orphan-row risk on tenant deletion.
- Grep ban: any `tenantId` originating from `req.body` / `req.query` / `req.params` in feature code — show the file:line and refuse.

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
- Per-method copy-pasted `andWhere('tenant_id = :tenantId')`. One missed copy = one leak. Inject in the base class once.
- Schema migration adds a tenant-scoped table with `tenant_id` nullable / no FK / no composite index. Required: `tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE` + `(tenant_id, <filter_column>)` composite index per list-query shape.
- Soft delete that ignores tenant. `WHERE deleted_at IS NULL` without `tenant_id = :tenantId` — listed deletes leak. Same rule applies to deletes as to selects.

## Cross-references

- `<rules-path>/multi-tenancy.md` — hard rules + review checklist + enforcement.
- `<patterns-path>/multi-tenancy.md` — sibling pattern: request-scoped tenant context + resolution chain (the "where the tenantId comes from").
- `<commands-path>/tenant-leak-audit.md` — grep + AST scanner for missing filters, client-supplied tenant ids, missing leak tests.
- `<agents-path>/tenant-isolation-reviewer.md` — review gate hard-failing on missing tests + raw-SQL leaks.
- `<adr-path>/<NNN>-multi-tenant-shared-db-row-level.md` — ADR pinning shared-DB row-level isolation as the deployment shape.
