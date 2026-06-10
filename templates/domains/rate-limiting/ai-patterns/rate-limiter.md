---
name: rate-limiter
description: "Pattern: Rate limiting / quotas / throttling (shared-store, atomic, per-identity)"
kind: ai-pattern
---

# Pattern: Rate limiting / quotas / throttling (shared-store, atomic, per-identity)

> **Hard rule** — Application code calls a `RateLimiter` interface backed by a SHARED atomic store (never an in-memory counter behind a load balancer); the increment-and-check is one atomic operation (`INCR`+`EXPIRE` / Lua / token-bucket script), never check-then-set; limits are keyed per-identity (key/user/tenant/IP/route), never global-only; a throttled request returns `429` + `Retry-After` + `RateLimit-Limit/Remaining/Reset`. Fail-open vs fail-closed on store outage is a documented per-endpoint decision.

**When to apply**
- Any public API, authenticated app backend, or service with anonymous traffic that can be abused or that has finite capacity.
- Security-sensitive endpoints (login, password-reset, signup, OTP, search, export) needing stricter, separately-keyed limits.
- Tiered SaaS products where free vs paid plans carry different rates / quotas, or where expensive endpoints must cost more.
- Multi-instance / autoscaled deployments where per-process counting is wrong by construction.

**When NOT to apply**
- A single-process CLI / batch job with no concurrent external callers — limiting is overhead.
- Internal trusted service-to-service calls already bounded by a connection pool / concurrency limit (use the concurrency cap instead of a request-rate limiter).
- Hard quota accounting that must be transactionally exact + billable (metered billing) — that belongs in the billing ledger with the payment domain, not an approximate rate counter.

**Halt conditions / mandatory cites**
- Cite the `RateLimiter` interface + its backing store at `<path:line>`. An in-memory counter as the authority in a `replicas > 1` service = halt.
- Cite the atomic increment-and-check (`INCR`+`EXPIRE`, Lua script, token-bucket script) at `<path:line>`. A `get()` → decide → `set()` sequence = halt (check-then-set race).
- Cite the identity-key derivation at `<path:line>` — must be per-identity/route, not a single global key.
- Cite the IP resolver at `<path:line>` when any limit keys on IP — must validate the trusted proxy chain, not read a raw client header.
- Cite the `429` + `Retry-After` + `RateLimit-*` emission at `<path:line>`. Silent drop / 200 / 500 on throttle = halt.
- Grep ban: "Redis handles the limit" / "the gateway rate-limits it" without file:line for the store, the atomic op, the per-identity key, and the header emission.

## Why

A rate limiter is a tiny amount of code with several independent ways to be silently wrong, each of which only shows up under exactly the load the limiter exists to handle:

1. **Wrong store** — an in-memory counter is correct on one box and 1/Nth-effective behind N boxes. The bug is invisible in dev (one process) and live in prod (autoscaled).
2. **Wrong atomicity** — read-decide-write leaks the limit under concurrency; the limiter passes every test that sends requests one at a time.
3. **Wrong identity** — a global counter throttles the quiet tenant for the loud one; a spoofable-IP key gives an attacker unlimited fresh identities.
4. **Wrong contract** — a silent drop or a `429` with no `Retry-After` turns a well-behaved client into a tight retry loop that amplifies load.
5. **Wrong failure mode** — an accidental fail-open removes all limiting during a store outage, on the exact critical paths an attacker probes.

The pattern isolates all five behind a small interface with one correct implementation.

## Algorithm choice (pick per use-case, document the trade-off)

| Algorithm | Burst behaviour | Cost | Use when |
|---|---|---|---|
| **Fixed window** | Allows up to 2× the limit across the window boundary (100 at 00:59 + 100 at 01:00). | Cheapest — one counter + TTL. | Coarse limits where a boundary burst is acceptable; document that you accept it. |
| **Sliding-window log** | Exact — no boundary burst. | Heavy — stores a timestamp per request. | Low-volume, must-be-exact limits (billing-adjacent gates). |
| **Sliding-window counter** | Approximates the sliding window by weighting the previous window. | Cheap — two counters. | The default when you want fixed-window cost without the boundary burst. |
| **Token bucket** | Allows a configured burst, refills at a steady rate. | Cheap — `{tokens, lastRefill}` + a script. | **Default for APIs** — natural burst + steady rate, good client ergonomics. |
| **Leaky bucket** | Smooths output to a constant rate (queue drains at fixed speed). | Cheap. | When the downstream needs a constant, smoothed inflow (no bursts at all). |

## The interface

