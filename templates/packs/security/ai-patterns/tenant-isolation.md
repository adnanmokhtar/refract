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
3. **Below the app (engine-conditional)** — a second enforcement point beneath the application, so a forgotten predicate fails closed. See § The below-app layer; it exists only if the engine can enforce it.
4. **Cache** — keys are tenant-prefixed by construction (`tenant:<id>:…`); a string-concatenated key that omits the prefix is a cross-tenant cache hit.
5. **Object storage / files** — paths/buckets namespaced per tenant; signed-URL scope checked.
6. **Events / queues** — tenant id in metadata (not payload); consumers re-establish tenant context before handling.
7. **Search / analytics / exports** — the isolation predicate applies to the index and the report path too (a common blind spot — the primary query is scoped but the search mirror isn't).

## The below-app layer (engine-conditional)


**Establish the engine's capability before you grade this layer.** A second enforcement layer below the app is worth having, but demanding one from an engine that has no such feature produces an unfixable finding on every run — which is how a real reviewer gets muted.

| Engine class | The mechanism | The silent failure that makes it decorative |
|---|---|---|
| Row-policy engines (e.g. **Postgres** `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + `CREATE POLICY`) | Policies filter rows per session setting | **"Table owners normally bypass row security"** unless the table is set to `FORCE ROW LEVEL SECURITY`, and *"Superusers and roles with the `BYPASSRLS` attribute always bypass the row security system"* ([PG docs](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)). An app that connects as the table owner has RLS enabled and enforcing nothing. **Verify the connecting role, not just the policy.** |
| Engines with no row-policy feature (e.g. **MySQL**, whose privileges apply at server / database / table / column / routine level — [privileges reference](https://dev.mysql.com/doc/refman/8.4/en/privileges-provided.html)) | The substitutes: a definer's-rights view (`SQL SECURITY DEFINER` … `WITH CHECK OPTION`, which *"prevent[s] inserts or updates to rows except those for which the `WHERE` clause … is true"* — [CREATE VIEW](https://dev.mysql.com/doc/refman/8.4/en/create-view.html)); per-tenant DB users with scoped grants; or a database/schema per tenant | A view only isolates if the app **cannot reach the base table** — one grant on the underlying table and the view is advisory. Per-tenant users only isolate if the pool actually re-binds the credential per request. |
| Schema- or database-per-tenant (any engine) | Isolation is the connection: which schema/database the checkout is bound to | A pooled connection **reused without re-binding** crosses tenants, and a row predicate cannot see it. The detector here is *"a checkout that did not re-bind"*, not *"a query without a filter"*. |

**Grading rule** (matches `@tenant-isolation-reviewer § Grading the below-app layer` — do not diverge from it):

- Engine **supports** a mechanism and the project does not use it → **HIGH**, naming the specific mechanism and the tables it would cover.
- Engine supports **none** of them → **MEDIUM**, recorded as an accepted architectural limit, and only with the compensating controls named: the auto-filter is the *only* query path reachable from request handlers, plus a cross-tenant regression test in CI.

Never report "no row-level security" as an unfixable finding against an engine that has no such feature — that row is a capability statement, and it belongs in the report as one.

## What a leak actually looks like

Three shapes, in descending order of how often they ship. Mirror the project's own primitive names; the shapes are what matters.

**1. The query that left the scoped path.** The base repository applies the predicate; this call does not go through it.

```
// LEAK — a raw/builder path around the scoped repo
rows = db.query("SELECT * FROM invoices WHERE id = ?", [id])        // no tenant predicate
// and the subtler write-path twin, which is an IDOR that mutates:
db.query("UPDATE invoices SET status=? WHERE id=?", [s, id])        // updates ANY tenant's row
// FIX: go through the scoped repo, or apply the predicate explicitly AND assert affected-rows
//      ... WHERE id = ? AND tenant_id = ?   → 0 rows affected means "not yours", return 404
```
Where it hides: reporting/export queries, admin tooling, "just one quick count", `JOIN`s whose *other* side is unscoped, and any subquery — the outer query's predicate does not reach inside it.

**2. The cache key without the tenant.** The query was scoped; the memo of it was not.

```
// LEAK — key derived from the resource id only
cache.set(`invoice:${id}`, invoice)        // tenant B reads tenant A's cached row
// FIX — prefix by construction, never by convention:
key = buildKey(tenantId, 'invoice', id)    // one helper; ad-hoc concatenation is the defect
```
Three variants that pass a naive review: an **in-process** memo/LRU (never touches the cache helper at all), an **invalidation** path that deletes an unprefixed key while writes use a prefixed one (stale cross-tenant data survives), and a **derived** cache — a computed aggregate, a rendered fragment, a rate-limit counter — keyed only by user or resource id.

**3. The background job that lost its tenant.** Context exists at enqueue time and is gone at execution time.

```
// LEAK — context read at enqueue, never carried
queue.push({ type: 'report', invoiceId: id })
// worker, minutes later, in a different process:
handle(job) { rows = repo.findAll() }      // TenantContext is EMPTY here
```
The dangerous outcome is not the crash — it is the **fallback**: a resolver that defaults to "no tenant" (returns everything), to the first/last tenant, or to whichever tenant the worker last processed. Same shape in scheduled jobs, retries, dead-letter replays, webhook consumers, and streaming/SSE handlers that outlive the request that opened them.

```
// FIX — tenant id travels in the envelope, and the consumer re-enters context before handling
queue.push({ tenant: tenantId, type: 'report', invoiceId: id })
handle(job) { runWithTenant(job.tenant, () => …) }   // and fail closed if job.tenant is absent
```

**Fail closed everywhere.** A resolver that returns "all tenants" when the context is empty converts every one of these bugs into a full-table disclosure. Absent context must throw.

## Review methodology

- **Assume-breach probe**: for each resource, construct the request "tenant A's user, tenant B's resource id" — does it 404/403, or leak? IDOR/BOLA on a tenant-owned object is a cross-tenant breach. Run it on the **write** verbs too; a cross-tenant `UPDATE`/`DELETE` is the same bug with worse consequences.
- **Grep the escape hatches**: any `skipTenantScope` / `bypassTenant` / raw query / admin cross-tenant path — each needs an explicit, audited justification.
- **Enumerate the tables, not the code.** Ask the schema which tables carry the tenant column and diff that against the tables the app writes; a table added since the last review with no tenant column is the finding *before* any query exists. (Engines expose this through their information-schema/catalog views.)
- **The cross-tenant leak test is mandatory** per repository (seed A + B, query as A, assert zero B rows).

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix.

1. **Tenant from client input** — `tenantId` read from header/body/query rather than the resolved context. `report-with-fix`.
2. **Query without the tenant predicate** — a raw query / query-builder path that bypasses the base repo scope, including the write-path twin. `report-with-fix`.
3. **Cache/storage key without the tenant prefix** — including in-process memos, invalidation paths, and derived caches. `report-with-fix`.
4. **Unaudited bypass** — `skipTenantScope`-style escape hatch with no justifying comment. `report-flagged` (BLOCKER until justified).
5. **Cross-tenant IDOR/BOLA** — an object endpoint that resolves by id with no ownership/tenant check. `report-with-fix`.
6. **Isolation missing on the secondary path** — search index / export / analytics that doesn't apply the predicate the primary query does. `report-flagged`.
7. **Context lost across an async boundary** — job/consumer/scheduled task that reads tenant-scoped data without re-entering the context, or a resolver that falls back instead of failing closed. `report-with-fix`.
8. **Below-app layer claimed but inert** — a row policy that the connecting role bypasses, a view whose base table is still granted, or a pooled connection not re-bound per tenant. `report-flagged` — this is worse than no second layer, because it is counted as one.

Closure verbs: `report-with-fix` / `report-flagged` (design/audit call) / `dismiss` (genuinely global data — countries, currencies — documented).

## Related

- `@tenant-isolation-reviewer` — the deep reviewer this pattern backs.
- `backend/ai-patterns/multi-tenancy.md` — the implementation shape (request-scoped context, base-repo scoping, isolation tests) and the topology table that decides which detectors apply.
- `rules/security-principles.md` — the authz-after-authn + no-header-trust MUSTs.
- `database` pack — the engine's own reference for whatever layer 3 it can offer.
