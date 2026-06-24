---
name: api-consistency-audit
description: API surface consistency audit. Detects drift across endpoints in: response envelope shape, error contract, pagination convention, naming case (snake/camel), idempotency-key coverage, auth header convention, rate-limit header coverage, rate-limit enforcement coverage, conditional-request (ETag/If-Match) coverage, batch-endpoint contract, field-selection uniformity, security-header uniformity, log-field naming, metric/trace naming, OpenAPI documentation coverage, timeout/retry policy uniformity. Emits one finding per drift fingerprint with <path:line> evidence + closure verb. Used by /polish on backend-* stacks. Behaviour-preserving (envelope unification + naming changes ship through deprecation flow, not blind rewrite).
kind: skill
pack: backend
---

# Skill: api-consistency-audit

## Purpose

Detect drift across the project's API surface so /polish can unify it. The skill operates on the deployed contract (OpenAPI spec, route table, controller signatures, response builders) and the project's conventions (`_extracted-idioms.md § API conventions` or `ai/api-conventions.md`).

This skill is the API-half of /polish (the frontend half is the design-token / a11y / motion suite).

## When to use

- Dispatched by `/polish` on `backend-*` stacks.
- No command wrapper ships for this skill; invoke via `/polish --diagnose-only --stack=backend` (writes the artifact, no fixes) or run the skill directly.
- NOT for adding new endpoints (use `/add-endpoint`) or fixing functional bugs (use `/fix-bug`).

## Inputs (precise contract)

| Input | Source | Required |
|---|---|---|
| Codebase root | Orchestrator | YES |
| `PROJECT_KIND` (must be `backend-*`) | `_extracted-codebase.md § Gold standards` | YES |
| API conventions | `_extracted-idioms.md § API conventions` OR `ai/api-conventions.md` | YES (without it, the canonical envelope/naming/etc. is unknown — halt) |
| OpenAPI spec | `<openapi.json>` / `<swagger.yaml>` (auto-detected) | NO (skip openapi-coverage detector if missing; warn) |
| Endpoint registry | Auto-detected from controllers / route table | YES |
| Scope filter (optional) | Caller flag | NO (default: all endpoints) |

## Outputs (precise contract)

A finding-draft array — one row per detected drift fingerprint. Each row:

```yaml
class: api-consistency
subclass: <one of: response-envelope-drift | error-contract-drift |
                   naming-convention-drift | pagination-drift | versioning-drift |
                   auth-header-drift | idempotency-key-missing |
                   rate-limit-header-drift | rate-limit-enforcement-missing |
                   etag-conditional-drift | optimistic-concurrency-missing |
                   batch-endpoint-contract-drift | field-selection-drift |
                   security-header-drift | log-field-drift |
                   metric-name-drift | trace-span-drift |
                   timeout-policy-drift | retry-policy-drift |
                   openapi-coverage-gap | example-coverage-gap>
endpoint: <method + path, e.g., "POST /orders">
file: <controller-or-handler-path:line>
canonical: <what the project's convention says — the envelope shape / naming / etc.>
divergence: <what this endpoint does differently>
closure_verb: <one of the verbs below>
risk: low | medium | high
```

## The 21 detectors

### 1. response-envelope-drift

**Fingerprint**: endpoints return different top-level shapes for the same conceptual response.

Common shapes the project might pick as canonical (one of):
- `{ data, meta, errors }` (JSON:API-ish)
- `{ data, pagination }` (Atlassian-ish)
- bare resource (no envelope at all — also valid IF consistent)

Drift: mixing them. Example: `GET /orders` returns `{ data: [...], meta: {...} }` but `GET /customers` returns `[...]` directly.

**Detection**: parse OpenAPI response schemas OR static-analyse controller return types. Cluster by shape. Anything not in the dominant cluster is drift.

**Closure verb**: `unify-envelope` — wrap responses in the canonical shape. Ships through additive flow first (add wrapped variant alongside; deprecate bare; remove in next major).

### 2. error-contract-drift

