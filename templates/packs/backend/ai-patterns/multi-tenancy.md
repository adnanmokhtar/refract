---
name: multi-tenancy
kind: pattern
pack: backend
---

# Pattern: Multi-Tenancy (request-scoped tenant context)

Every request carries a tenant identity through every layer — resolution → context → data filter → cache → events. A single leak is a security incident, not a bug. This pattern mirrors the project's own tenant primitive; adapt the names to what the codebase already uses.

## Overview

The tenant is resolved **once** at the edge, stored in a request-scoped context, and read (never re-passed) everywhere downstream. Data access, cache keys, and events are tenant-scoped by construction so a developer cannot forget to filter.

**When NOT to apply — this pattern assumes ONE topology, and it is not the only one.** Everything below is written for **shared-schema, row-scoped** multi-tenancy: every tenant's rows sit in the same tables, and a `tenant_id` predicate is what separates them. That assumption is load-bearing, and cargo-culting it into a codebase built the other way produces a filter that is at best redundant and at worst a second, weaker isolation mechanism sitting where the real one already is.

| Topology | Where isolation actually lives | What this pattern still owns |
|---|---|---|
| **Shared schema, `tenant_id` column** | The row predicate. This pattern, end to end. | All of it. |
| **Schema-per-tenant** (one PG schema / MySQL database per tenant) | The `search_path` / database selected at connection checkout. A row predicate adds nothing — every row in reach already belongs to the tenant. | Resolution chain, context propagation, cache-key prefixing, event metadata, `TenantContext.run` in consumers. **Not** § Automatic filtering: the detector for a missing predicate is a false positive here, and the real detector is *"a connection checked out without the tenant's schema bound"*. |
| **Database-per-tenant** | Connection routing — which DSN the pool hands you. | Same as above, plus one failure this pattern does not otherwise name: a **connection leaked across tenants** by a pooler that reuses a connection without re-binding. Row filters cannot see it and will report clean. |
| **Platform-global tables** (countries, currencies, plans, feature flags, the tenant registry itself) | Nothing. They are not tenant data. | Nothing — this is what § Manual bypass rules exists for. A `tenant_id` on a currency table is a modelling error, not a security control. |

**State the topology before applying any detector below.** A finding that does not know which row of this table the codebase is in cannot know whether the thing it flagged is a bug. On a schema-per-tenant codebase, detectors 2 and 5 must be re-aimed at connection binding and cache-key prefixing respectively, or they produce noise on every query in the repo — which is how a security scan gets muted.

## Resolution chain

Resolve tenant identity at the edge, first match wins (order is project-specific — mirror the existing resolver):

1. **Host / domain** — `Host` header → tenant record by domain.
2. **Path prefix** — `/{tenantSlug}/…` or a landing-product segment.
3. **Impersonation claim** — a support/admin caller acting on a tenant's behalf. The tenant id is read from the **authenticated principal's** `act`/impersonation claim, never from a bare request header. A plain `X-Tenant-Id` from the network is attacker-controlled and MUST NOT be a resolution input on any internet-reachable route (`backend-principles` lists trusting it under **Must not**). If a header carries it at all, the request must have arrived over mTLS from a named internal peer, the authenticated principal must hold a `tenant:impersonate` claim, and every use is audit-logged with both identities.
4. **API key** — server-to-server callers resolve tenant from the key.
5. **Signed webhook payload** — the provider event's account/resource id maps to a tenant (see `webhook-flow.md`).

Resolution lives in ONE place — a `TenantResolutionMiddleware` (REST) or a dedicated resolver — and stores the tenant in a request-scoped store (`AsyncLocalStorage` / `contextvars` / `Context` / thread-local, per stack).

## Context propagation

```ts
// Read anywhere downstream — services, repos, mappers, jobs.
const { tenantId } = TenantContext.get();
```

- **Ambient reads are confined to the data layer.** The repository base class (and only it) reads `TenantContext.get()`; that is one file, reviewable, and the place the filter is applied by construction.
- **A service MAY take an explicit tenant scope at its own boundary** when that makes it testable — `placeOrder(scope: TenantScope, dto)` where `scope` was produced by the resolver, not by the caller inventing one. What is forbidden is a **controller reading a client-supplied value and passing it down**: that re-opens the attacker-controlled path the resolution chain exists to close.
  This is the honest reconciliation with `backend-principles`' DI rule ("service classes receive collaborators as constructor args, not import-and-call singletons"). `TenantContext.get()` scattered through domain services *is* the named anti-pattern — it makes every service untestable without an ambient wrapper. Push the ambient read down to the repository base; let services above it take the scope explicitly or receive a context-bound repository. Either shape satisfies both rules; a domain service calling a global getter satisfies neither.
- **NEVER** read it from request body / params / query / a bare request header — all four are attacker-controlled. The resolved context is the only source.
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

## Related

- `debug-tenant` skill — diagnoses a suspected cross-tenant leak.
- `webhook-flow.md` — webhook resolution feeds the resolution chain.
- Deeper authz / tenant-isolation enforcement is owned by the **security** pack (`security-principles` data-layer tenant filter).
