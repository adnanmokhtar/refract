---
name: tenant-isolation
kind: pattern
pack: security
---

# Pattern: Tenant isolation (security lens)

In a multi-tenant system, a single missing filter is not a bug — it is a cross-tenant data-breach. This pattern is the **security invariant + review methodology** for tenant isolation; the *implementation shape* (request-scoped context, base-repo scoping) lives in the backend pack's `multi-tenancy` pattern. Here the question is only: **can tenant A ever read, write, or infer tenant B's data?**

## The invariant

**Every data access is scoped to exactly one tenant, derived from the authenticated context — never from client input.** Isolation must hold at every layer independently (defense in depth), so a miss at one layer is caught by the next.

## Isolation layers (verify each independently)

1. **Identity** — tenant resolved from the authenticated session / token / verified webhook, NEVER from a request header/body/query the client controls (`X-Tenant-Id` from the public internet is an attack, not an input).
2. **Query** — every read/write carries a `tenant_id` predicate, enforced by the base repository so an individual query cannot forget it. Raw SQL applies it explicitly.
3. **Row-Level Security (belt-and-suspenders)** — where the DB supports it (Postgres RLS with a per-request `SET app.tenant_id`), so even a forgotten predicate fails closed.
4. **Cache** — keys are tenant-prefixed by construction (`tenant:<id>:…`); a string-concatenated key that omits the prefix is a cross-tenant cache hit.
5. **Object storage / files** — paths/buckets namespaced per tenant; signed-URL scope checked.
6. **Events / queues** — tenant id in metadata (not payload); consumers re-establish tenant context before handling.
7. **Search / analytics / exports** — the isolation predicate applies to the index and the report path too (a common blind spot — the primary query is scoped but the search mirror isn't).

## Review methodology

- **Assume-breach probe**: for each resource, construct the request "tenant A's user, tenant B's resource id" — does it 404/403, or leak? IDOR/BOLA on a tenant-owned object is a cross-tenant breach.
- **Grep the escape hatches**: any `skipTenantScope` / `bypassTenant` / raw query / admin cross-tenant path — each needs an explicit, audited justification.
- **The cross-tenant leak test is mandatory** per repository (seed A + B, query as A, assert zero B rows).

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix.

1. **Tenant from client input** — `tenantId` read from header/body/query rather than the resolved context. `report-with-fix`.
2. **Query without the tenant predicate** — a raw query / query-builder path that bypasses the base repo scope. `report-with-fix`.
3. **Cache/storage key without the tenant prefix** — string-concatenated key or shared path. `report-with-fix`.
4. **Unaudited bypass** — `skipTenantScope`-style escape hatch with no justifying comment. `report-flagged` (BLOCKER until justified).
5. **Cross-tenant IDOR/BOLA** — an object endpoint that resolves by id with no ownership/tenant check. `report-with-fix`.
6. **Isolation missing on the secondary path** — search index / export / analytics that doesn't apply the predicate the primary query does. `report-flagged`.

Closure verbs: `report-with-fix` / `report-flagged` (design/audit call) / `dismiss` (genuinely global data — countries, currencies — documented).

## Related

- `@tenant-isolation-reviewer` — the deep reviewer this pattern backs.
- `backend/ai-patterns/multi-tenancy.md` — the implementation shape (request-scoped context, base-repo scoping, isolation tests).
- `rules/security-principles.md` — the authz-after-authn + no-header-trust MUSTs.
- `database` pack — Row-Level Security setup.
