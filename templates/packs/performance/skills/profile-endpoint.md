---
name: profile-endpoint
description: Load-test a specific endpoint locally and profile where time is spent. Use before optimizing.
---

# profile-endpoint

Load + flamegraph + DB-query analysis on one endpoint. Never optimize on vibes.

## Premise

Real signals only. Every percentile, RPS number, and "% time spent" comes from a measured run — autocannon/k6/wrk output captured verbatim, flamegraph generated, slow-query log tailed. Recommendations cite the exact query / index / function frame from the captured artifact. No "this should be faster if…" without a baseline + ramp on the same hardware. Empty tables and dev-mode servers are non-starters; either run with realistic data or refuse the result.

## Halt conditions

- Refuse to report p50/p95/p99 without the load-tool output it came from.
- Refuse to claim "X% of time in Y" without a flamegraph pointing at frame Y.
- Halt if DB tables are empty or seeded with < 1k rows — numbers will lie.
- Don't propose an index without showing the slow query that needs it (cite the log line).
- Don't recommend "optimize the loop" without naming the file and line.

## When to use

- An SLO is being missed.
- Before implementing a "performance" change — get a baseline first.
- After a feature ship that quietly slowed something else down.
- During capacity planning ("can we handle 5x traffic?").

## Prerequisites

- Dev server running with realistic data (NOT empty tables — those lie).
- Load generator (any HTTP load tool — k6 / Artillery / Locust / Gatling / vegeta / wrk / autocannon / hey / `oha`).
- Profiler for the runtime — every mainstream language has a sampling profiler (e.g., `pprof` for Go, `py-spy` / `cProfile` for Python, `0x` / `clinic flame` for Node, `async-profiler` / JFR for JVM, `dotnet-trace` / PerfView for .NET, `perf` / `samply` for Rust + native).
- DB slow-query logging enabled in dev.

## Procedure (stack-agnostic shape)

1. Enable DB slow-query log via the engine's knob (e.g., Postgres `log_min_duration_statement`, MySQL slow-query log).
2. Warm up to avoid JIT + connection-pool noise — run a low-concurrency burst for 30s and discard.
3. Baseline at low concurrency — run the load tool for 60s at moderate concurrency (~50 connections) against the target endpoint with realistic auth + payload; capture p50/p95/p99 + RPS + error count.
4. Capture a flamegraph during a ramp — start the server under the language's sampling profiler, run the load tool at higher concurrency (~200 connections) for 60s, stop the profiler to write the flamegraph artifact.
5. Capture DB slow queries during the ramp — tail the DB log; collect entries with duration above your SLO budget.
6. Disable verbose logging when done.

## Output (illustrative)

```
Endpoint: POST /orders

Baseline (50 conn, 60s):
  p50:  42ms    p95:  87ms    p99: 112ms    rps: 1180    errors: 0

Ramp (200 conn, 60s):
  p50:  98ms    p95: 340ms    p99: 720ms    rps: 1840    errors: 12 (vendor SDK timeouts)

Where time is spent (sampling-profiler flamegraph):
  42%  OrderRepository.findByUser    (missing index on user_id)
  18%  ProductMapper.toDto           (heavy serialize of large nested object)
  15%  <vendor API call>             (network — can't optimize further)
  25%  other (router, request parse, log serialization)

DB slow queries (>50ms):
  SELECT ... FROM orders WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50
    avg 38ms, 420 calls — missing index on (user_id, created_at DESC)

Recommendations (priority):
  1. Add the missing composite index (use the engine's online-index-build syntax, e.g., `CREATE INDEX CONCURRENTLY` in Postgres) — expect p95 ~180ms.
  2. Cache ProductMapper.toDto per product (invalidate on write).
  3. Cap the vendor-API call timeout at 3s + use cached fallback reply.
```

## False positives / gotchas

- Empty tables run any query in ~0ms — populate with prod-like volume before profiling.
- Local profiling on a laptop ≠ production hardware; treat findings as relative, not absolute.
- The first request after server start hits cold cache + lazy DB connections — discard.
- "Concurrent connections" is not the same as "requests per second" — different load tools knob this differently; pick the one your tool exposes.
- A "fast" endpoint is whatever your SLO says — don't chase numbers from a blog post.

## Related

- `load-test.md` — boundary: this skill diagnoses ONE slow subject; `load-test` runs the whole-system SLA campaign (realistic mix, ramp to breakpoint, headroom). When a campaign exposes a knee, it hands the subject at that knee back here for the flamegraph + slow-query root cause.
