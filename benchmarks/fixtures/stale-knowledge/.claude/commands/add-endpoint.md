---
name: add-endpoint
description: Adds one HTTP endpoint with its schema, service call, test and docs.
kind: command
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
pack: backend
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
> - **Money in responses**: render amounts with `formatMinorUnits()` before they reach a response DTO.
> - **Where this applies here** (`OrdersController`): `apps/api/src/modules/orders/orders.controller.ts:8`, 14 file(s) in apps/api/src/modules
> Cite-able sources: package.json, apps/api/package.json, apps/web/package.json, top-level: apps, packages, docs.

<!-- project-specific:end -->

# /add-endpoint

Add one endpoint end to end.

## Steps

1. Define the request and response schema in the contracts package.
2. Add the controller method; parse with the schema.
3. Call one service or use case; map the result.
4. Add the controller test and the e2e case.
5. Update the API docs.
