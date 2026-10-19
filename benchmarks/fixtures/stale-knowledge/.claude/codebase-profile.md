# Codebase profile — Orderly
approved_hash: 9ce42e5a1ca2
approved_at: 2026-07-08

Read by `/setup-project` when it anchors installed agents, commands and skills. Corrected 2026-09-07.

## Stack

- Monorepo: pnpm workspaces (`apps/api`, `apps/web`, `packages/contracts`), Node 22 from `.nvmrc`.
- API: NestJS 11 on Fastify (`@nestjs/platform-fastify`); background jobs on BullMQ and Redis.
- Web: React 19 + Vite 6; TanStack Query for server state.

## Architecture

- Modular NestJS monolith: one module per folder under `apps/api/src/modules/`.

## Naming

- kebab-case files with role suffixes (`*.service.ts`, `*.controller.ts`, `*.entity.ts`).

## Data access

- MikroORM 6 over Postgres 16 (`@mikro-orm/postgresql`); UUIDv7 primary keys from `newId()`.

## Testing

- Jest specs beside the code (`*.spec.ts`); e2e suites under `apps/api/test/`.

## Error handling

- Services throw `DomainError` subclasses; `HttpErrorFilter` maps them to problem+json responses.
