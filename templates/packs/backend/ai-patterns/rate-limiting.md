---
name: rate-limiting
description: 'Pattern: Rate Limiting & Load Shedding'
kind: ai-pattern
pack: backend
---

# Pattern: Rate Limiting & Load Shedding

> **Hard rule:** Every public or expensive endpoint enforces a limit keyed on a stable identity (tenant / user / API-key / IP), returns `429` + `Retry-After` + `RateLimit-*` headers when exceeded, and sits behind a bounded in-flight admission limit that sheds `503` BEFORE the connection pool / queue saturates. A multi-instance deploy with an in-memory counter is unprotected — the limit resets per pod. This pattern is INBOUND self-protection; outbound resilience (circuit breaker, bulkhead) is owned by the distributed-systems pack.

**When to apply**
- Any unauthenticated endpoint (login, signup, password-reset, public search) — abuse + credential-stuffing surface.
- Expensive endpoints regardless of auth: search, export, report, bulk, file upload, LLM/inference, anything fanning out to a DB or third party.
- Multi-tenant APIs where one tenant's burst must not starve others.
- Any endpoint where the cost-to-call is asymmetric (cheap for the client, expensive for you).

**When NOT to apply**
- Internal service-to-service calls behind a private network with their own concurrency budget (use bulkhead/quota at the mesh, not per-request 429s).
- A single-tenant internal tool with trusted users and no abuse surface — document the decision; don't add ceremony.
- Static/cached assets served by the CDN — the edge owns that limit (infrastructure pack).

**Halt conditions / mandatory cites**
- A mutating or expensive route with no limiter middleware/decorator MUST be flagged at `<path:line>` — "looks rate-limited" is not a finding.
- A `429` returned without `Retry-After` AND `RateLimit-Limit/Remaining/Reset` is incomplete — cite the response builder.
- A single shared global counter on a per-tenant API is a fairness bug — cite it; per-tenant bucket required.
- An in-memory limiter (`Map`, local LRU) on a deploy with >1 instance MUST cite the deploy topology that breaks it.
- The store-unreachable behavior (FAIL-OPEN vs FAIL-CLOSED) MUST be an explicit, documented decision — an undocumented `try/catch → allow` is a silent bypass.

## Algorithm decision table

| Algorithm | Burst behavior | Memory | Accuracy | Use when |
|---|---|---|---|---|
| **Fixed window** | Allows 2× burst at window edges | 1 counter/key | Low | Coarse, cheap, non-critical |
| **Sliding window counter** | Smooths the edge (weighted prev+current) | 2 counters/key | Good | **Default** — cheap + accurate enough |
| **Sliding window log** | Exact | 1 sorted set/key (O(n) mem) | Exact | Low-volume, billing-grade precision |
| **Token bucket** | Allows controlled burst up to bucket size, steady refill | 2 fields/key | Good | APIs that should tolerate short bursts |
| **GCRA / leaky bucket** | Smooth, no burst | 1 timestamp/key | Exact | Strict steady-rate (e.g. `redis-cell` `CL.THROTTLE`) |

Default to **sliding-window-counter** or **token-bucket**; reach for log/GCRA only when precision or strict smoothing justifies the cost.

## Key dimension — what to limit by

| Dimension | Key | Use when |
|---|---|---|
| Per-IP | `ratelimit:ip:<ip>` | Unauthenticated endpoints; coarse abuse defense (beware shared NAT / proxies — use the real client IP) |
| Per-user | `ratelimit:user:<id>` | Authenticated per-user fairness |
| Per-API-key | `ratelimit:key:<keyId>` | Public/partner APIs with issued keys |
| Per-tenant | `ratelimit:tenant:<id>:<route>` | **Multi-tenant fairness — never a shared global counter** |
| Per-route | suffix `:<method>:<route>` | Different cost ceilings per endpoint |

**Multi-tenant rule:** each tenant gets its OWN bucket. A global counter lets one noisy tenant exhaust the limit for everyone — that's a fairness/availability bug, not a limit.

## Distributed counter store

- The counter MUST live in a **shared store** (Redis/Valkey, or the DB for low volume) — never process memory on a multi-instance deploy.
- Make the check-and-increment **atomic**: a Redis Lua script, or `redis-cell`'s `CL.THROTTLE` (GCRA in one round-trip). A read-then-write race over-admits under load.
- Set a **key TTL** = window length so idle keys expire (no unbounded memory).
- **Clock skew:** anchor windows to the store's clock (or `TIME`), not each pod's wall clock.
- **Store unreachable — decide explicitly:** FAIL-OPEN (allow, preserve availability — typical for a soft limit) vs FAIL-CLOSED (deny, preserve protection — typical for login/abuse). Document which, and emit a metric when the fallback fires.

