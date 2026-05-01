---
name: backend-principles
kind: example
pack: backend
---

# Backend Principles

Stack-agnostic. Framework specifics in `references/<framework>.md` (nestjs, express, fastify, fastapi, django, rails, laravel, spring, go-chi, gin).

Prevents the recurring backend failures: business logic in controllers, raw SQL in services, missing tenant filters, unvalidated webhooks, transactions over network calls.

## Must

- Layered architecture: HTTP/webhook/CLI adapter → service / use-case → repository. Each layer crosses one boundary.
- Adapters validate every input with a schema (`zod`, `class-validator`, `pydantic`, `marshmallow`, `go-playground/validator`). Internal calls trust types; boundaries don't.
- Services own business logic AND transaction boundaries. Repositories own queries. Controllers own HTTP shape.
- Domain / core code imports nothing framework-specific (no `Request`, no `Reply`, no `Session`). Easy unit testing follows for free.
- Auth on every endpoint by default. Public endpoints are explicitly marked + reviewed.
- Authorization (who-can) checked AFTER authentication (who-is). Different concerns, different layers.
- Every list endpoint paginates with a default limit (e.g. 20 / 50). Cursor preferred over offset for deep lists.
- Every mutating endpoint returns the resource or its ID. No silent 204s on POST without a documented reason.
- Custom error classes per domain concept (`OrderNotFoundError`, `PaymentDeclinedError`). Mapped to HTTP statuses in ONE place — global filter / error middleware.
- Idempotency keys on every external retry boundary: webhooks, queue consumers, payment attempts. Receiver dedupes via unique constraint.
- Parameterized queries always. Soft-delete + tenant filters applied at the repository layer for raw queries that bypass the base repo.
- Structured logs (JSON in prod) with correlation ID propagated through every layer + downstream call.
- Config validated on boot — fail fast if a required env var is missing or malformed (`zod.parse(process.env)` / pydantic settings).

## Must not

- Business logic in controllers / route handlers. Controllers map HTTP ↔ service input/output, nothing else.
- Direct repository / DB access from controllers. Always go through a service.
- Raw SQL in services. Queries belong in repositories.
- `throw new Error('...')` on user-reachable paths — caller can't `instanceof` it specifically.
- Leak stack traces, raw SQL, internal file paths to clients. Prod error response = `{ code, message }`.
- Hold a DB transaction across an external API / queue publish / HTTP call. Connection pool dies at peak.
- Sync I/O in async handlers (`fs.readFileSync`, blocking DB driver). Stops the event loop.
- CPU-bound work > 50ms on the main thread / event loop. Offload to a worker / queue.
- Trust headers like `X-User-Id`, `X-Tenant-Id` from the public internet. Derive identity from authenticated session / JWT only.
- Log secrets, tokens, full PII. Mask or hash.
- Accept tenant ID in request bodies — derive from authenticated context (AsyncLocalStorage / request scope).

## Should

- Default to dependency injection (constructor injection or framework DI container). Easier to test, easier to swap implementations.
- Outbox pattern for "DB write + event publish" atomicity. Avoid 2PC.
- Feature flags for risky changes — decouple deploy from release.
- Health endpoints: `/healthz` (liveness — process up) and `/readyz` (readiness — deps up). Different semantics; different consumers.
- Graceful shutdown: drain in-flight requests, close DB pool, finish queue ack — bounded by a deadline.
- Timeouts on every external call (HTTP client, DB, cache, queue). Default no-timeout = cascading failure.
- Retries with exponential backoff + jitter for transient errors only — not for 4xx.

## Review checklist

- [ ] Auth check on every new endpoint.
- [ ] Input validated with a schema.
- [ ] Pagination on new list endpoint.
- [ ] No business logic in controller.
- [ ] No raw SQL in service.
- [ ] New custom errors mapped to HTTP statuses.
- [ ] No external call inside a transaction.
- [ ] No header-trusted user / tenant identity.
- [ ] Logs structured + carry correlation ID.
- [ ] Idempotency key on retryable mutation endpoints.

## Enforcement

- ESLint / TSLint plugins for layering rules (e.g. `eslint-plugin-boundaries`, `dependency-cruiser`).
- Type-check (`tsc --noEmit`, `mypy --strict`, `pyright`) gates CI.
- `eslint-plugin-no-secrets` / `gitleaks` blocks committed secrets.
- Schema-driven contract tests (OpenAPI / Pact / GraphQL schema diff) prevent breaking consumers.
