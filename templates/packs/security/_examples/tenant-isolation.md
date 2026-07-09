---
name: tenant-isolation
kind: example
pack: security
---

# Pattern: Tenant isolation (security lens)

A single missing filter = cross-tenant breach. This is the security invariant + review methodology; the impl shape lives in backend `multi-tenancy`. Question: can tenant A read/write/infer tenant B's data?

## Invariant

Every data access scoped to exactly one tenant, derived from the AUTHENTICATED context — never from client input. Holds independently at every layer (defense in depth).

## Isolation layers

1. Identity — tenant from session/token/verified-webhook, never a client header/body/query.
2. Query — every read/write carries the tenant predicate via the base repo; raw SQL applies it explicitly.
3. RLS — Postgres row-level security (per-request SET) as belt-and-suspenders (fails closed).
4. Cache — tenant-prefixed keys by construction.
5. Object storage / files — namespaced per tenant; signed-URL scope checked.
6. Events / queues — tenant id in metadata; consumers re-establish context.
7. Search / analytics / exports — the predicate applies to the secondary path too (common blind spot).

## Review methodology

Assume-breach probe (tenant A's user + tenant B's resource id → 404/403 or leak?). Grep escape hatches (`skipTenantScope`). Mandatory cross-tenant leak test per repo.

## Detectors (cite-or-halt)

1. Tenant from client input (header/body/query).
2. Query bypassing the base-repo tenant scope.
3. Cache/storage key without the tenant prefix.
4. Unaudited `skipTenantScope` bypass (BLOCKER until justified).
5. Cross-tenant IDOR/BOLA (object by id, no ownership check).
6. Isolation missing on the search/export/analytics path.

## Related

`@tenant-isolation-reviewer`, backend `multi-tenancy.md` (impl), `security-principles.md`, database pack (RLS).
