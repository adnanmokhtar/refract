# Multi-tenancy rules

This project is shared-DB, row-level multi-tenant. See ADR `0002` + `ai/patterns/tenant-isolation.md`.

## Hard rules

1. **Every tenant-scoped table has `tenant_id uuid NOT NULL REFERENCES tenants(id)`.** New migrations that add a tenant-scoped table without it will be rejected in review.
2. **Every tenant-scoped repo method filters by `tenant_id`** — accepted as a parameter or pulled from `TenantContext`. A method that doesn't is a bug.
3. **`tenant_id` comes from the server, never from the client.** No DTO field, query param, or header sets it. Ever.
4. **Cross-tenant access lives in separate `*.admin-repository.ts` files** with explicit naming, so audits can grep for it.
5. **Every new tenant-scoped repo has an explicit isolation test** (`it('filters by tenant_id')`).
6. **Unique constraints are `(tenant_id, natural_key)`**, never global.

## Checklist before merging a PR touching data access

- [ ] New tables have `tenant_id` column + FK + index.
- [ ] New repo methods take / derive `tenantId`.
- [ ] Raw SQL (if any) includes `WHERE tenant_id = $n`.
- [ ] At least one spec asserts another tenant's rows are filtered out.
- [ ] No new path reads `tenant_id` from a DTO / params / headers.

## When in doubt

Run `/tenant-leak-audit` — greps for suspicious queries and repo methods missing tenant filters.
