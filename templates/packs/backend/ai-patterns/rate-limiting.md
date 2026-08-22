---
name: rate-limiting
description: 'Pattern: Rate Limiting & Load Shedding'
kind: ai-pattern
pack: backend
---

# Pattern: Rate Limiting & Load Shedding

> **Hard rule:** Every public or expensive endpoint enforces a limit keyed on a stable identity (tenant / user / API-key / IP), returns `429` + `Retry-After` + the `RateLimit` / `RateLimit-Policy` quota fields when exceeded, and sits behind a bounded in-flight admission limit that sheds `503` BEFORE the connection pool / queue saturates. A multi-instance deploy with an in-memory counter is unprotected — the limit resets per pod. This pattern is INBOUND self-protection; outbound resilience (circuit breaker, bulkhead) is owned by the distributed-systems pack.

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
- A `429` returned without `Retry-After` AND a quota field (`RateLimit`, or the legacy triple while clients migrate) is incomplete — cite the response builder.
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

Default to **sliding-window-counter** or **token-bucket** — and the choice between those two is decided by the traffic shape, not by taste, because the table's own columns (burst / memory / accuracy) do not separate them:

- **Token bucket** when the caller legitimately arrives in bursts and goes quiet — automation, CI, a sync worker, an agent completing one task. Bucket size *is* the permitted burst, and the refill rate is the sustained allowance; you can grant both independently, which is the whole reason to reach for it.
- **Sliding-window counter** when traffic is a steady human trickle and what you actually care about is that no window ever admits materially more than the quota. Its job is to remove the fixed window's 2× edge artefact; it has no burst allowance to tune, which is a feature when you did not want to grant one.

**When both fit, pick sliding-window counter** — one fewer parameter to size wrong, and a mis-sized bucket is a silent limit that never fires. When you cannot characterise the traffic yet, that is the finding: measure the calls-per-caller-per-minute distribution first (§ Caller class), because the two algorithms fail in opposite directions on the shape you guessed wrong.

## Key dimension — what to limit by

| Dimension | Key | Use when |
|---|---|---|
| Per-IP | `ratelimit:ip:<ip>` | Unauthenticated endpoints; coarse abuse defense (beware shared NAT / proxies — use the real client IP) |
| Per-user | `ratelimit:user:<id>` | Authenticated per-user fairness |
| Per-API-key | `ratelimit:key:<keyId>` | Public/partner APIs with issued keys |
| Per-tenant | `ratelimit:tenant:<id>:<route>` | **Multi-tenant fairness — never a shared global counter** |
| Per-route | suffix `:<method>:<route>` | Different cost ceilings per endpoint |
| Per-caller-class | `ratelimit:class:<human\|automation>:<id>` | The API is called by autonomous agents as well as humans — see below |

**Caller class is a dimension, not a key detail.** If an API is consumed by autonomous agents (an LLM tool-caller, a CI job, a sync worker) as well as by a UI, the two traffic shapes differ: a UI produces a slow trickle of user-initiated calls, an agent completing one task produces a tight burst of sequential calls and then goes silent. A fixed window sized for the trickle rejects the burst; a fixed window sized for the burst is no limit at all for the trickle. Token bucket handles both (burst capacity + steady refill) — which is the concrete reason to reach for it here rather than a stylistic preference. **Do not import a number for this.** Measure your own calls-per-task distribution before choosing bucket size; the shape is workload-specific and any figure quoted without your telemetry behind it is a guess.

**Multi-tenant rule:** each tenant gets its OWN bucket. A global counter lets one noisy tenant exhaust the limit for everyone — that's a fairness/availability bug, not a limit.

## Distributed counter store

- The counter MUST live in a **shared store** (Redis/Valkey, or the DB for low volume) — never process memory on a multi-instance deploy.
- Make the check-and-increment **atomic**: a Redis Lua script, or `redis-cell`'s `CL.THROTTLE` (GCRA in one round-trip). A read-then-write race over-admits under load.
- Set a **key TTL** = window length so idle keys expire (no unbounded memory).
- **Clock skew:** anchor windows to the store's clock (or `TIME`), not each pod's wall clock.
- **Store unreachable — decide explicitly:** FAIL-OPEN (allow, preserve availability — typical for a soft limit) vs FAIL-CLOSED (deny, preserve protection — typical for login/abuse). Document which, and emit a metric when the fallback fires.

## Response contract

```
HTTP/1.1 429 Too Many Requests            (RFC 6585)
Retry-After: 30                           (seconds OR HTTP-date — RFC 9110 §10.2.3)
RateLimit-Policy: "default";q=100;w=60    (q = quota units, REQUIRED; w = window seconds;
                                           qu = requests|content-bytes|concurrent-requests; pk = partition key)
RateLimit: "default";r=0;t=30             (r = remaining quota units, REQUIRED; t = seconds to reset;
                                           pk = partition key)
Content-Type: application/problem+json

{ "type": "https://iana.org/assignments/http-problem-types#quota-exceeded",
  "title": "Too Many Requests", "status": 429, "detail": "Limit 100/min exceeded" }
```

