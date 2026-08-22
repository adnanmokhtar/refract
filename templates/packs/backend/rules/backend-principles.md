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

Stack-agnostic. Framework specifics in `references/<framework>.md`. Prevents the recurring backend failures: business logic in controllers, raw SQL in services, missing tenant filters, unvalidated webhooks, transactions over network calls.

**What earns a line here.** Always loaded means every line is billed in every backend session, including the ones that never touch HTTP — so a line qualifies only if it changes what gets written *before* anyone knows which pattern applies. Tables, code samples, header specs and per-project numbers are `ai/patterns/` work. Hence: no portable numeric threshold in this file, and no review checklist, a checkbox restating a MUST forty lines above it being the same rule billed twice.

## Must

- Layered architecture: HTTP/webhook/CLI adapter → service / use-case → repository. Each layer crosses one boundary.
- Validate untrusted input at ONE boundary with a schema, in this order: `decode → validate → normalize → authorize`. Canonicalize AFTER validate — normalizing first is how a rejected input becomes an accepted one. Bound every string / array / number and the nesting depth; enforce a `Content-Type` allow-list + max body size *before* parsing. See `ai/patterns/request-validation.md`. (SEC-01)
- Bind writes through an explicit writable-field allow-list. Server-set fields (`id`, `role`, `tenant_id`, `ownerId`, `price`) never come from the body. (SEC-01)
- Services own business logic AND transaction boundaries. Repositories own queries. Controllers own HTTP shape.
- Domain / core code imports nothing framework-specific (no `Request`, no `Reply`, no `Session`). Easy unit testing follows for free.
- Auth on every endpoint by default; public endpoints are explicitly marked and reviewed.
- Authorization (who-can) checked AFTER authentication (who-is) — a valid token is not a permission, and the test that proves it is a `403` for the wrong principal, never a `401`.
- Every list endpoint paginates with a default limit. Cursor preferred over offset for deep lists.
- Every mutating endpoint returns the resource or its ID — a silent `204` on POST forces the client into a second round-trip to learn what it just created.
- Custom error classes per domain concept (`OrderNotFoundError`), mapped to HTTP statuses in ONE place — global filter / error middleware.
- One canonical response envelope for the whole project (bare resource OR `{ data, meta }` — pick one, apply everywhere); mixing shapes across endpoints is drift. Error bodies use the one error contract and are never wrapped in the success envelope. See `ai/patterns/api-contract.md` + `error-handling.md`.
- Content negotiation: unsupported request `Content-Type` → `415`; unsatisfiable `Accept` → `406`; `Vary` on any negotiated or auth-varied response, so a shared cache cannot hand one client another's representation.
- Idempotency at every external retry boundary (webhooks, queue consumers, payment attempts): dedupe by unique constraint, and persist `(key → status + body)` atomically with the side effect so a retry replays it. **Accepting the `Idempotency-Key` header without storing and replaying is non-compliant** — the second call must not re-execute the side effect. (API-7)
- Rate-limit every unauthenticated and every expensive endpoint (search / export / report / bulk / upload / LLM-proxy); `429` carries `Retry-After` plus the quota fields `ai/patterns/rate-limiting.md` specifies — that pattern is the only place the current-vs-legacy header question is answered. Counters live in a shared store, never process memory. (RES-1)
- Parameterized queries always. Soft-delete + tenant filters applied at the repository layer for raw queries that bypass the base repo.
- Structured logs (JSON in prod) with a correlation ID propagated through every layer and every downstream call.
- Config validated on boot — fail fast on a missing or malformed env var. A key that fails fast is a boot error; one that does not fails three layers in as an `undefined`.

## Must not

