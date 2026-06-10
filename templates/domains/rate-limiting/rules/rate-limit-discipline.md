---
name: rate-limit-discipline
description: Rate limiting / quotas / throttling discipline
kind: rule
---

# Rate limit discipline

## Hard rule

Every public or expensive endpoint MUST be rate-limited per-identity (API key / user / tenant / IP) against a SHARED atomic store — in-memory counters behind a load balancer are FORBIDDEN. Limit decisions MUST use an atomic primitive (Redis `INCR`+`EXPIRE`, or a single Lua / token-bucket script) — check-then-set is FORBIDDEN. A throttled request MUST return `429 Too Many Requests` with `Retry-After` and the `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset` headers — silently dropping or 200-ing a throttled request is FORBIDDEN. Login / password-reset / signup / OTP / search / export and any expensive endpoint MUST carry a stricter limit. Fail-open vs fail-closed when the store is down MUST be a documented per-endpoint decision, never an accident. Client IP MUST come from a trusted-proxy-validated forwarded header, never a raw client-supplied header.

Rate limiting is a correctness + availability + abuse control, not a nicety. A missing limit on login is credential-stuffing fuel; an in-memory counter behind three pods is a 3x-leaky limit; an accidental fail-open on the store outage turns a Redis blip into an unbounded-traffic incident.

## Must

- **Per-identity, not global.** Choose the identity dimension deliberately: per API key (server-to-server), per authenticated user / tenant (app traffic), per IP (anonymous traffic), per route (cost isolation). Compose where needed (`{tenant}:{route}`, `{ip}:{route}`). A single global counter is almost always wrong — one noisy tenant starves everyone.
- **Shared atomic store.** Counters / buckets live in a store visible to every instance (Redis, or a managed limiter). The increment-and-check MUST be atomic: `INCR` then `EXPIRE` on first hit, or a Lua script, or a token-bucket script that reads + refills + decrements + writes in one round trip. Never read the count, decide in app code, then write back.
- **Pick the algorithm per use-case + document it.** Fixed window (cheap, but allows a 2x burst across the window boundary), sliding-window log (exact, memory-heavy), sliding-window counter (good approximation, cheap), token bucket (allows a configured burst over a steady refill rate — the default for APIs), leaky bucket (smooths to a constant outflow). Record the choice + reason in the limiter config or an ADR.
- **Standard response contract.** Throttled → `429` + `Retry-After: <seconds>` + `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset` (IETF draft headers) on BOTH throttled and successful responses so a well-behaved client can self-pace. Body is a structured error, not an empty 429.
- **Tiered quotas.** Free vs paid tiers carry different limits; per-plan limits live in config / the plan record, not hardcoded `if (plan === 'free')` scattered across handlers. Support a burst allowance distinct from the steady rate, cost-weighted limits (an export / report / LLM call costs more tokens than a cheap read), and daily/monthly quotas layered on top of the per-second rate.
- **Stricter limits on security-sensitive + expensive endpoints.** Login, password-reset, signup, OTP/verify, search, export/report, bulk, and any unbounded-cost endpoint get their own tight bucket — keyed by both IP and account where applicable (defends both the account and the IP source).
- **Trusted-proxy IP resolution.** When keying on IP, derive the client IP from the correct forwarded header (`X-Forwarded-For` / `Forwarded` / `True-Client-IP`) only when the immediate peer is a trusted proxy (your CDN / LB), taking the right hop. A raw client-supplied header is attacker-controlled and trivially spoofed → every attacker request looks like a fresh IP.
- **Conscious fail-open / fail-closed per endpoint.** When the limiter store is unavailable, decide deliberately: auth / payment / write paths fail-closed (or degrade to a stricter in-process fallback) so an outage can't be a bypass; general read endpoints may fail-open to preserve availability. The choice is documented at the call site and is the same in every environment.
- **Layer limits.** Edge / CDN / WAF limits (coarse, IP-based, absorb volumetric abuse) + application limits (per-identity, per-route, business-aware) + per-resource concurrency limits (max in-flight expensive jobs per tenant). Don't rely on a single layer — the edge can't see your tenant; the app can't absorb a volumetric flood.
- **Graceful client guidance.** Document the limits publicly, always emit the `RateLimit-*` headers, and pair with idempotent retries + backoff on the client (see `<rules-path>/payment-idempotency.md` — a retried-with-backoff request after a 429 MUST reuse the original idempotency key on money-moving paths).

