---
description: Scan the codebase for tenant-isolation leaks — queries and repo methods missing tenant_id filters.
---

# /tenant-leak-audit

Purpose: catch cross-tenant data leaks before they ship. Runs grep + static checks; flags every suspicious pattern.

## What it checks

1. **Repo methods without `tenantId`.** Any method on a `*Repository` class whose signature has no `tenantId: TenantId` / `tenantId: string` AND whose body doesn't call `tenantContext.getTenantId()`. Exclusion: anything in `*.admin-repository.ts`.
2. **Missing `tenant_id` filter in TypeORM query builders.** Any `.createQueryBuilder(…)` chain inside `infrastructure/persistence/` without a `.andWhere('… tenant_id = :tenantId'` or equivalent. Same carve-out for admin repos.
3. **Raw SQL without tenant filter.** Any `query(` or `.query('...')` in `infrastructure/` whose string doesn't contain `tenant_id`.
4. **Tenant id from client.** Any `@Body()` / `@Query()` / `@Param()` / `@Headers()` field named `tenantId` / `tenant_id` / `tenant` — FORBIDDEN. The server decides tenant.
5. **Entity decorators missing `tenant_id` column.** Any `@Entity()` class in `infrastructure/persistence/entities/` (outside `tenant.orm-entity.ts`) without a `tenant_id` property + index.
6. **Migrations adding a table without `tenant_id`.** Any `CREATE TABLE` in a migration, excluding `tenants`, without a `tenant_id uuid NOT NULL REFERENCES tenants(id)`.
7. **Joins across tenants.** Any `.leftJoin` / `.innerJoin` where the joined table's alias doesn't also appear in a `tenant_id = :tenantId` constraint.

## How to run

```bash
.claude/skills/tenant-leak-scan.sh
```

Or slash: `/tenant-leak-audit`. Claude walks the file tree, runs checks, reports a table:

| File:Line | Check | Severity | Suggested fix |

Severity:
- **blocker** — rules 1, 2, 3, 6 (probable leak).
- **high** — rules 4, 5 (design violation, leak-adjacent).
- **medium** — rule 7 (possible leak, needs human review).

## When to run

- Pre-commit on any PR touching `infrastructure/persistence/` or `application/`.
- Before each release.
- When opening a new migration.

## Resolution

Each finding must be either fixed or explicitly exempted. Exemption format, in the file:

```ts
// tenant-leak:ignore — admin report endpoint, explicitly cross-tenant, see ai/decisions/<ADR>.md
```

No silent ignores. Every exemption references an ADR.

## See also

- `ai/patterns/tenant-isolation.md`
- `.claude/rules/multi-tenancy.md`
- `agents/tenant-isolation-reviewer.md`