**Fingerprint**: 4xx/5xx responses have different shapes across endpoints.

Common canonical shapes:
- RFC 9457 (obsoletes RFC 7807, 2023) Problem Details — `{ type, title, status, detail, instance, errors? }` served as `application/problem+json`. The `type` is a stable, dereferenceable URI per error class (e.g. `https://errors.acme.com/insufficient-funds`), NOT the human-readable `title`.
- `{ error, code, message, details? }`
- `{ message, code }`

Drift: some endpoints return `{ error: "msg" }`, others `{ message: "msg" }`, others throw raw stack traces in the body.

**Detection**: cluster 4xx/5xx body schemas by shape. When the canonical is Problem Details, the fingerprint is BOTH the body keys AND the `Content-Type` — an endpoint that returns the right keys but `application/json` (not `application/problem+json`), or uses `type` as a free-text title rather than a stable URI, is drift. Flag any error path emitting a raw stack trace / framework default body.

**Closure verb**: `unify-error-contract`.

### 3. naming-convention-drift

**Fingerprint**: response/request field names mix `camelCase` and `snake_case` across endpoints (or `PascalCase` etc.).

**Detection**: extract every field name from request/response schemas; classify case style. If the mix isn't 100% one style, drift.

**Closure verb**: `unify-naming` — picks the project's canonical case (from `_extracted-idioms.md`) and renames others. Ships with serializer mapping for breaking-change protection.

### 4. pagination-drift

**Fingerprint**: list endpoints use different pagination styles:
- `?cursor=<opaque>` (cursor-based)
- `?page=<n>&limit=<n>` (offset/limit)
- `?offset=<n>&limit=<n>` (raw offset)
- `?after=<id>` / `?before=<id>` (keyset)

Drift: mixing. The project's `api-conventions.md` should declare ONE canonical style.

**Closure verb**: `unify-pagination`.

### 5. versioning-drift

**Fingerprint**: endpoints prefixed `/v1/` and `/v2/` coexisting without documented deprecation OR with overlapping responsibility (same conceptual operation in both).

**Detection**: route table; flag mixed prefixes; cross-check `_extracted-idioms.md § Deprecations`.

**Closure verb**: `unify-versioning` (declares which is canonical; surfaces the deprecation plan for the other).

### 6. auth-header-drift

**Fingerprint**: some endpoints expect `Authorization: Bearer <token>`, others `X-API-Key: <key>`, others a custom header. Mixed within the same API.

**Closure verb**: `unify-auth-header`.

### 7. idempotency-key-missing

**Fingerprint**: write endpoints (POST/PUT/PATCH/DELETE) don't accept an `Idempotency-Key` header where the project's convention requires it. Especially critical for payment/order creation.

**Detection**: per-method scan; cross-check `api-conventions.md § Idempotency` (if the project requires it).

**Closure verb**: `add-idempotency-key`.

### 8. rate-limit-header-drift

**Fingerprint**: some endpoints expose `X-RateLimit-Limit` / `X-RateLimit-Remaining` / `X-RateLimit-Reset`, others don't. Or naming drift in the headers themselves (`X-Rate-Limit-*` vs `RateLimit-*` standard).

**Closure verb**: `unify-rate-limit-headers`.

### 8b. rate-limit-enforcement-missing