```ts
// src/modules/rate-limit/core/rate-limiter.interface.ts

export type RateLimitPolicy = {
  /** Algorithm + its window/refill config. */
  algorithm: 'fixed-window' | 'sliding-window' | 'token-bucket' | 'leaky-bucket';
  limit: number;            // tokens per window, or bucket capacity
  windowSeconds: number;    // window length, or refill period
  burst?: number;           // token-bucket burst above steady rate
  cost?: number;            // cost-weight of THIS request (default 1; expensive routes > 1)
};

export type RateLimitResult = {
  allowed: boolean;
  limit: number;            // -> RateLimit-Limit
  remaining: number;        // -> RateLimit-Remaining
  resetSeconds: number;     // -> RateLimit-Reset
  retryAfter?: number;      // -> Retry-After (present only when !allowed)
};

export interface RateLimiter {
  /** Atomic check-and-consume. `key` is the composite identity key. */
  check(key: string, policy: RateLimitPolicy): Promise<RateLimitResult>;
}
```

Handlers / middleware deal only with `RateLimitResult` — never with Redis, never with the algorithm. Swapping fixed-window for token-bucket, or Redis for a managed limiter, is a single-file change.

## Token-bucket limiter (default) — atomic Lua

> The example below uses an `ioredis`-style client + a NestJS-style provider for illustration. Substitute your project's idiom from `.claude/_extracted-codebase.md`: your Redis / cache client, your DI mechanism, your config source. The SHAPE — load the policy → run ONE atomic script → map to the standard result → emit standard headers — is what's universal, not the client names. The Lua runs entirely server-side in Redis, so the read-refill-decrement-write is atomic against all other instances.

```lua
-- token_bucket.lua  — KEYS[1] = bucket key
-- ARGV: 1=capacity 2=refillPerSec 3=now(ms) 4=cost 5=ttlSec
local capacity      = tonumber(ARGV[1])
local refillPerSec  = tonumber(ARGV[2])
local now           = tonumber(ARGV[3])
local cost          = tonumber(ARGV[4])
local ttl           = tonumber(ARGV[5])

local data    = redis.call('HMGET', KEYS[1], 'tokens', 'ts')
local tokens  = tonumber(data[1])
local ts      = tonumber(data[2])
if tokens == nil then tokens = capacity; ts = now end

-- refill since last touch
local elapsed = math.max(0, now - ts) / 1000.0
tokens = math.min(capacity, tokens + elapsed * refillPerSec)

local allowed = 0
if tokens >= cost then
  tokens  = tokens - cost
  allowed = 1
end

redis.call('HMSET', KEYS[1], 'tokens', tokens, 'ts', now)
redis.call('EXPIRE', KEYS[1], ttl)

-- seconds until enough tokens for one more `cost`
local deficit    = math.max(0, cost - tokens)
local retryAfter = math.ceil(deficit / refillPerSec)
return { allowed, math.floor(tokens), retryAfter }
```

```ts
// src/modules/rate-limit/infrastructure/redis-token-bucket.limiter.ts

@Injectable()
export class RedisTokenBucketLimiter implements RateLimiter {
  constructor(@Inject(REDIS) private redis: Redis, private logger: Logger) {}

  async check(key: string, policy: RateLimitPolicy): Promise<RateLimitResult> {
    const capacity     = policy.burst ?? policy.limit;
    const refillPerSec = policy.limit / policy.windowSeconds;
    const cost         = policy.cost ?? 1;

    const [allowed, tokens, retryAfter] = (await this.redis.eval(
      TOKEN_BUCKET_LUA, 1, `rl:${key}`,
      capacity, refillPerSec, Date.now(), cost, policy.windowSeconds * 2,
    )) as [number, number, number];

    return {
      allowed: allowed === 1,
      limit: capacity,
      remaining: tokens,
      resetSeconds: Math.ceil((capacity - tokens) / refillPerSec),
      retryAfter: allowed === 1 ? undefined : retryAfter,
    };
  }
}
```

## Fixed / sliding window — atomic counter (when burst doesn't matter)

```ts
// Fixed window: one INCR per window, EXPIRE only on the first hit. Atomic — no check-then-set.
async check(key: string, policy: RateLimitPolicy): Promise<RateLimitResult> {
  const windowKey = `rl:${key}:${Math.floor(Date.now() / 1000 / policy.windowSeconds)}`;
  const count = await this.redis.incr(windowKey);
  if (count === 1) await this.redis.expire(windowKey, policy.windowSeconds);

  const remaining = Math.max(0, policy.limit - count);
  const ttl = await this.redis.ttl(windowKey);
  return {
    allowed: count <= policy.limit,
    limit: policy.limit,
    remaining,
    resetSeconds: ttl,
    retryAfter: count <= policy.limit ? undefined : ttl,
  };
}
```

