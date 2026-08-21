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
- Validate untrusted input at ONE boundary before use-case logic: `decode → validate → normalize → authorize` (canonicalize AFTER validate, never before). Bind writes through an explicit writable-field allow-list (`whitelist` / `.strict()` / `permit(...)`) — server-set fields (`id`, `role`, `tenant_id`, `ownerId`, `price`) never come from the body. Bound every string / array / number (`@MaxLength` / `@ArrayMaxSize` / `@Min`/`@Max`, nesting depth). Enforce a `Content-Type` allow-list + max body size before parsing (`415` / `413 Content Too Large` — RFC 9110 §15.5.14 renamed it from "Payload Too Large"). On failure emit a structured `422` field-error map with stable machine codes (envelope owned by `error-handling`). See `ai/patterns/request-validation.md`. (SEC-01)
- Services own business logic AND transaction boundaries. Repositories own queries. Controllers own HTTP shape.
- Domain / core code imports nothing framework-specific (no `Request`, no `Reply`, no `Session`). Easy unit testing follows for free.
- Auth on every endpoint by default. Public endpoints are explicitly marked + reviewed.
- Authorization (who-can) checked AFTER authentication (who-is). Different concerns, different layers.
- Every list endpoint paginates with a default limit (e.g. 20 / 50). Cursor preferred over offset for deep lists.
- Every mutating endpoint returns the resource or its ID. No silent 204s on POST without a documented reason.
- Custom error classes per domain concept (`OrderNotFoundError`, `PaymentDeclinedError`). Mapped to HTTP statuses in ONE place — global filter / error middleware.
- Single response envelope: every endpoint returns the project's ONE canonical response shape (bare resource OR `{ data, meta }` — pick one, apply everywhere); mixing shapes across endpoints is drift. The error body is the one error contract (RFC 9457 Problem Details is the interop option). See `ai/patterns/api-contract.md` + `ai/patterns/error-handling.md`.
- Content negotiation: reject an unsupported request `Content-Type` with `415 Unsupported Media Type`, an unacceptable `Accept` with `406 Not Acceptable`, and set `Vary` on any content-negotiated or auth-varied response so caches don't serve the wrong representation.
- Idempotency keys on every external retry boundary: webhooks, queue consumers, payment attempts. Receiver dedupes via unique constraint.
- Stored replay required — persist `(key → response_status + response_body)` atomically with the side effect and replay that stored response on retry. Accepting the `Idempotency-Key` header without storing+replaying is non-compliant (a second call with the same key must NOT re-execute the side effect). The persisted-key table schema + replay-state machine live in the **distributed-systems** pack (its `idempotency` pattern — not shipped in the backend pack); this is the one-line backend floor. (API-7)
- Rate-limit every unauthenticated and every expensive endpoint (search / export / report / bulk / upload / LLM-proxy); return `429 Too Many Requests` (RFC 6585) with `Retry-After` (RFC 9110 §10.2.3 — seconds or HTTP-date) + the two quota fields `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=0;t=30` (IETF `draft-ietf-httpapi-ratelimit-headers` — still an Internet-Draft, NOT an RFC). The `RateLimit-Limit` / `-Remaining` / `-Reset` triple is draft-05 legacy and vendor `X-RateLimit-*` is still shipped reality — emit the two-field form AND whichever legacy set your clients read, until they migrate. Counters live in a shared store, never process memory. See `ai/patterns/rate-limiting.md`. (RES-1)
- Parameterized queries always. Soft-delete + tenant filters applied at the repository layer for raw queries that bypass the base repo.
- Structured logs (JSON in prod) with correlation ID propagated through every layer + downstream call.
- Config validated on boot — fail fast if a required env var is missing or malformed (`zod.parse(process.env)` / pydantic settings).

## Must not

- Bind a whole request body onto a persisted entity (`save(req.body)` / `Object.assign(entity, body)` / `Model.update(params)`) — mass-assignment / over-posting lets a client set `role` / `isAdmin` / `tenant_id` / `ownerId` / `price`. Bind only the DTO's declared writable fields. See `ai/patterns/request-validation.md`. (SEC-01)
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
- Store request-scoped or per-user state in process memory / module-level mutable singletons / local disk — it does not survive horizontal scale-out or rolling deploys, and silently corrupts behind a load balancer. Sessions, response caches, rate-limit counters, locks, and dedupe sets MUST live in a shared store (Redis / DB). This is the shared store as **source of truth** for that datum; it is NOT a licence to cache a copy of DB truth — `caching-strategy`'s do-not-cache list (auth tokens, session *content*) governs the cache case and does not contradict this MUST. See `ai/patterns/rate-limiting.md` (shared-store buckets) + the distributed-systems `idempotency` pattern. (PERF-6)

## Should