### The transition rule (read before you copy the block above)

`draft-ietf-httpapi-ratelimit-headers-11` (23 May 2026) defines **exactly two** fields — `RateLimit-Policy` and `RateLimit` — both RFC 9651 Structured Fields, both carrying a **quoted policy name** and named parameters. The `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset` triple this pack shipped previously is **draft-05 legacy**: the current revision does not define it.

Three facts have to travel together, or the guidance is dishonest in one direction or the other:

1. **The draft is not settled.** It is an Internet-Draft (`IESG State: I-D Exists`), and the HTTPDIR early review of `-10` (Lucas Pardue, 16 Jan 2026) came back **"Not ready"**. Pin no contract to it as though it were an RFC.
2. **The legacy triple is still deployed reality.** Clients written against draft-05 read `RateLimit-Remaining`. So do a lot of SDKs.
3. **Vendor `X-RateLimit-*` is still what large public APIs ship.** Unprefixed is the direction of travel, not the installed base.

**Therefore: emit the two-field form AND the triple during transition.** Both are cheap (a few bytes); a client that understands neither reads `Retry-After`, which is the only field here that is unambiguously standardised. Drop the triple when your own client telemetry says nothing reads it — not on a draft's publication date.

- The `429` body uses the project's error envelope (`error-handling.md`) or `application/problem+json` (RFC 9457).
- **Always set `Retry-After` on `429` AND `503`** — clients back off deterministically instead of hammering. This is the field to get right first; it is the one with an RFC behind it.

## Problem types for the body (RFC 9457)

The draft registers three problem types, each carrying a `violated-policies` extension member naming the policies that were exceeded. Use them as the `type` URI when the body is `application/problem+json`; keep the project's own `code` mapped 1:1 to the URI so the two representations never diverge (`error-handling.md` § References).

| `type` URI | Status | Emit when |
|---|---|---|
| `https://iana.org/assignments/http-problem-types#quota-exceeded` | 429 | The caller's own limit or quota was exceeded — the ordinary case. |
| `https://iana.org/assignments/http-problem-types#temporary-reduced-capacity` | 503 | **The load-shedding path below.** Aggregate load exceeded capacity and this request was shed; the caller did nothing wrong. This is the type for §Load shedding's `503`, and the reason to prefer it over a bare `503`: it tells the client "back off, but you are not the problem", which is different advice from `#quota-exceeded`. |
| `https://iana.org/assignments/http-problem-types#abnormal-usage-detected` | 429 | Traffic matched an abuse heuristic rather than a published quota. Emit only if you can name the heuristic — otherwise use `#quota-exceeded`. |

These `type` URIs are registration targets in a draft, not resolvable documentation. If your project needs a dereferenceable URI today, use your own (`https://errors.example.com/quota-exceeded`) and record the mapping to the IANA form in the ADR.

## Quotas vs rate limits

- **Rate limit** = requests per short window (per-second/minute) — protects infrastructure. Exceed → `429` + `Retry-After`.
- **Quota** = plan allowance per long period (per-day/month) — a billing/entitlement concept. Exceed → `429` (or `402 Payment Required` if it's a paid-plan upgrade path). Track separately. A quota and a rate limit can be advertised as two named policies on the same response — `RateLimit-Policy: "burst";q=100;w=60,"daily";q=1000;w=86400` — which is exactly what the named-policy syntax is for; the legacy triple could not express it.

## Load shedding / admission control

Rate limits cap a single caller; **load shedding** protects the whole process when aggregate load exceeds capacity (a thundering herd of *new* tenants each under their own limit can still saturate you).

- Put a **bounded-concurrency semaphore** + **bounded queue depth** in front of expensive work. When in-flight ≥ ceiling and the queue is full, reject overflow with `503 Service Unavailable` + `Retry-After` rather than accepting work that will time out anyway. Type the body `#temporary-reduced-capacity` (see §Problem types) so the caller can tell shedding apart from its own quota.
- **Priority-aware shedding:** exempt health/readiness probes; shed low-priority/background traffic before user-facing requests.
- Size the ceiling from a real number (pool size, downstream capacity), cited — not a guess.

## Detectors (cite-or-halt)

- `grep` route decorators/handlers for expensive paths (`/search`, `/export`, `/report`, `/bulk`, `/upload`, LLM endpoints) with NO limiter middleware/decorator → `add-rate-limit`.
- `429` constructed without `Retry-After` or without any quota field → `emit-ratelimit-headers`.
- A response builder emitting **only** `RateLimit-Limit`/`-Remaining`/`-Reset` (draft-05 legacy) with no `RateLimit` / `RateLimit-Policy` alongside → `emit-ratelimit-headers` (add the two-field form; keep the triple until telemetry says no client reads it).
- `RateLimit-Policy` written in the old unnamed-policy syntax (`100;w=60` — no quoted name, no `q=`) → `emit-ratelimit-headers`.
- A `503` shed by admission control with no `Retry-After` → `add-load-shedding` (the shed path is the one clients most often hot-loop against).
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
