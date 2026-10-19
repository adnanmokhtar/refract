---
name: add-migration
description: Generates, reviews and dry-runs one schema migration.
kind: command
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
pack: database
---

<!-- project-specific:start -->
## Project-specific (auto-generated, regenerate with `/setup-project --refine`)

> Auto-populated by `scripts/apply-anchors.sh` from `.claude/codebase-profile.md`. Round-one floor — `/setup-project --refine` deepens shallow blocks based on `compute-anchor-density` scoring.
>
> - **Architecture** (`.claude/codebase-profile.md:15`): Modular NestJS monolith: one module per folder under `apps/api/src/modules/`.
> - **Naming** (`.claude/codebase-profile.md:19`): kebab-case files with role suffixes (`*.service.ts`, `*.controller.ts`, `*.entity.ts`).
> - **Testing** (`.claude/codebase-profile.md:27`): Jest specs beside the code (`*.spec.ts`); e2e suites under `apps/api/test/`.
> - **Data access** (`.claude/codebase-profile.md:23`): MikroORM over MySQL 8; one `EntityManager` fork per request.
> - **Error handling** (`.claude/codebase-profile.md:31`): Services throw `DomainError` subclasses; `HttpErrorFilter` maps them to problem+json responses.
> - **Detected load-bearing idioms** (`_extracted-idioms.md`): `BaseRepository` (1 abstract base, extended per aggregate)
>
> - **Where this applies here** (`Migration`): `apps/api/src/migrations/Migration20260924.ts:3`, 2 file(s) in apps/api/src/migrations
> Cite-able sources: package.json, apps/api/package.json, apps/web/package.json, top-level: apps, packages, docs.

<!-- project-specific:end -->

# /add-migration

Generate one migration, read its SQL, and dry-run it against a copy of the schema.

## Steps

1. Generate the migration with the project ORM.
2. Read every statement; flag table rewrites and long locks.
3. Dry-run against a scratch database.
4. Record the decision when the change is architectural.

## Example (generic, from the pack)

A team that moves a column to another table records it as `ADR-0042` superseding `ADR-0017`, and the migration
names that ADR in its header comment.
