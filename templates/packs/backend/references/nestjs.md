# NestJS Clean Architecture rules

## Layer imports (strict)

- `core/` → imports NOTHING from NestJS, TypeORM, or any other framework. Pure TS.
- `application/` → imports from `core/` only. Uses ports (interfaces) from `core/ports/`.
- `infrastructure/` → imports from `core/` (ports to implement). May import TypeORM, SDKs, etc.
- `adapters/` → imports from `application/`. Never from `infrastructure/` directly.
- `<module>.module.ts` → the ONLY place that binds adapters ↔ use-cases ↔ infra via DI.

Violation = block at review.

## Dependency injection

- DI tokens are `Symbol('NAME')` declared in `tokens.ts` per module.
- Providers use `{ provide: Token.X, useClass: Y }` — no magic strings.
- Controllers inject use-cases via `@Inject(Tokens.USE_CASE)`.

## DTOs

- Every input DTO has `class-validator` decorators on every field.
- Every input DTO has a test that rejects invalid payloads.
- Output DTOs are plain classes — no decorators needed.
- NEVER return the ORM entity from a controller. Always map.

## Error handling

- Domain errors live in `core/errors/`. They extend a base `DomainError`.
- Controllers catch domain errors and map to HTTP status via a global filter.
- Never throw `new Error(...)` — use a typed error class.

## Tests

- Unit tests next to the code (`*.spec.ts`).
- Use-cases: unit tested with mocked ports.
- Controllers: e2e tested with a real DB (test container or sqlite).
- Repos: integration tested against a real DB.
- NEVER hit real external APIs in any test — always mock the client.