**Fingerprint**: sibling to `rate-limit-header-drift` (#8) — that one checks header NAMING; this one checks whether a limiter is WIRED AT ALL. A mutating (`POST`/`PUT`/`PATCH`/`DELETE`) or expensive-read endpoint (search, export, report, fan-out, fuzzy/`LIKE` query) has NO limiter middleware/decorator on its path while sibling endpoints do.

**Detection**: per route, look for an inbound limiter binding — middleware in the chain (`rateLimit(...)`, `@Throttle`, `throttle:`, `RateLimiterMiddleware`, gateway/Kong/Envoy `rate-limit` plugin) OR a decorator/guard. Cluster routes that HAVE one; any mutating/expensive route NOT in that cluster (and not explicitly exempted in `api-conventions.md § Rate limiting`) is drift. Emits e.g. `POST /reports/export` at `src/reports/reports.controller.ts:88` — no limiter, while `POST /orders` at `src/orders/orders.controller.ts:41` carries `@Throttle({ default: { limit: 20, ttl: 60000 } })`.

**Detection (always-on hook)**: an unlimited mutating endpoint is also a server-side resilience gap, not just a uniformity gap — flag it even when NO sibling has a limiter (the cluster is empty). The enforcement SHAPE (429 + `Retry-After` + unprefixed `RateLimit-*` headers, per-tenant buckets over a shared store, FAIL-OPEN vs FAIL-CLOSED on store outage, 503 admission control) is OWNED by `ai-patterns/rate-limiting.md` — point there; do NOT re-specify the algorithm here. 429 = RFC 6585; `Retry-After` = RFC 9110 §10.2.3; `RateLimit-*` / `RateLimit-Policy` = IETF draft-ietf-httpapi-ratelimit-headers (a DRAFT, not an RFC).

**Closure verb**: `add-rate-limiter` (wire the limiter per `ai-patterns/rate-limiting.md`; do NOT hand-roll a new shape).

### 8c. etag-conditional-drift

**Fingerprint**: a cacheable `GET` (single-resource read, or a list with a stable representation) returns no `ETag` (and no `Last-Modified`) while sibling reads do — so clients can't revalidate. Conversely, an endpoint emits an `ETag` but ignores `If-None-Match`, never returning `304 Not Modified`.

**Detection**: per `GET` route, check the response builder for an `ETag`/`Last-Modified` header and the handler for `If-None-Match` short-circuit logic. Cluster reads that revalidate; cacheable siblings outside the cluster are drift. Emits e.g. `GET /orders/:id` at `src/orders/orders.controller.ts:120` — no `ETag`, while `GET /customers/:id` at `src/customers/customers.controller.ts:96` sets `res.setHeader('ETag', weakEtag(body))` and returns `304` on match.

**Detection (pointer)**: the revalidation contract (strong vs weak ETag, `If-None-Match` → `304`, RFC 9110 obsoletes RFC 7232) is OWNED by `ai-patterns/conditional-requests.md` — point there for the exact handling.

**Closure verb**: `add-etag-revalidation`.

### 8d. optimistic-concurrency-missing

**Fingerprint**: a write endpoint (`PUT`/`PATCH`/`DELETE`) targets a resource whose model carries a concurrency token — a `version` / `row_version` / `etag` / `updated_at` column — but the handler accepts NO `If-Match` precondition, so concurrent writers silently last-write-wins (lost update).

**Detection**: cross-reference the route's target model (from the ORM entity / migration) for a version/`updated_at` column against the handler's request parsing for `If-Match`. A write with the column but no precondition check is drift; bonus-flag handlers that don't return `412 Precondition Failed` on mismatch or `428 Precondition Required` when the project mandates the header. Emits e.g. `PATCH /documents/:id` at `src/documents/documents.controller.ts:64` — model `Document` has `version` (`migrations/0007_documents.sql:12`) but no `If-Match` read.

**Detection (pointer)**: the over-HTTP optimistic-concurrency contract (`If-Match` → `412`, `428 Precondition Required`, RFC 9110) is OWNED by `ai-patterns/conditional-requests.md`. The DB-side stored-version replay / compare-and-swap belongs to the distributed-systems pack (`stored-idempotency-replay`) — point there, do not duplicate.

**Closure verb**: `add-if-match-precondition`.

### 8e. batch-endpoint-contract-drift

**Fingerprint**: a route accepts an ARRAY body (bulk create/update/delete) but returns a single scalar status for the whole batch — `200`/`204` with no per-item result — so a caller can't tell WHICH items succeeded and which failed. Partial failure is invisible.

**Detection**: per route, detect array-shaped request bodies (OpenAPI `type: array`, or handler iterating the parsed body). Check the response schema for a sibling per-item status array (e.g. `{ results: [{ id, status, error? }, ...] }`) and/or a `207 Multi-Status`-style envelope. A batch route returning a bare scalar is drift. Emits e.g. `POST /orders/bulk` at `src/orders/orders.controller.ts:152` — accepts `Order[]`, returns `201` with no `results[]`, while `POST /invoices/bulk` at `src/invoices/invoices.controller.ts:71` returns `{ results: [{ index, id, status }] }`.

**Closure verb**: `add-batch-item-status` — return a per-item status array (stable order or explicit `index`) so partial failure is addressable. Ships additively (add `results[]` alongside the existing status; deprecate the bare shape).

### 8f. field-selection-drift

**Fingerprint** (opt-in — fires ONLY if `api-conventions.md § Field selection` declares a `?fields=` / `?expand=` / sparse-fieldset convention): some list/detail endpoints honour `?fields=`/`?expand=` (sparse fieldsets / relation expansion) while sibling endpoints silently ignore the param and return the full representation.

**Detection**: skip entirely unless the convention is declared. When declared, per read route check the handler for parsing of the declared param (projection / expansion logic). Cluster endpoints that honour it; sibling reads of comparable resources that ignore it are drift. Emits e.g. `GET /customers` at `src/customers/customers.controller.ts:40` honours `?fields=`, but `GET /orders` at `src/orders/orders.controller.ts:33` ignores it and returns all columns.

**Detection (pointer)**: the underlying `SELECT *` / over-fetch at the data layer is OWNED by the database pack — point there; this detector only flags the HTTP-surface UNIFORMITY of the param contract.

**Closure verb**: `unify-field-selection`.

### 8g. security-header-drift

**Fingerprint** (low weight — presence-UNIFORMITY only): some response paths set baseline security headers (`X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `X-Frame-Options` / CSP) while others omit them, so the header set is inconsistent across the surface.

**Detection**: sample response headers across route groups (global middleware vs per-route overrides that strip/skip the security middleware). Flag groups whose responses lack a header that the majority of paths set. This detector asserts ONLY uniformity of presence — it does NOT define which headers are required, their values, or threat coverage. The security-header POLICY (which headers, correct values, HSTS max-age/preload, CSP shape) is OWNED by the security pack (`security-headers`) — point there.

**Closure verb**: `unify-security-headers` — apply the missing baseline header at the shared response layer so every path is uniform; defer value/policy decisions to the security pack.

### 9. log-field-drift

**Fingerprint**: structured logs use different field names for the same concept across endpoints.

Common drifts:
- `userId` vs `user_id` vs `uid`
- `orderId` vs `order_id` vs `oid`
- `requestId` vs `req_id` vs `correlation_id` vs `trace_id`

**Detection**: scan all `log.info(...)` / `logger.warn(...)` / similar calls; extract structured fields; classify by concept; flag drift.

**Closure verb**: `unify-log-fields` — applies the project's canonical name from `_extracted-idioms.md § Logging`.

### 10. metric-name-drift

**Fingerprint**: counters / histograms / gauges named inconsistently for similar concepts.

Common drifts:
- `orders.created` vs `OrderCreated` vs `order_created_total` vs `orders_created`
- Different unit suffixes (`_ms` vs `_seconds` vs none)

**Detection**: scan metric registration; classify by concept; flag drift.

**Closure verb**: `unify-metric-names`.

### 11. trace-span-drift

**Fingerprint**: tracing spans for similar operations have different names / attributes.

Common drifts:
- `db.query` vs `database.fetch` vs `repo.read`
- Some spans tagged with `db.statement`, others not.

**Closure verb**: `unify-trace-spans`.

### 12. timeout-policy-drift

**Fingerprint**: per-endpoint or per-client timeout values differ wildly without documented reason. Some endpoints 30s, others 5s, others infinite.

**Detection**: scan client / server config + middleware; cluster by service tier (per-tier different timeouts is OK; within-tier drift is not).

**Closure verb**: `unify-timeout-policy`.

### 13. retry-policy-drift

**Fingerprint**: retry counts / backoff strategies differ across similar call sites without documented reason.

**Closure verb**: `unify-retry-policy`.

### 14. openapi-coverage-gap

**Fingerprint**: an endpoint exists in the route table but isn't in the OpenAPI spec.

**Detection**: route registry minus OpenAPI paths.

**Closure verb**: `add-openapi-doc`.

### 15. example-coverage-gap

**Fingerprint**: endpoint is in OpenAPI but has no `examples` for request/response. (Or a single trivial example that doesn't reflect real-world payloads.)

**Closure verb**: `add-endpoint-example`.

## Procedure (step-by-step)

1. **Pre-flight**:
   - `PROJECT_KIND` matches `backend-*`. Halt otherwise (this skill is backend-only).
   - `_extracted-idioms.md § API conventions` OR `ai/api-conventions.md` exists. Halt if missing — without canonical conventions, drift is undefined.
   - OpenAPI spec discoverable (warn-only if missing; openapi-coverage detector skips).
2. **Build endpoint registry** — walk controllers / route table; emit one row per `{method, path, file, line}`.
3. **For each detector** (1–15 + siblings 8b–8g above):
   - Apply the detector's fingerprint procedure across the registry.
   - Emit findings.
4. **Cross-cutting check** — if a finding's closure verb would break a public contract (rename a response field; change envelope shape), flag `risk: high` and require ADR.
5. **Write artifact** — `ai/polish/_api-decisions.md` with all findings grouped by subclass.

## Hard rules

- **Behaviour-preserving** — closure verbs that rename / unify ship via deprecation flow (additive change first, deprecation header, removal in next major). Blind rewrites are forbidden — they break clients.
- **Per-endpoint commit** — one finding = one commit (except for naming-convention-drift sweeps where a single mass-rename commit is acceptable when wired through serializer mapping).
- **OpenAPI must stay in sync** — every code change updates the spec in the same commit.
- **Contract tests must stay green** — if the project has them.
- **No detector invents new conventions** — the canonical shape always comes from `_extracted-idioms.md § API conventions`. If that file says nothing about envelope/naming/etc., the detector skips with WARN.

## Failure modes

- **`api-conventions.md` missing** → halt; surface "/setup-project --refine to declare API conventions first".
- **OpenAPI spec missing** → warn; skip openapi-coverage + example-coverage detectors.
- **Conflicting conventions** (e.g., `api-conventions.md` says snake_case but `_extracted-idioms.md` says camelCase) → halt; surface conflict for user resolution.
- **High-risk closure** (would break public contract) → flag, halt that finding, surface ADR template; rest continue.

## References

- `_extracted-idioms.md § API conventions` (project-specific oracle).
- `ai/api-conventions.md` (alternative location).
- `align-discipline.md` — closed-vocabulary closure-verb discipline.
- `polish` command — dispatches this skill on backend stacks.
- `ai-patterns/rate-limiting.md` — server-side inbound limit + load shedding (429 + `Retry-After` + `RateLimit-*` headers; per-tenant buckets; shared store; FAIL-OPEN/CLOSED; 503 admission control). Owner of the `add-rate-limiter` shape (8b).
- `ai-patterns/conditional-requests.md` — `ETag`/`If-None-Match` → `304` (read revalidation) + `If-Match` → `412` / `428` (optimistic concurrency over HTTP); RFC 9110. Owner of 8c + 8d.
- `ai-patterns/response-streaming.md` — NDJSON/SSE/chunked for unbounded results; mid-stream terminal error sentinel; backpressure; disconnect cancellation; RFC 9112. Consider when a list/export route would otherwise return an unbounded body.
- `ai-patterns/async-job-offload.md` — `202 Accepted` + `Location` + status URL; job-status state machine; idempotent submit; result TTL. Consider for the expensive endpoints surfaced by 8b instead of holding a synchronous connection.
