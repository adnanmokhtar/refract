---
name: multi-tenancy
kind: pattern
pack: backend
---

# Pattern: Multi-Tenancy (request-scoped tenant context)

Every request carries a tenant identity through every layer — resolution → context → data filter → cache → events. A single leak is a security incident, not a bug. This pattern mirrors the project's own tenant primitive; adapt the names to what the codebase already uses.

## Overview

The tenant is resolved **once** at the edge, stored in a request-scoped context, and read (never re-passed) everywhere downstream. Data access, cache keys, and events are tenant-scoped by construction so a developer cannot forget to filter.

## Resolution chain

Resolve tenant identity at the edge, first match wins (order is project-specific — mirror the existing resolver):

1. **Host / domain** — `Host` header → tenant record by domain.
2. **Path prefix** — `/{tenantSlug}/…` or a landing-product segment.
3. **Explicit header** — an admin/portal header (e.g. `X-Tenant-Id`) for internal callers.
4. **API key** — server-to-server callers resolve tenant from the key.
5. **Signed webhook payload** — the provider event's account/resource id maps to a tenant (see `webhook-flow.md`).

Resolution lives in ONE place — a `TenantResolutionMiddleware` (REST) or a dedicated resolver — and stores the tenant in a request-scoped store (`AsyncLocalStorage` / `contextvars` / `Context` / thread-local, per stack).

## Context propagation

```ts
// Read anywhere downstream — services, repos, mappers, jobs.
const { tenantId } = TenantContext.get();
```

- **NEVER** accept `tenantId` as a function argument passed down from a controller — it invites a caller passing the wrong one.
- **NEVER** read it from request body / params / query — those are attacker-controlled.
- Background jobs / queue consumers re-enter the context: `TenantContext.run(job.tenantId, () => handle(job))`.

## Automatic filtering (data layer)

Every repository is tenant-scoped by default — the base class injects the filter so an individual query cannot forget it:

```ts
protected scope<Q extends SelectQueryBuilder<T>>(qb: Q): Q {
  return qb.andWhere(`${qb.alias}.tenant_id = :tenantId`,
    { tenantId: TenantContext.get().tenantId });
}
```

- Raw SQL applies the tenant predicate **explicitly** — no exceptions.
- Row-Level Security (Postgres `RLS` with a per-request `SET app.tenant_id`) is the stronger belt-and-suspenders where the DB supports it.
- **Cache keys** are tenant-prefixed by construction: `tenant:<id>:<namespace>:<key>` via a `buildKey()` helper — never string-concatenated ad hoc.

## Manual bypass rules

- A `skipTenantScope` / `skipTenantPrefix` escape hatch exists ONLY for genuinely global data (countries, currencies, static enums, platform config).
- Every use carries a code-comment justification referencing this pattern. Any bypass in a review is a BLOCKER until justified.
- Cross-tenant admin/reporting reads go through a separate, explicitly-audited path — never the normal repository with the scope disabled inline.

## Events / async

- The tenant id lives in **event metadata**, never the payload; payloads carry ids, not cross-tenant data.
- Receivers re-establish context: `TenantContext.run(metadata.tenantId, () => handler(payload))`.

## Testing isolation

Every tenant-scoped repository ships a cross-tenant leak test — this is the test that catches the incident:

```ts
it('does not return tenant B rows to tenant A', async () => {
  await seed({ tenantId: 'A' /* … */ });
  await seed({ tenantId: 'B' /* … */ });
  const rows = await TenantContext.run({ tenantId: 'A' }, () => repo.findAll());
  expect(rows.every(r => r.tenantId === 'A')).toBe(true);
});
```

## Pitfalls

- `tenantId` sourced from request body / query / a client header that isn't the authenticated resolution input — always from the resolved context.
- Raw SQL or a query builder that bypasses the base scope.
- Cache keys built by string concat (miss the prefix → cross-tenant cache hit).
- Cross-tenant foreign keys / a join that crosses the tenant boundary.
- Background job or webhook handler that runs outside `TenantContext.run(...)` → context-less query → leak or crash.
- A `skipTenantScope` with no justifying comment.

## Related

- `debug-tenant` skill — diagnoses a suspected cross-tenant leak.
- `webhook-flow.md` — webhook resolution feeds the resolution chain.
- Deeper authz / tenant-isolation enforcement is owned by the **security** pack (`security-principles` data-layer tenant filter).
