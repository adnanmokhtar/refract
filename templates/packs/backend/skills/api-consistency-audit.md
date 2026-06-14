---
name: api-consistency-audit
description: API surface consistency audit. Detects drift across endpoints in: response envelope shape, error contract, pagination convention, naming case (snake/camel), idempotency-key coverage, auth header convention, rate-limit header coverage, log-field naming, metric/trace naming, OpenAPI documentation coverage, timeout/retry policy uniformity. Emits one finding per drift fingerprint with <path:line> evidence + closure verb. Used by /polish on backend-* stacks. Behaviour-preserving (envelope unification + naming changes ship through deprecation flow, not blind rewrite).
kind: skill
pack: backend
---

# Skill: api-consistency-audit

## Purpose

Detect drift across the project's API surface so /polish can unify it. The skill operates on the deployed contract (OpenAPI spec, route table, controller signatures, response builders) and the project's conventions (`_extracted-idioms.md § API conventions` or `ai/api-conventions.md`).

This skill is the API-half of /polish (the frontend half is the design-token / a11y / motion suite).

## When to use

- Dispatched by `/polish` on `backend-*` stacks.
- Dispatched by `/api-audit` (read-only audit, if the project has it).
- Standalone: `/polish --diagnose-only --stack=backend` writes the artifact, no fixes.
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
                   rate-limit-header-drift | log-field-drift |
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

## The 15 detectors

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
- RFC 7807 problem+json: `{ type, title, status, detail, instance, errors? }`
- `{ error, code, message, details? }`
- `{ message, code }`

Drift: some endpoints return `{ error: "msg" }`, others `{ message: "msg" }`, others throw raw stack traces in the body.

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
3. **For each detector** (1–15 above):
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