- Use dependency injection (constructor injection or framework DI container) — service classes MUST receive collaborators as constructor args, not `import`-and-call singletons.
- Outbox pattern for "DB write + event publish" atomicity. 2PC / XA is forbidden **across services** — a blocking coordinator turns N independent availabilities into their product, and a coordinator crash leaves every participant's rows locked with no owner to resolve them. (Inside ONE deployment unit spanning two resource managers, a single transaction manager is defensible; that is not this case.)
- Feature flags for risky changes — decouple deploy from release.
- Health endpoints: `/healthz` (liveness — process up) and `/readyz` (readiness — deps up). Different semantics; different consumers.
- Graceful shutdown: drain in-flight requests, close DB pool, finish queue ack — bounded by a deadline (default 30s).
- Set a timeout on every external call (HTTP client, DB, cache, queue). No-timeout calls are forbidden — the default is cascading failure.
- Retries with exponential backoff + jitter for transient errors only — never on 4xx.
- Optimistic concurrency: a mutable resource contended by more than one writer exposes a strong `ETag` and requires `If-Match` on writes (`412 Precondition Failed` on stale, `428 Precondition Required` when the header is absent); reads honour `If-None-Match` → `304`. Prevents silent lost-updates. See `ai/patterns/conditional-requests.md`.
- Prevent N+1: eager-load / batch related reads instead of querying per row. The query-shape discipline is owned by the **database + performance** packs (`n-plus-one-scan`); `api-reviewer` flags an N+1 inline at review time.
- Resilience (outbound): the per-call failure-mode matrix — timeout-budget nesting (inner deadline < outer), retry eligibility, circuit breaker, per-dependency bulkhead, dead-letter queue — is OWNED by the distributed-systems pack. Consult its `resilience-reviewer` + `circuit-breaker` / `idempotency` / `outbox` patterns. The `api-reviewer` External-calls checklist (every call has a timeout + bounded retries + a fallback) is the inline floor when that pack isn't installed. (RES-2)
- Observability DoD: every endpoint also emits a RED metric (rate / errors / duration) + a trace span; generate the correlation / trace id at the edge OR continue an inbound W3C `traceparent` header — never start a fresh trace when one is already in flight. The full RED / USE / SLO / OTel design (cardinality budgets, sampling, audit-log) lives in the observability pack (Related: `observability-principles`); this is the always-on backend hook. (OBS-1)

## Review checklist

- [ ] Auth check on every new endpoint.
- [ ] Input validated with a schema.
- [ ] Untrusted input validated at one boundary; writes bind an explicit field allow-list (no `save(req.body)` / mass-assignment); strings / arrays / numbers bounded; failure returns a `422` field-error map. (SEC-01)
- [ ] Pagination on new list endpoint.
- [ ] No business logic in controller.
- [ ] No raw SQL in service.
- [ ] New custom errors mapped to HTTP statuses.
- [ ] Response uses the project's single envelope; content negotiation returns `415`/`406` + `Vary` where applicable.
- [ ] Contended mutable resource requires `If-Match` (`412`/`428`); read honours `If-None-Match` → `304`.
- [ ] No external call inside a transaction.
- [ ] No header-trusted user / tenant identity.
- [ ] Logs structured + carry correlation ID.
- [ ] Idempotency key on retryable mutation endpoints.
- [ ] Idempotent endpoint stores `(key → status + body)` and replays it on retry — not just accepts the header. (API-7)
- [ ] Unauthenticated / expensive endpoint rate-limited: `429` + `Retry-After` + `RateLimit` / `RateLimit-Policy` (plus the legacy triple only while clients migrate). (RES-1)
- [ ] No request-scoped / per-user state in process memory, singletons, or local disk — shared store only. (PERF-6)
- [ ] Outbound calls carry timeout + bounded retries + fallback (api-reviewer floor; distributed-systems pack owns the full matrix). (RES-2)
- [ ] New endpoint emits a RED metric + trace span; trace id generated at edge or continued from inbound `traceparent`. (OBS-1)

## Enforcement

- ESLint / TSLint plugins for layering rules (e.g. `eslint-plugin-boundaries`, `dependency-cruiser`).
- Type-check (`tsc --noEmit`, `mypy --strict`, `pyright`) gates CI.
- `eslint-plugin-no-secrets` / `gitleaks` blocks committed secrets.
- Schema-driven contract tests (OpenAPI / Pact / GraphQL schema diff) prevent breaking consumers.

## Related

- **Patterns** (in-pack): `api-contract` (envelope), `error-handling` (error contract), `request-validation` (boundary validation + writable-field allow-list), `pagination`, `conditional-requests` (ETag/optimistic-concurrency), `rate-limiting`, `response-streaming`, `async-job-offload`, `caching-strategy`, `parallel-io`, `webhook-flow`, `multi-tenancy`.
- **Sibling rules**: `concurrency-discipline` (bounded fan-out, no parallel-in-tx), `migration-backend` (online-safe schema change — ships when the migration pack is loaded).
- **Cross-pack owners** (referenced, not duplicated — resolve when co-installed): idempotency stored-replay + resilience matrix / outbox / circuit-breaker → **distributed-systems**; N+1 / query shape / index discipline → **database** + **performance** (`n-plus-one-scan`); authz / tenant isolation / SSRF / mass-assignment → **security**; RED / OTel / cardinality / audit-log → **observability**.
