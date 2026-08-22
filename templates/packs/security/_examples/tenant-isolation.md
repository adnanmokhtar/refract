---
name: tenant-isolation
kind: example
pack: security
---

# Pattern: Tenant isolation (security lens)

A single missing filter = cross-tenant breach. This is the security invariant + review methodology; the impl shape lives in backend `multi-tenancy`. Question: can tenant A read/write/infer tenant B's data?

## The invariant

Every data access scoped to exactly one tenant, derived from the AUTHENTICATED context — never from client input. Holds independently at every layer (defense in depth).

## Isolation layers (verify each independently)

1. Identity — tenant from session/token/verified-webhook, never a client header/body/query.
2. Query — every read/write carries the tenant predicate via the base repo; raw SQL applies it explicitly.
3. Below the app — a second enforcement point so a forgotten predicate fails closed; engine-conditional, see § The below-app layer.
4. Cache — tenant-prefixed keys by construction.
5. Object storage / files — namespaced per tenant; signed-URL scope checked.
6. Events / queues — tenant id in metadata; consumers re-establish context.
7. Search / analytics / exports — the predicate applies to the secondary path too (common blind spot).

## The below-app layer (engine-conditional)


**Establish the engine's capability before grading.** Demanding a feature the engine lacks produces an unfixable finding on every run.

| Engine class | Mechanism | The silent failure |
|---|---|---|
| Row-policy engines (e.g. **Postgres** `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY`) | Policies filter rows per session setting | *"Table owners normally bypass row security"* unless `FORCE ROW LEVEL SECURITY`, and superusers / `BYPASSRLS` roles always bypass ([docs](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)). Connect as the owner and RLS enforces nothing — **verify the connecting role, not just the policy.** |
| No row-policy feature (e.g. **MySQL** — privileges apply at server/database/table/column/routine level, [docs](https://dev.mysql.com/doc/refman/8.4/en/privileges-provided.html)) | Substitutes: `SQL SECURITY DEFINER` view + `WITH CHECK OPTION`, which "prevent[s] inserts or updates to rows except those for which the `WHERE` clause … is true" ([CREATE VIEW](https://dev.mysql.com/doc/refman/8.4/en/create-view.html)); per-tenant DB users; database/schema per tenant | A view isolates only if the app **cannot reach the base table**; per-tenant users only if the pool re-binds per request |
| Schema-/database-per-tenant | Isolation is the connection binding | A pooled connection reused **without re-binding** crosses tenants; a row predicate cannot see it |

**Grading rule** (matches `@tenant-isolation-reviewer § Grading the below-app layer`): engine **supports** a mechanism, project does not use it → **HIGH**, naming the mechanism and the tables it covers. Engine supports **none** → **MEDIUM**, an accepted architectural limit, only with compensating controls named (auto-filter is the sole reachable query path; cross-tenant regression test in CI). Never report "no row-level security" against an engine that has no such feature.

## What a leak actually looks like

**1. The query that left the scoped path** — a raw/builder call around the scoped repo: `db.query("SELECT * FROM invoices WHERE id = ?")`. The write twin (`UPDATE … WHERE id=?`) is an IDOR that mutates. Fix: scoped repo, or explicit predicate **plus** an affected-rows assert (0 rows ⇒ 404). Hides in exports, admin tooling, JOINs whose other side is unscoped, and subqueries.

**2. The cache key without the tenant** — a key built from the resource id alone (`cache.set("invoice:" + id, …)`) after a correctly scoped query. Fix: one `buildKey(tenantId, …)` helper; concatenation is the defect. Variants that pass review: in-process memo/LRU, an invalidation path deleting an unprefixed key, and derived caches (aggregates, rendered fragments, rate-limit counters).

**3. The background job that lost its tenant** — context exists at enqueue, gone in the worker. The danger is not the crash but the **fallback**: "no tenant" resolving to everything, or to the last tenant processed. Fix: tenant id in the job envelope, consumer re-enters context, absent tenant throws. Same shape in schedules, retries, DLQ replays, webhook consumers, SSE handlers.

**Fail closed everywhere** — a resolver returning "all tenants" on empty context turns each of these into full-table disclosure.

## Review methodology

Assume-breach probe (tenant A's user + tenant B's resource id → 404/403 or leak?), **on write verbs too**. Grep escape hatches (`skipTenantScope`). **Enumerate tables from the schema, not the code** — a table added with no tenant column is the finding before any query exists. Mandatory cross-tenant leak test per repo.

## Detectors (cite-or-halt)

1. Tenant from client input (header/body/query).
2. Query bypassing the base-repo scope — including the write-path twin.
3. Cache/storage key without the tenant prefix — including memos, invalidation, derived caches.
4. Unaudited `skipTenantScope` bypass (BLOCKER until justified).
5. Cross-tenant IDOR/BOLA (object by id, no ownership check).
6. Isolation missing on the search/export/analytics path.
7. Context lost across an async boundary, or a resolver that falls back instead of failing closed.
8. Below-app layer claimed but inert (policy the connecting role bypasses, view whose base table is granted, pool not re-bound) — worse than no layer 3, because it is counted as one.

## Related

`@tenant-isolation-reviewer`, backend `multi-tenancy.md` (impl + topology table), `security-principles.md`, database pack (the engine's own layer-3 reference).