## Response contract

```
HTTP/1.1 429 Too Many Requests          (RFC 6585)
Retry-After: 30                          (seconds OR HTTP-date — RFC 9110 §10.2.3)
RateLimit-Limit: 100
RateLimit-Remaining: 0
RateLimit-Reset: 30                      (seconds until the window resets)
RateLimit-Policy: 100;w=60               (IETF draft-ietf-httpapi-ratelimit-headers — a DRAFT, not an RFC)
Content-Type: application/problem+json

{ "type": "https://errors.example/rate-limit", "title": "Too Many Requests",
  "status": 429, "code": "RATE_LIMITED", "detail": "Limit 100/min exceeded", "retryAfter": 30 }
```

- Prefer the unprefixed `RateLimit-*` (standardizing draft) over legacy `X-RateLimit-*`; if you must keep `X-RateLimit-*` for existing clients, emit BOTH during migration.
- The `429` body uses the project's error envelope (`error-handling.md`) or `application/problem+json` (`RFC 9457`).
- **Always set `Retry-After` on `429` AND `503`** — clients back off deterministically instead of hammering.

## Quotas vs rate limits

- **Rate limit** = requests per short window (per-second/minute) — protects infrastructure. Exceed → `429` + `Retry-After`.
- **Quota** = plan allowance per long period (per-day/month) — a billing/entitlement concept. Exceed → `429` (or `402 Payment Required` if it's a paid-plan upgrade path). Track separately; surface remaining quota in `RateLimit-*` or a plan-specific header.

## Load shedding / admission control

Rate limits cap a single caller; **load shedding** protects the whole process when aggregate load exceeds capacity (a thundering herd of *new* tenants each under their own limit can still saturate you).

- Put a **bounded-concurrency semaphore** + **bounded queue depth** in front of expensive work. When in-flight ≥ ceiling and the queue is full, reject overflow with `503 Service Unavailable` + `Retry-After` rather than accepting work that will time out anyway.
- **Priority-aware shedding:** exempt health/readiness probes; shed low-priority/background traffic before user-facing requests.
- Size the ceiling from a real number (pool size, downstream capacity), cited — not a guess.

## Detectors (cite-or-halt)

- `grep` route decorators/handlers for expensive paths (`/search`, `/export`, `/report`, `/bulk`, `/upload`, LLM endpoints) with NO limiter middleware/decorator → `add-rate-limit`.
- `429` constructed without `Retry-After`/`RateLimit-*` → `emit-ratelimit-headers`.
- A single global counter key (no tenant/user/IP segment) on a multi-tenant API → `add-per-tenant-quota`.
- In-memory limiter (`new Map`, `lru-cache`) where the deploy runs >1 replica → cite the topology; move to the shared store.
- Expensive synchronous fan-out with no concurrency cap / queue bound → `add-load-shedding`.

**Closure verbs:** `add-rate-limit`, `add-per-tenant-quota`, `add-load-shedding`, `emit-ratelimit-headers`.

## Framework bindings (stack-agnostic core above; specifics here)

| Stack | Limiter |
|---|---|
| NestJS | `@nestjs/throttler` (+ `@nestjs/throttler-storage-redis` for multi-instance) |
| Express | `express-rate-limit` + `rate-limit-redis` |
| Fastify | `@fastify/rate-limit` (Redis store) |
| FastAPI | `slowapi` or `fastapi-limiter` (Redis) |
| Django / DRF | `django-ratelimit` / DRF throttling classes |
| Rails | `rack-attack` |
| Laravel | `ThrottleRequests` middleware (`throttle:60,1`) |
| Spring Boot | Bucket4j / Resilience4j `RateLimiter` |
| .NET | `Microsoft.AspNetCore.RateLimiting` (fixed/sliding/token/concurrency) |
| Go | `golang.org/x/time/rate` / `tollbooth` |
| Phoenix/Elixir | `Hammer` / `PlugAttack` |

Record the chosen limiter + store in `references/<framework>.md`.

## Forbidden

- An unauthenticated or expensive endpoint with no enforced limit.
- `429` without `Retry-After`.
- A shared global counter on a multi-tenant API (fairness bug).
- An in-memory limiter on a horizontally-scaled deploy.
- Silent FAIL-OPEN on store errors with no metric and no documented decision.
- Accepting work into an unbounded queue instead of shedding `503` at the ceiling.
