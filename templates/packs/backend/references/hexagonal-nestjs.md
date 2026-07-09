# Hexagonal + DDD rules (NestJS)

> **Framework**: NestJS 10+ • TypeORM 0.3+ or Prisma 5+ • TypeScript 5+
> **Official docs**: https://docs.nestjs.com/ • Hexagonal Architecture: https://alistair.cockburn.us/hexagonal-architecture/
> **Version-specific gotchas**: NestJS 10's `@nestjs/cqrs` requires explicit handler exports; TypeORM 0.3 changed repository API (no more `Connection`, use `DataSource`); class-validator 0.14 with NestJS validation pipe needs `transform: true` for nested DTOs.
> **Substitution markers**: Replace `<Thing>` placeholders with the project's actual aggregate / value-object / use-case names from `_extracted-idioms.md`.

## Layers (strict)

```
domain/          pure TS, no framework, no imports from other layers
application/     imports domain only; declares ports (interfaces)
infrastructure/  imports domain + application; implements ports
interface/       imports application only; controllers / webhooks
```

Violation = block at review.

## Domain

- Aggregates extend `AggregateRoot<Id>`.
- Every state change publishes a domain event via `this.apply(new EventX(...))`.
- Value objects are immutable classes with `equals()`.
- Domain errors extend `DomainError` with a stable `code`.

## Ports

- Interfaces in `application/ports/`.
- Named `<Thing>Repository` or `<Thing>Port`.
- Input/output types are domain types — NEVER ORM entities or SDK types.

## Use-cases

- Single intent per use-case. Name: `<Verb><Noun>UseCase`.
- Constructor-inject ports via DI tokens.
- Orchestrate domain + ports. No business logic of its own.

## Adapters (infrastructure)

- One file per adapter. Name: `<technology>.<port-name>.ts` (e.g., `typeorm.user.repository.ts`).
- Map ORM ↔ domain via a dedicated mapper class.
- Never leak ORM types to callers.

## Resilience, streaming, conditional requests & pagination

This file is the **layering** companion to `nestjs.md` — it does not restate the full HTTP block. Rate limiting, ETag/conditional requests, streaming, and async-job offload are *interface-layer* concerns: they live on the controller / adapter (`@nestjs/throttler`, `@Sse`/`StreamableFile`, a BullMQ producer returning `202`) and MUST NOT leak into `domain` or `application`. See the full wiring in `nestjs.md` § "Resilience, streaming & conditional requests" + the sibling patterns (`ai-patterns/{rate-limiting,conditional-requests,response-streaming,async-job-offload}.md`).

- **Pagination** — keep the contract hexagonal: the port declares `page(query: PageQuery): Promise<Page<Domain>>` in domain types (cursor + limit in, `{ items, nextCursor, hasMore }` out) — never ORM `FindManyOptions` or a raw `Repository`. The keyset predicate + stable tiebroken sort + `limit + 1` (no `COUNT(*)`) live in the TypeORM adapter; the controller maps `Page<Domain>` to the response envelope and enforces the default + max limit. → `ai-patterns/pagination.md`.

## Events

- Domain events → dispatched by the event bus after the aggregate is saved.
- Event handlers live in `application/event-handlers/`.
- Idempotent — handler may fire more than once under retry.

## Tests

- Domain: pure unit tests, no mocks, no DB.
- Application: mocks at port boundary.
- Infra: integration tests with real DB.
- Interface: e2e with running HTTP server.
