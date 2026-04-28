# Hexagonal + DDD rules (NestJS)

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

## Events

- Domain events → dispatched by the event bus after the aggregate is saved.
- Event handlers live in `application/event-handlers/`.
- Idempotent — handler may fire more than once under retry.

## Tests

- Domain: pure unit tests, no mocks, no DB.
- Application: mocks at port boundary.
- Infra: integration tests with real DB.
- Interface: e2e with running HTTP server.