Note the boundary-burst trade-off: this allows up to `2 × limit` across a window edge. If that matters, use a sliding-window-counter Lua script (weights the previous window) or the token bucket above. NEVER do `const n = await redis.get(k); if (n < limit) redis.set(k, n+1)` — that is the check-then-set race.

## The guard (per-identity key + standard headers + fail policy)

```ts
// src/modules/rate-limit/rate-limit.guard.ts

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    @Inject(RATE_LIMITER) private limiter: RateLimiter,
    private ip: TrustedProxyIpResolver,
    private reflector: Reflector,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const policy = this.reflector.get<RateLimitPolicy & { keyBy: KeyDimension; failMode: 'open' | 'closed' }>(
      RATE_LIMIT, ctx.getHandler(),
    );
    if (!policy) return true;                       // no policy declared on this route

    const req = ctx.switchToHttp().getRequest();
    const res = ctx.switchToHttp().getResponse();
    const key = this.identityKey(req, policy.keyBy); // tenant / user / apiKey / ip — composed with route

    let result: RateLimitResult;
    try {
      result = await this.limiter.check(key, policy);
    } catch (err) {
      // CONSCIOUS, DOCUMENTED failure policy — per endpoint, not accidental.
      this.logger.error({ err: err.message, route: req.route?.path }, 'rate_limiter_store_unavailable');
      if (policy.failMode === 'closed') throw new ServiceUnavailableException('rate_limiter_unavailable');
      return true;                                  // fail-open: only for non-critical reads
    }

    res.setHeader('RateLimit-Limit', result.limit);
    res.setHeader('RateLimit-Remaining', result.remaining);
    res.setHeader('RateLimit-Reset', result.resetSeconds);

    if (!result.allowed) {
      res.setHeader('Retry-After', result.retryAfter!);
      throw new HttpException(
        { error: 'rate_limited', message: 'Too many requests', retryAfter: result.retryAfter },
        429,
      );
    }
    return true;
  }

  private identityKey(req: Request, keyBy: KeyDimension): string {
    const route = req.route?.path ?? req.path;
    switch (keyBy) {
      case 'apiKey': return `key:${req.apiKey!.id}:${route}`;
      case 'tenant': return `tenant:${req.tenantId!}:${route}`;
      case 'user':   return `user:${req.user!.id}:${route}`;
      case 'ip':     return `ip:${this.ip.resolve(req)}:${route}`;   // trusted-proxy resolved
    }
  }
}
```

Declare policy on the route, not inside it:

```ts
@RateLimit({ keyBy: 'tenant', algorithm: 'token-bucket', limit: 100, windowSeconds: 60, burst: 20, failMode: 'open' })
@Get('/products')
list() { /* ... */ }

// Security-sensitive: tighter, IP+account keyed, FAIL-CLOSED.
@RateLimit({ keyBy: 'ip', algorithm: 'fixed-window', limit: 5, windowSeconds: 60, failMode: 'closed' })
@Post('/auth/login')
login() { /* ... */ }

// Expensive: cost-weighted + concurrency-capped elsewhere.
@RateLimit({ keyBy: 'tenant', algorithm: 'token-bucket', limit: 60, windowSeconds: 60, cost: 10, failMode: 'closed' })
@Post('/reports/export')
export() { /* ... */ }
```

## Trusted-proxy IP resolution

```ts
// src/modules/rate-limit/trusted-proxy-ip.resolver.ts

@Injectable()
export class TrustedProxyIpResolver {
  // CIDRs of YOUR proxies / CDN / load balancers — config, not code constants.
  constructor(@Inject(TRUSTED_PROXIES) private trusted: CidrSet) {}

  resolve(req: Request): string {
    // Only trust X-Forwarded-For if the immediate peer is a trusted proxy.
    if (!this.trusted.contains(req.socket.remoteAddress!)) {
      return req.socket.remoteAddress!;             // direct client — ignore forwarded headers entirely
    }
    // Walk right-to-left, skip trusted hops, take the first untrusted = real client.
    const chain = (req.headers['x-forwarded-for'] as string ?? '').split(',').map(s => s.trim());
    for (let i = chain.length - 1; i >= 0; i--) {
      if (!this.trusted.contains(chain[i])) return chain[i];
    }
    return req.socket.remoteAddress!;
  }
}
```

Reading `req.headers['x-forwarded-for']` directly, without the trusted-proxy check, lets any client mint a fresh "IP" per request → the per-IP limit is meaningless.

## Tiered quotas + cost weighting