## Must not

- In-memory / per-process counter (`Map`, module-level variable, local LRU) used as the authority in a multi-instance / autoscaled / load-balanced deployment. Each pod counts only its own slice → effective limit = configured × pod-count.
- Check-then-set on the counter (`const n = await get(key); if (n < limit) await set(key, n+1)`). Two concurrent requests both read `n`, both pass, both write — the limit leaks under exactly the load it exists to stop.
- A single global limit with no per-identity dimension (one tenant's burst throttles everyone).
- Throttling silently — dropping the request, returning 200, or returning 500. The client can't distinguish "slow down" from "broken."
- Returning `429` without `Retry-After` (client has no idea when to retry → tight retry loop → makes it worse).
- No limit on login / password-reset / signup / OTP / search / export / any expensive endpoint.
- Trusting `X-Forwarded-For` (or any forwarded header) from an untrusted peer — spoofable; every request mints a fresh "IP."
- Accidental fail-open: the limiter is wrapped in `try { check() } catch { /* allow */ }` with no thought — a store blip silently removes all limiting on critical paths.
- An unbounded expensive endpoint (export-everything, full-text search with no page cap, report generation, fan-out) with no concurrency cap and no cost-weighted limit.
- Per-attempt / random rate-limit keys (defeats the limit the same way a per-attempt idempotency key defeats idempotency).

## Should

- Wrap the limiter behind a project-internal `<RateLimiter>` interface (`check(key, policy)` → `{ allowed, limit, remaining, resetSeconds, retryAfter }`) so the algorithm + store are a single-file swap and every handler emits identical headers.
- Express policies declaratively (decorator / middleware config / route metadata: `@RateLimit({ key: 'tenant', limit: 100, window: '1m', burst: 20 })`) — not imperative counting inside handlers.
- Use a token-bucket Lua script as the default API limiter: it gives a documented burst + steady refill in one atomic round trip and degrades gracefully.
- Set the Redis key TTL to the window so abandoned keys expire — never let the keyspace grow unbounded.
- Emit metrics: throttle rate per route + per identity, limiter latency, store-error count, fail-open invocations. A spike in fail-open invocations is an incident, not noise.
- Return `429` from a guard / middleware that runs BEFORE the expensive work, never after — limiting that runs after the cost is paid protects nothing.
- For OTP / login, layer a progressive penalty (exponential lockout / increasing cooldown) on top of the flat rate limit, and combine with the auth domain's lockout policy.

## Review checklist (PRs touching limiter config / public endpoints / auth / expensive routes)

- [ ] New public / expensive endpoint has an explicit per-identity limit (not relying on a global default, not unlimited).
- [ ] Counter / bucket lives in the shared store (cite it) — no in-memory authority in a multi-instance service.
- [ ] Increment-and-check is atomic (`INCR`+`EXPIRE` / Lua / token-bucket script) — no check-then-set.
- [ ] Algorithm choice is documented with its trade-off (boundary burst for fixed window, etc.).
- [ ] Throttled response is `429` + `Retry-After` + `RateLimit-Limit/Remaining/Reset`; headers also present on success.
- [ ] Identity dimension is correct (per tenant/user/key/IP/route as appropriate) — not a single global counter.
- [ ] IP-keyed limits resolve the client IP from a trusted-proxy-validated forwarded header, not a raw client header.
- [ ] Login / password-reset / signup / OTP / search / export carry a stricter, separately-keyed limit.
- [ ] Fail-open vs fail-closed on store outage is explicit + correct for the endpoint's sensitivity (write/auth/payment = closed/degrade).
- [ ] Expensive endpoints have a cost-weighted limit and/or a per-tenant concurrency cap.
- [ ] Tiered quotas come from plan config, not hardcoded plan checks scattered across handlers.

## Anti-patterns

- **In-memory counter behind a load balancer** — `const hits = new Map()` in a service running 4 pods. Effective limit is 4x the configured value, and a deploy / scale event resets it. Authority MUST be the shared store.
- **Check-then-set race** — `if (await redis.get(k) < limit) await redis.incr(k)`. Under concurrent load the window between GET and INCR lets dozens of requests pass a limit of 1. Use atomic `INCR` (with `EXPIRE` on first hit) or a Lua script.
- **Fixed-window boundary burst** — a 100/min fixed window allows 100 requests at 00:59 and another 100 at 01:00 = 200 in two seconds. If the burst matters, use sliding-window or token bucket; if it doesn't, document that you accept it.
- **Global-only limit** — one counter for the whole API. The loudest tenant throttles the quietest. Key per identity.
- **Silent throttle** — request dropped or returned as 200/500. The client retries blindly. Return 429 + Retry-After.
- **429 without Retry-After or headers** — client busy-loops on retry, amplifying the load the limiter exists to shed.
- **Spoofable IP key** — keying on `req.headers['x-forwarded-for']` with no trusted-proxy check. Attacker sets a new value per request → unlimited. Validate the proxy chain; take the correct hop.
- **Accidental fail-open on auth/payment** — limiter store down → `try/catch` allows everything → login brute-force window opens during the exact outage an attacker probes for. Critical paths fail-closed or degrade.
- **Unbounded expensive endpoint** — `/export` streams the whole table, no concurrency cap, no cost weight. Ten tenants hit it at once → DB melts. Cost-weight it and cap concurrency.
- **NAT/proxy false-positive** — a strict per-IP limit on a corporate / mobile-carrier NAT throttles thousands of legitimate users sharing one egress IP. Prefer per-account limits where identity exists; reserve pure per-IP for anonymous traffic and tune for shared egress.

## Enforcement

- `<commands-path>/probe-limits.md` (slash: `/probe-limits`) — fires a controlled burst at a target endpoint (LOCAL / STAGING ONLY) and reports the observed status sequence + the actual `Retry-After` / `RateLimit-*` headers, proving the limit triggers and the contract is correct. Cite-or-halt: refuses prod, never reports an assumed result.
- `<agents-path>/rate-limit-reviewer.md` — review gate hard-failing on in-memory counters in multi-instance services, missing limits on auth / expensive endpoints, missing `429`/`Retry-After`/`RateLimit-*`, accidental fail-open on critical paths, global-instead-of-per-identity limiting, untrusted-header IP keys, check-then-set races, and unbounded expensive endpoints.
- CI lint MUST flag module-level mutable counters (`new Map()` / `{}` / array used as a hit counter) in files that also import the HTTP router, in any service whose deploy manifest declares `replicas > 1`.
- CI lint MUST flag any auth-sensitive route handler (`login`, `reset-password`, `signup`, `verify-otp`, `forgot`) that has no rate-limit decorator / middleware in its chain.
- CI lint MUST flag reads of `x-forwarded-for` / `forwarded` / `x-real-ip` that are not routed through the project's trusted-proxy IP resolver.
- TODO: `scripts/validate-rate-limits.sh` to AST-walk route definitions and assert every public + expensive route has a limit policy, that the policy resolves to the shared-store limiter, and that no in-memory counter is used as authority.

## Cross-references

- `<patterns-path>/rate-limiter.md` — algorithm trade-offs, the `RateLimiter` interface, token-bucket Lua script, atomic fixed/sliding-window scripts, tiered-quota + cost-weight shapes, fail-open/closed policy table, header emission, trusted-proxy IP resolution.
- `<rules-path>/payment-idempotency.md` — idempotent retries with backoff after a 429 on money-moving paths (reuse the original key).
- `<patterns-path>/webhook-flow.md` — inbound retry-heavy traffic; relate the provider's own retry/backoff to your throttle responses.
- `<agents-path>/rate-limit-reviewer.md` — review gate.
- `<commands-path>/probe-limits.md` — limit-probe tool.
- `<adr-path>/<NNN>-rate-limit-policy.md` — ADR pinning the algorithm choice, the identity dimensions, the tier limits, and the per-endpoint fail-open/closed decisions.
