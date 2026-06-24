---
name: rate-limiting
description: 'Pattern: Rate Limiting & Load Shedding'
kind: ai-pattern
pack: backend
---

# Pattern: Rate Limiting & Load Shedding

> **Hard rule:** Every public or expensive endpoint enforces a limit keyed on a stable identity (tenant / user / API-key / IP), returns `429` + `Retry-After` + `RateLimit-*` headers when exceeded, and sits behind a bounded in-flight admission limit that sheds `503` BEFORE the pool / queue saturates. A multi-instance deploy with an in-memory counter is unprotected — the limit resets per pod. Inbound self-protection only; outbound resilience is owned by the distributed-systems pack.

**When to apply** — any unauthenticated endpoint (login/signup/reset/public search), any expensive endpoint (search/export/report/bulk/upload/LLM), and multi-tenant APIs where one tenant's burst must not starve others.

**Halt conditions / mandatory cites**
- A mutating/expensive route with no limiter MUST be cited at `<path:line>` — "looks limited" is not a finding.
- `429` without `Retry-After` AND `RateLimit-Limit/Remaining/Reset` is incomplete.
- A single shared global counter on a per-tenant API is a fairness bug — per-tenant bucket required.
- The store-unreachable behavior (FAIL-OPEN vs FAIL-CLOSED) MUST be an explicit, documented decision.

## Algorithm decision table

| Algorithm | Burst | Memory | Accuracy | Use when |
|---|---|---|---|---|
| Fixed window | 2× at edges | 1 counter | Low | Coarse, cheap |
| **Sliding window counter** | Smoothed | 2 counters | Good | **Default** |
| Sliding window log | Exact | sorted set | Exact | Billing-grade precision |
| Token bucket | Controlled burst | 2 fields | Good | Tolerate short bursts |
| GCRA / leaky bucket | Smooth | 1 timestamp | Exact | Strict steady-rate (`redis-cell CL.THROTTLE`) |

## Key dimension

| Dimension | Key | Use when |
|---|---|---|
| Per-IP | `ratelimit:ip:<ip>` | Unauthenticated (beware shared NAT) |
| Per-user / per-API-key | `ratelimit:user:<id>` / `:key:<id>` | Authenticated / partner APIs |
| Per-tenant | `ratelimit:tenant:<id>:<route>` | **Multi-tenant fairness — never a shared global counter** |

## Distributed counter store

- Counter lives in a **shared store** (Redis/Valkey/DB) — never process memory on a multi-instance deploy.
- **Atomic** check-and-increment (Redis Lua / `CL.THROTTLE`) — a read-then-write race over-admits.
- Key TTL = window length; anchor windows to the store clock (skew).
- **Store down — decide explicitly:** FAIL-OPEN (availability) vs FAIL-CLOSED (protection); emit a metric when the fallback fires.

## Response contract

```
HTTP/1.1 429 Too Many Requests           (RFC 6585)
Retry-After: 30                           (seconds or HTTP-date — RFC 9110 §10.2.3)
RateLimit-Limit: 100
RateLimit-Remaining: 0
RateLimit-Reset: 30
RateLimit-Policy: 100;w=60                (IETF draft-ietf-httpapi-ratelimit-headers — a DRAFT, not an RFC)
```

Prefer unprefixed `RateLimit-*` over legacy `X-RateLimit-*`. The `429` body uses the project envelope or `application/problem+json` (RFC 9457). Always set `Retry-After` on `429` AND `503`.

## Quotas vs rate limits

- **Rate limit** = req/short-window — protects infra → `429`.
- **Quota** = plan allowance/long-period — billing → `429` (or `402` on a paid-plan path). Track separately.

## Load shedding / admission control

Rate limits cap one caller; load shedding protects the whole process. Put a **bounded-concurrency semaphore + bounded queue** before expensive work — at the ceiling, reject overflow with `503` + `Retry-After`. Priority-aware: exempt health probes, shed low-priority first. Size the ceiling from a real number (pool size), cited.

## Detectors (cite-or-halt)

- Expensive route (`/search`/`/export`/`/report`/`/bulk`/`/upload`/LLM) with no limiter → `add-rate-limit`.
- `429` without `Retry-After`/`RateLimit-*` → `emit-ratelimit-headers`.
- Single global counter on a multi-tenant API → `add-per-tenant-quota`.
- In-memory limiter on >1 replica → cite topology; move to shared store.
- Expensive fan-out with no concurrency cap / queue bound → `add-load-shedding`.

**Closure verbs:** `add-rate-limit`, `add-per-tenant-quota`, `add-load-shedding`, `emit-ratelimit-headers`.

## Framework bindings

| Stack | Limiter |
|---|---|
| NestJS | `@nestjs/throttler` (+ `-storage-redis`) |
| Express | `express-rate-limit` + `rate-limit-redis` |
| FastAPI | `slowapi` / `fastapi-limiter` |
| Django/DRF | `django-ratelimit` / DRF throttling |
| Rails | `rack-attack` |
| Laravel | `ThrottleRequests` |
| Spring | Bucket4j / Resilience4j |
| .NET | `Microsoft.AspNetCore.RateLimiting` |
| Go | `golang.org/x/time/rate` / `tollbooth` |

## Forbidden

- An unauthenticated/expensive endpoint with no enforced limit.
- `429` without `Retry-After`.
- A shared global counter on a multi-tenant API.
- An in-memory limiter on a horizontally-scaled deploy.
- Silent FAIL-OPEN on store errors with no metric / no documented decision.
- Accepting work into an unbounded queue instead of shedding `503`.