- Bind a whole request body onto a persisted entity (`save(req.body)` / `Object.assign(entity, body)` / `Model.update(params)`) — mass-assignment lets a client set `role` / `isAdmin` / `tenant_id` / `price`. (SEC-01)
- Business logic in controllers / route handlers. Controllers map HTTP ↔ service input/output, nothing else.
- Direct repository / DB access from controllers. Always go through a service.
- Raw SQL in services. Queries belong in repositories.
- `throw new Error('...')` on user-reachable paths — the caller cannot `instanceof` it specifically.
- Leak stack traces, raw SQL, or internal file paths to clients. Prod error response = `{ code, message }`.
- Hold a DB transaction across an external API / queue publish / HTTP call — the transaction's lifetime becomes a remote service's timeout, and the connection pool dies at peak.
- Sync I/O in async handlers (`fs.readFileSync`, blocking DB driver). Stops the event loop.
- CPU-bound work > 50ms on the main thread / event loop. Offload to a worker / queue.
- Trust headers like `X-User-Id`, `X-Tenant-Id` from the public internet. Derive identity from the authenticated session / JWT only.
- Log secrets, tokens, or full PII. Mask or hash.
- Accept tenant ID in a request body — derive it from authenticated context (AsyncLocalStorage / request scope).
- Store request-scoped or per-user state in process memory, mutable module singletons, or local disk. It survives neither scale-out nor a rolling deploy, and it fails *silently* — behind a load balancer it works for whichever share of requests lands on the right process. Sessions, response caches, rate-limit counters, locks and dedupe sets belong in a shared store, as source of truth for that datum (which is not a licence to cache DB truth — `ai/patterns/caching-strategy.md` governs that). (PERF-6)

## Should

- Dependency injection: service classes receive collaborators as constructor args, not `import`-and-call singletons.
- Outbox pattern for "DB write + event publish" atomicity. 2PC / XA is forbidden **across services** — a blocking coordinator turns N independent availabilities into their product, and a coordinator crash leaves every participant's rows locked with no owner to resolve them. (Inside ONE deployment unit spanning two resource managers, a single transaction manager is defensible; that is not this case.)
- Graceful shutdown: drain in-flight requests, close the DB pool, finish queue acks — bounded by a deadline.
- A timeout on every external call (HTTP, DB, cache, queue). No-timeout is not a default, it is cascading failure.
- Retries with exponential backoff + jitter, for transient errors only — never on 4xx, never on a non-idempotent write.
- Optimistic concurrency: a mutable resource with more than one writer exposes a strong `ETag` and requires `If-Match` on writes. Without it the second writer silently overwrites the first and nothing in the logs says so. Status codes and the version-column mapping: `ai/patterns/conditional-requests.md`.
- Prevent N+1: eager-load / batch related reads instead of querying per row. Query-shape depth is owned by the **database + performance** packs (`n-plus-one-scan`); `api-reviewer` flags an N+1 inline at review time.
- Outbound resilience — nested timeout budgets, retry eligibility, circuit breaker, bulkhead, DLQ — is owned by the **distributed-systems** pack. Inline floor when it is not installed: timeout + bounded retries + a declared fallback. (RES-2)
- Every endpoint emits a RED metric (rate / errors / duration) + a trace span; generate the trace id at the edge OR continue an inbound W3C `traceparent` — never start a fresh trace when one is in flight, which severs the request from its caller. Cardinality budgets and sampling belong to the observability pack. (OBS-1)

## Related

- **Depth** lives in this pack's `ai/patterns/` (each MUST above names the one it points at) and in the sibling rules `concurrency-discipline` (bounded fan-out) and `migration-backend` (V1→V2 transposition, migration layouts only).
- **Enforcement is tooling, not prose**: layering via `eslint-plugin-boundaries` / `dependency-cruiser`, types via `tsc --noEmit` / `mypy --strict`, secrets via `gitleaks`, contract drift via OpenAPI / Pact / schema diff. Wire them in CI once; this rule does not re-list them per project.
- **Cross-pack owners** (referenced, never duplicated): idempotency replay + resilience matrix / outbox → **distributed-systems**; query shape + indexes → **database** + **performance**; authz / tenant isolation / SSRF → **security**; RED / OTel / cardinality → **observability**.
