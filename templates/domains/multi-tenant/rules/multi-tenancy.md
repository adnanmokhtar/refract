---
name: multi-tenancy
description: Multi-tenancy rules
kind: rule
---

# Multi-tenancy rules

## Hard rule

This project is shared-DB, row-level multi-tenant. Every tenant-scoped table has `tenant_id NOT NULL`; every repo filters by `tenant_id` resolved from `<tenant-context>` (NEVER from a DTO / query / header / payload); cross-tenant access lives in separately-named admin repos with restricted DI binding; every tenant-scoped repo ships an explicit isolation test. A single leak = security incident.

See `<adr-path>/<NNN>-multi-tenant-shared-db-row-level.md` and `<patterns-path>/tenant-isolation.md`.

## Must

1. **Every tenant-scoped table has `tenant_id <uuid|bigint> NOT NULL REFERENCES tenants(id) ON DELETE CASCADE`.** New migrations adding a tenant-scoped table without it are rejected in review.
2. **Every tenant-scoped repo method filters by `tenant_id`** — accepted as a parameter or pulled from `<tenant-context>`. A method that omits it is a bug.
3. **`tenant_id` comes from the server, never from the client.** No DTO field, query param, header, or payload sets it. Ever.
4. **Cross-tenant access lives in separate `*.admin-repository.<ext>` files** with explicit naming, so audits can grep for it. Restricted DI binding — feature modules cannot inject admin repos.
5. **Every new tenant-scoped repo has an isolation test** (e.g. `it('filters by tenant_id — does not return other tenants rows')`). CI fails on a tenant-scoped repo without one.
6. **Unique constraints are `(tenant_id, <natural_key>)`**, never global on the natural key. Tenant uniqueness is per-tenant by default.
7. **Composite indexes lead with `tenant_id`** — `(tenant_id, <filter_column>)` for every list-query shape. Single-column indexes on filter columns are rejected.
8. **Async entry points (queue workers, crons, webhook handlers) wrap work in `<tenant-context>.run({ tenantId }, () => ...)`** — context never propagates implicitly across the queue boundary.
9. **Cache + search keys are tenant-prefixed via the project's helper** (`buildKey(...)` / equivalent). String-concat keys for tenant data are rejected.

## Must not

- Hardcode tenant IDs in feature code.
- Read `tenant_id` from `req.body` / `req.query` / `req.params` / `req.headers` / event payload top-level fields.
- Add a foreign key that joins across tenants (`shared_with_tenant_id`). Use a separate join table with explicit admin-path access.
- Write raw SQL on a tenant-scoped table without an explicit `WHERE tenant_id = :tenantId`.
- Add a "convenience" method on a tenant-scoped repo that skips the filter "for internal use".
- Rely on database RLS (Row-Level Security) instead of app-layer filters. RLS may run alongside app-layer filters as defence in depth, never as a substitute.
- Persist a tenant id load-bearing in event payload top-level — tenant id lives in event metadata (envelope) so receivers re-establish context, never trust the body.

## Should

- Run `<tenant-context>` via the platform's async-local primitive (`AsyncLocalStorage` / `context.Context` / `ThreadLocal` / coroutine-local) so every layer downstream of the resolver reads the same value.
- Resolve tenant via a single chain (domain / path / API key / signed payload — see the pattern doc) and document the precedence order. First match wins.
- Keep truly-global tables (countries, currencies, system enums) out of the tenant-scoped repo base class so accidental tenant filters on them don't surprise.
- Add `EXPLAIN ANALYZE` on the top-N list queries against prod-sized data; index hints kick in only when `tenant_id` leads.
- Consider Postgres RLS as belt-and-braces ONCE app-layer filters are stable — never as the first line.

## Review checklist (PRs touching data access / migrations)

- [ ] New tables include `tenant_id NOT NULL` + FK to `tenants(id) ON DELETE CASCADE` + composite index.
- [ ] New repo methods take `tenantId` or pull from `<tenant-context>`.
- [ ] Raw SQL (if any) includes `WHERE tenant_id = $n` and is reviewed line-by-line.
- [ ] Every new tenant-scoped repo has an isolation spec asserting another tenant's rows are filtered out.
- [ ] No new path reads `tenant_id` from a DTO / query / params / headers.
- [ ] New unique constraints are `(tenant_id, ...)`, not global.
- [ ] New cache / search keys go through the tenant-prefix helper.
- [ ] Any cross-tenant access is in `*.admin-repository.<ext>` with restricted injection.
- [ ] Async entry points (workers / crons / webhooks) wrap work in `<tenant-context>.run(...)`.

## Anti-patterns

- **Client-supplied tenant id** — `req.headers['x-tenant-id']` / `req.body.tenantId`. Server decides tenant. Always.
- **Convenience cross-tenant method** — `findAllAcrossTenants` on a normal repo. Move to admin repo or delete.
- **Cache key string-concat** — `cache.get('user:' + id)` instead of helper. Tenant prefix WILL be missed eventually.
- **Single-column index** on a filter column. Composite `(tenant_id, <filter>)` or full scan.
- **Global unique on natural key** — `UNIQUE (slug)` blocks tenant B from picking tenant A's slug. Use `(tenant_id, slug)`.
- **Soft-delete query without tenant filter** — `WHERE deleted_at IS NULL` leaks listed deletes. Filter applies to all queries, not just selects.
- **RLS-only isolation** — relying on database RLS without app-layer filters. RLS is a backstop, not the only layer.

## Enforcement

- `<commands-path>/tenant-leak-audit.md` (slash: `/tenant-leak-audit`) — greps repo methods, raw SQL, and ORM queries for missing `tenant_id`; greps `req.body.tenantId` / `req.query.tenantId` / `req.headers['x-tenant-id']`; flags cross-tenant joins, missing isolation tests, single-column indexes on filter columns.
- CI MUST run isolation tests for every tenant-scoped repo; missing `it('filters by tenant_id')` test on a tenant-scoped repo fails the build.
- Migration review MUST reject any new tenant-scoped table without `tenant_id <type> NOT NULL REFERENCES tenants(id)` + composite index.
- `<agents-path>/tenant-isolation-reviewer.md` — review gate; hard-fails PRs that introduce a leak surface without a corresponding isolation test.
- TODO: `scripts/validate-tenant-isolation.sh` to AST-walk repo files and assert every method that touches a tenant-scoped table either accepts `tenantId` or pulls from `<tenant-context>`.

## Cross-references

- `<patterns-path>/multi-tenancy.md` — request-scoped context + resolution chain (the "where").
- `<patterns-path>/tenant-isolation.md` — repo-layer enforcement (the "how").
- `<commands-path>/tenant-leak-audit.md` — scanner.
- `<agents-path>/tenant-isolation-reviewer.md` — review gate.
- `<adr-path>/<NNN>-multi-tenant-shared-db-row-level.md` — ADR pinning the deployment shape.
