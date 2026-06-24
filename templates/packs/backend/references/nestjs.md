# NestJS Clean Architecture rules

> **Framework**: NestJS 10+ on Node 20+ • TypeScript 5+
> **Official docs**: https://docs.nestjs.com/
> **Version-specific gotchas**: NestJS 10 dropped legacy decorators that worked in v9; class-validator 0.14+ requires explicit `@Type()` for nested DTOs; `@nestjs/cqrs` v10 changed event-handler discovery (must export from module).
> **Substitution markers**: Replace `<Module>` / `<UseCase>` / `<Repo>` / DI `Tokens.X` with the project's actual identifiers from `_extracted-idioms.md`.

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

## Resilience, streaming & conditional requests

- **Rate limiting**: gate inbound load with `@nestjs/throttler` — `ThrottlerModule.forRoot([...])` globally, `@Throttle({ default: { limit, ttl } })` / `@SkipThrottle()` per route. The default in-memory `ThrottlerStorage` resets per pod, so multi-instance deploys MUST use `@nestjs/throttler-storage-redis` (shared store) or each replica enforces its own quota. Throttler emits `429` + `Retry-After`; surface unprefixed `RateLimit-Limit/Remaining/Reset` over legacy `X-RateLimit-*`. Defect: `@Throttle()` on a controller with no shared storage in a >1-replica chart `<deploy/values.yaml>`. → ai/patterns/rate-limiting.md
- **Conditional requests**: enable `ETag` (`app.use(etag())` in `main.ts`, or a response interceptor that hashes the serialized body) so reads revalidate to `304`. For writes, read `If-Match` in a guard/interceptor and compare it to the entity's `version` column (TypeORM `@VersionColumn`); mismatch → `412 Precondition Failed`, missing on an unsafe method → `428 Precondition Required`. Defect: a PATCH controller writing the ORM entity with no `If-Match` check `<*.controller.ts:PATCH>` — last-writer-wins. → conditional-requests.md
- **Streaming**: return `StreamableFile` for file/download responses; use `@Sse('events')` returning an `Observable` for server-sent events; for NDJSON write to the raw `@Res() res` and respect backpressure (await `res.write()` / honor the `drain` event) and `req.on('close')` to cancel work on disconnect. Defect: building a full array then `res.json()` for an unbounded query `<*.controller.ts>` — heap blow-up, no mid-stream error sentinel. → response-streaming.md
- **Async jobs**: offload work >~1s — a `@nestjs/bullmq` producer enqueues in the controller and returns `202 Accepted` + `Location: /jobs/:id`, a `@Processor()` consumer runs the job, and `GET /jobs/:id` exposes the status state machine (queued→running→done/failed, result behind a TTL). Make submit idempotent via a client key → existing-job lookup. Defect: a controller doing the heavy work inline and returning `200` only after it finishes `<*.controller.ts>`. → async-job-offload.md

## Tests

- Unit tests next to the code (`*.spec.ts`).
- Use-cases: unit tested with mocked ports.
- Controllers: e2e tested with a real DB (test container or sqlite).
- Repos: integration tested against a real DB.
- NEVER hit real external APIs in any test — always mock the client.
