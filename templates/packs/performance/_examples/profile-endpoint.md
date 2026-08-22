---
name: profile-endpoint
description: Load-test a specific endpoint locally and profile where time is spent. Use before optimizing.
---

# profile-endpoint

Load + flamegraph + DB-query analysis on one endpoint. Never optimize on vibes.

## Premise

Real signals only. Every percentile, RPS number, and "% time spent" comes from a measured run — the load generator's output captured verbatim, a flamegraph generated, the slow-query log tailed. Recommendations cite the exact query / index / function frame from the captured artifact. No "this should be faster if…" without a baseline + ramp on the same hardware. Empty tables and dev-mode servers are non-starters; either run with realistic data or refuse the result.

## Halt conditions

- Refuse to report p50/p95/p99 without the load-tool output it came from.
- Refuse to claim "X% of time in Y" without a flamegraph pointing at frame Y.
- Halt if the DB is empty or seeded so thinly that the planner picks a different plan than production would. Row count is a proxy, not the test: compare the plan the target query gets here against the production plan, and refuse the run when they differ — a seq scan that is correct on 200 rows tells you nothing about the index scan production performs.
- Don't propose an index without showing the slow query that needs it (cite the log line).
- Don't recommend "optimize the loop" without naming the file and line.

## When to use

- An SLO is being missed.
- Before implementing a "performance" change — get a baseline first.
- After a feature ship that quietly slowed something else down.
- During capacity planning ("can we handle 5x traffic?").

## Prerequisites

- Dev server running with realistic data (NOT empty tables — those lie).
- Load generator: whichever the project already uses. Any tool is fine provided it reports **percentiles, not just an average** — a mean cannot gate a p95.
- Profiler for the runtime:
  - Node: `0x` or `clinic flame`
  - Python: `py-spy`
  - Go: `go tool pprof`
  - Java: `async-profiler`
- DB slow-query logging enabled in dev.

## Procedure

1. Enable DB slow-query log (Postgres):
   ```bash
   # Turn the engine's slow-query log down to zero for the duration of the run.
   # The statement is engine-specific — take it from `references/<engine>.md`, never from memory,
   # and note that on some engines this needs a reload and on others a session variable is enough.
   ```
2. Warm up to avoid JIT + connection-pool noise:
   ```bash
   <load-generator> --connections 10 --duration 30 <endpoint-url>   # warmup, discard results
   ```
3. Baseline at low concurrency:
   ```bash
   <load-generator> --connections 50 --duration 60 --method POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -b '{"customerId":"u_1","items":[{"sku":"A1","qty":1}]}' \
     http://localhost:3000/orders
   ```
4. Capture a flamegraph during a ramp:
   ```bash
   # Start server under 0x
   <sampling-profiler> <the project's server start command> &
   SERVER_PID=$!
   <load-generator> --connections 200 --duration 60 <endpoint-url>
   kill -SIGINT $SERVER_PID   # most profilers write the flamegraph on clean shutdown
   ```
5. Capture DB slow queries during the ramp:
   ```bash
   # Tail the engine's slow-query log — its path comes from the engine's own config,
   # never a distro default — and filter for statements above your latency floor.
   ```
6. Disable verbose logging when done:
   ```bash
   # Reset the slow-query threshold to its previous value. Leaving it at zero on a shared
   # environment is a real incident: it logs every statement.
   ```

## Output

```
Endpoint: POST /orders

Baseline (50 conn, 60s):
  p50:  42ms    p95:  87ms    p99: 112ms    rps: 1180    errors: 0

Ramp (200 conn, 60s):
  p50:  98ms    p95: 340ms    p99: 720ms    rps: 1840    errors: 12 (vendor SDK timeouts)

Where time is spent (flamegraph):
  42%  OrderRepository.findByUser    (missing index on user_id)
  18%  ProductMapper.toDto           (JSON.stringify of large nested obj)
  15%  <vendor API call>             (network — can't optimize further)
  25%  other (router, JSON parse, log serialization)

DB slow queries (>50ms):
  SELECT ... FROM orders WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50
    avg 38ms, 420 calls — missing index on (user_id, created_at DESC)

Recommendations (priority):
  1. CREATE INDEX CONCURRENTLY idx_orders_user_created ON orders(user_id, created_at DESC); — expect p95 ~180ms.
  2. Cache ProductMapper.toDto per product (invalidate on write).
  3. Cap the vendor-API timeout + use a cached fallback reply.
```

## False positives / gotchas

- Empty tables run any query in ~0ms — populate with prod-like volume before profiling.
- Local profiling on a laptop ≠ production hardware; treat findings as relative, not absolute.
- The first request after server start hits cold cache + lazy DB connections — discard.
- Most load generators' "connections" flag sets **concurrency, not RPS** — a closed-loop tool paces itself against your latency. If you need a fixed arrival rate, use the tool's rate flag, or you are measuring a different system than you think.
- A "fast" endpoint is whatever your SLO says — don't chase numbers from a blog post.