- Per-plan limits come from the plan record / config, not hardcoded `if (plan === 'free')` scattered across handlers: `policy = plans[req.tenant.plan].limits[routeGroup]`.
- A daily / monthly quota is a SECOND limiter check with a long window (`keyBy: 'tenant'`, `windowSeconds: 86400`) layered on top of the per-second rate — both must pass.
- Expensive endpoints set `cost > 1` so they consume more of the same bucket (an export costing 10 tokens against a 100-token bucket = 10 exports/window) — one knob instead of a parallel limiter.
- Burst allowance is the token-bucket `capacity` (`burst`) above the steady `limit / windowSeconds` refill.

## Layering (don't rely on one layer)

| Layer | Sees | Keys on | Stops |
|---|---|---|---|
| Edge / CDN / WAF | Raw connections, volume | IP, ASN, geo | Volumetric floods, obvious bots — before they reach your origin. |
| Application limiter | Identity, plan, route, cost | tenant / user / key / IP × route | Per-identity abuse, fair-share, tiered quotas, expensive routes. |
| Per-resource concurrency cap | In-flight expensive jobs | tenant × resource | One tenant monopolising the export/report/LLM worker pool. |

The edge can't see your tenant; the app can't cheaply absorb a volumetric flood; concurrency caps protect finite backends the rate limiter can't model. Use all three.

## Fail-open vs fail-closed (decision table)

| Endpoint class | Store-down behaviour | Why |
|---|---|---|
| Login / signup / password-reset / OTP | **fail-closed** (or degrade to a strict in-process fallback) | An outage must not become a brute-force bypass window. |
| Payment / write / money-moving | **fail-closed** (or degrade) | Unbounded writes during an outage compound the incident. |
| General authenticated reads | **fail-open** | Availability > limiting; abuse during a brief blip is tolerable. |
| Anonymous public reads | **fail-open**, but the edge/WAF layer still caps volume | The edge is the backstop when the app limiter is blind. |

The choice is declared at the route (`failMode`) and is identical across environments. A bare `try { check() } catch { /* allow */ }` with no per-endpoint thought is the accidental-fail-open anti-pattern.

## Graceful client guidance

- Always emit `RateLimit-Limit / Remaining / Reset` (on success too) so a good client self-paces before hitting 429.
- On 429 emit `Retry-After`; document that clients MUST honour it with backoff.
- For money-moving / write retries after a 429, the client reuses the ORIGINAL idempotency key (see `<rules-path>/payment-idempotency.md`) — a backoff-retry must not become a double-charge.
- Publish the limits + tiers in your API docs; surprise limits generate support load.

## Common mistakes

### In-memory counter behind a load balancer
`const hits = new Map()` in a 4-pod service. Effective limit = 4× configured, resets on every deploy. Authority MUST be the shared store.

### Check-then-set race
`const n = await redis.get(k); if (n < limit) await redis.incr(k)`. Concurrent requests all read the same `n`, all pass. Use atomic `INCR`+`EXPIRE` or a Lua script.

### Fixed-window boundary burst (unacknowledged)
100/min fixed window → 200 requests across the 00:59→01:00 edge. Either accept + document it, or use sliding-window / token bucket.

### Global-only limit
One counter for the whole API. The loud tenant throttles the quiet one. Key per identity × route.

### Spoofable IP key
`keyBy: ip` reading a raw `X-Forwarded-For`. Attacker sets a new value per request → unlimited. Resolve through the trusted-proxy chain.

### Accidental fail-open on auth
Limiter store blips → `catch { return true }` everywhere → login throttle vanishes during the outage. Auth/payment/write fail-closed.

### Silent throttle / 429 without Retry-After
Dropped request or bare 429 → client tight-loops. Return 429 + Retry-After + RateLimit-* and document the contract.

### Unbounded expensive endpoint
`/export` with no cost weight + no concurrency cap. Cost-weight it (`cost: 10`) and cap per-tenant concurrency on the worker.

### Limiting after the cost
Running the limiter check after the expensive query/handler protects nothing. The guard runs BEFORE the work.

### NAT false-positives
A tight per-IP limit on a carrier/corporate NAT throttles thousands of real users on one egress IP. Prefer per-account limits where identity exists.

## Cross-references

- `<rules-path>/rate-limit-discipline.md` — the hard-rule list (shared store, atomic, per-identity, 429 contract, stricter auth/expensive limits, fail policy, trusted-proxy IP).
- `<rules-path>/payment-idempotency.md` — idempotent backoff-retry after a 429 on money paths (reuse the original key).
- `<patterns-path>/webhook-flow.md` — relate inbound provider retry/backoff to your throttle responses + return-200 policy.
- `<commands-path>/probe-limits.md` — local/staging probe that proves the limit triggers + verifies the headers.
- `<agents-path>/rate-limit-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-rate-limit-policy.md` — ADR pinning algorithm, identity dimensions, tier limits, and per-endpoint fail-open/closed choices.
