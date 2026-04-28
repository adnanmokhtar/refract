---
name: profile-endpoint
description: Load-test a specific endpoint locally and profile where time is spent. Use before optimizing.
---

# profile-endpoint

Load + flamegraph + DB-query analysis on one endpoint. Never optimize on vibes.

## When to use

- An SLO is being missed.
- Before implementing a "performance" change — get a baseline first.
- After a feature ship that quietly slowed something else down.
- During capacity planning ("can we handle 5x traffic?").

## Prerequisites

- Dev server running with realistic data (NOT empty tables — those lie).
- Load generator: `autocannon` (Node), `oha` (Rust), `wrk`, `k6`, or `hey`.
- Profiler for the runtime:
  - Node: `0x` or `clinic flame`
  - Python: `py-spy`
  - Go: `go tool pprof`
  - Java: `async-profiler`
- DB slow-query logging enabled in dev.

## Procedure

1. Enable DB slow-query log (Postgres):
   ```bash
   psql "$DATABASE_URL" -c "ALTER SYSTEM SET log_min_duration_statement = 0; SELECT pg_reload_conf();"
   ```
2. Warm up to avoid JIT + connection-pool noise:
   ```bash
   npx autocannon -c 10 -d 30 http://localhost:3000/orders   # 30s warmup, ignore results
   ```
3. Baseline at low concurrency:
   ```bash
   npx autocannon -c 50 -d 60 -p 1 -m POST -H "Authorization: Bearer $JWT" \
     -H "Content-Type: application/json" \
     -b '{"customerId":"u_1","items":[{"sku":"A1","qty":1}]}' \
     http://localhost:3000/orders
   ```
4. Capture a flamegraph during a ramp:
   ```bash
   # Start server under 0x
   npx 0x -- node dist/main.js &
   SERVER_PID=$!
   npx autocannon -c 200 -d 60 http://localhost:3000/orders
   kill -SIGINT $SERVER_PID   # 0x writes flamegraph.html
   ```
5. Capture DB slow queries during the ramp:
   ```bash
   tail -f /var/log/postgresql/postgresql-15-main.log | grep -E 'duration: [0-9]{3,}'
   ```
6. Disable verbose logging when done:
   ```bash
   psql "$DATABASE_URL" -c "ALTER SYSTEM RESET log_min_duration_statement; SELECT pg_reload_conf();"
   ```

## Output

```
Endpoint: POST /orders

Baseline (50 conn, 60s):
  p50:  42ms    p95:  87ms    p99: 112ms    rps: 1180    errors: 0

Ramp (200 conn, 60s):
  p50:  98ms    p95: 340ms    p99: 720ms    rps: 1840    errors: 12 (Claude SDK timeouts)

Where time is spent (0x flamegraph):
  42%  OrderRepository.findByUser    (missing index on user_id)
  18%  ProductMapper.toDto           (JSON.stringify of large nested obj)
  15%  Anthropic.messages.create     (network — can't optimize further)
  25%  other (router, JSON parse, log serialization)

DB slow queries (>50ms):
  SELECT ... FROM orders WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50
    avg 38ms, 420 calls — missing index on (user_id, created_at DESC)

Recommendations (priority):
  1. CREATE INDEX CONCURRENTLY idx_orders_user_created ON orders(user_id, created_at DESC); — expect p95 ~180ms.
  2. Cache ProductMapper.toDto per product (invalidate on write).
  3. Cap Anthropic timeout at 3s + use cached fallback reply.
```

## False positives / gotchas

- Empty tables run any query in ~0ms — populate with prod-like volume before profiling.
- Local profiling on a laptop ≠ production hardware; treat findings as relative, not absolute.
- The first request after server start hits cold cache + lazy DB connections — discard.
- `autocannon -c` is concurrent connections, not RPS; use `--connectionRate` if you need fixed RPS.
- A "fast" endpoint is whatever your SLO says — don't chase numbers from a blog post.
