---
name: backend-principles
description: Backend Principles
kind: rule
pack: backend
severity: must
applies-to: backend-track, every-code-writing-task-in-backend
---

# Backend Principles

> **Hard rule.** Every HTTP / webhook / queue handler MUST: (a) validate input at the boundary with a schema, (b) enforce auth + authorization before business logic runs, and (c) keep business logic in services — controllers and repositories MUST NOT contain it. No external I/O is held inside a DB transaction.

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
- Stored replay required — persist `(key → response_status + response_body)` atomically with the side effect and replay that stored response on retry. Accepting the `Idempotency-Key` header without storing+replaying is non-compliant (a second call with the same key must NOT re-execute the side effect). The persisted-key table schema + replay-state machine live in the distributed-systems pack; this is the one-line backend floor. See `ai/patterns/idempotency.md`. (API-7)
- Rate-limit every unauthenticated and every expensive endpoint (search / export / report / bulk / upload / LLM-proxy); return `429 Too Many Requests` (RFC 6585) with `Retry-After` (RFC 9110 §10.2.3 — seconds or HTTP-date) + `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset` headers (IETF `draft-ietf-httpapi-ratelimit-headers` — a draft, prefer the unprefixed form over legacy `X-RateLimit-*`). Counters live in a shared store, never process memory. See `ai/patterns/rate-limiting.md`. (RES-1)
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
- Store request-scoped or per-user state in process memory / module-level mutable singletons / local disk — it does not survive horizontal scale-out or rolling deploys, and silently corrupts behind a load balancer. Sessions, response caches, rate-limit counters, locks, and dedupe sets MUST live in a shared store (Redis / DB). See `ai/patterns/rate-limiting.md` (shared-store buckets) + `ai/patterns/idempotency.md`. (PERF-6)

## Should

- Use dependency injection (constructor injection or framework DI container) — service classes MUST receive collaborators as constructor args, not `import`-and-call singletons.
- Outbox pattern for "DB write + event publish" atomicity. 2PC / XA is forbidden across services.
- Feature flags for risky changes — decouple deploy from release.
- Health endpoints: `/healthz` (liveness — process up) and `/readyz` (readiness — deps up). Different semantics; different consumers.
- Graceful shutdown: drain in-flight requests, close DB pool, finish queue ack — bounded by a deadline (default 30s).
- Set a timeout on every external call (HTTP client, DB, cache, queue). No-timeout calls are forbidden — the default is cascading failure.
- Retries with exponential backoff + jitter for transient errors only — never on 4xx.
- Resilience (outbound): the per-call failure-mode matrix — timeout-budget nesting (inner deadline < outer), retry eligibility, circuit breaker, per-dependency bulkhead, dead-letter queue — is OWNED by the distributed-systems pack. Consult its `resilience-reviewer` + `circuit-breaker` / `idempotency` / `outbox` patterns. The `api-reviewer` External-calls checklist (every call has a timeout + bounded retries + a fallback) is the inline floor when that pack isn't installed. (RES-2)
- Observability DoD: every endpoint also emits a RED metric (rate / errors / duration) + a trace span; generate the correlation / trace id at the edge OR continue an inbound W3C `traceparent` header — never start a fresh trace when one is already in flight. The full RED / USE / SLO / OTel design (cardinality budgets, sampling, audit-log) lives in the observability pack (Related: `observability-principles`); this is the always-on backend hook. (OBS-1)

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
- [ ] Idempotent endpoint stores `(key → status + body)` and replays it on retry — not just accepts the header. (API-7)
- [ ] Unauthenticated / expensive endpoint rate-limited: `429` + `Retry-After` + `RateLimit-*` headers. (RES-1)
- [ ] No request-scoped / per-user state in process memory, singletons, or local disk — shared store only. (PERF-6)
- [ ] Outbound calls carry timeout + bounded retries + fallback (api-reviewer floor; distributed-systems pack owns the full matrix). (RES-2)
- [ ] New endpoint emits a RED metric + trace span; trace id generated at edge or continued from inbound `traceparent`. (OBS-1)

## Enforcement

- ESLint / TSLint plugins for layering rules (e.g. `eslint-plugin-boundaries`, `dependency-cruiser`).
- Type-check (`tsc --noEmit`, `mypy --strict`, `pyright`) gates CI.
- `eslint-plugin-no-secrets` / `gitleaks` blocks committed secrets.
- Schema-driven contract tests (OpenAPI / Pact / GraphQL schema diff) prevent breaking consumers.
