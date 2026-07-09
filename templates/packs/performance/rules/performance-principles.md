---
name: performance-principles
description: Performance Principles
kind: rule
pack: performance
severity: must
applies-to: performance-track, every-code-writing-task-in-performance
---

# Performance Principles

> **Hard rule.** Every "perf" PR MUST attach a baseline AND post-change measurement (p50 / p95 / p99 + RPS). Optimization without a profile, N+1 queries, unbounded caches, sync I/O on the event loop, and external calls held inside DB transactions are forbidden.

Prevents the two failure modes: optimizing the wrong thing, and shipping a regression because no one measured.

## Must

- Establish a baseline BEFORE changing code: p50 / p95 / p99 latency, RPS, memory, error rate. No baseline = no proof of improvement.
- Profile before optimizing. Use the language's profiler (per language family — sampling profilers like `pprof` for Go, `py-spy` / `cProfile` for Python, `node --prof` / `clinic.js` / `0x` for Node, `async-profiler` / JFR for JVM, `dotnet-trace` / PerfView for .NET, `perf` / `samply` for Rust + native, the browser's built-in performance profiler for frontend). The bottleneck is rarely where you guessed.
- Every list endpoint paginates. Cursor pagination (`WHERE id > :lastId LIMIT N`) for deep lists; offset is fine for shallow.
- Every cache entry has a TTL or an explicit invalidation path. Unbounded caches = memory leak you'll find at 3am.
- Cache stampede protection on hot keys: a single-flight / coalescing primitive (every mainstream language has one — singleflight in Go, dataloader / promise-coalescing in Node, locked `getOrSet` / `cached` decorators in Python, etc.).
- Indexes on every column appearing in WHERE, ORDER BY, or JOIN of slow queries. Verify with the DB's plan-explainer (`EXPLAIN ANALYZE` and equivalents per DB engine).
- Async I/O on the event loop / async runtime. Sync filesystem reads or blocking DB drivers in a request handler are a stop-the-world bug.
- Browser input handlers MUST keep per-interaction main-thread work under the INP budget. Break tasks > 50ms with `scheduler.yield()` (fallback `await new Promise(r => setTimeout(r))`); mark non-urgent state updates with the framework transition primitive (React `useTransition` / `startTransition` + `useDeferredValue`; Vue is non-blocking by default; Svelte runes). See `inp-responsiveness.md`.

## Must not

- Optimize without a profile. Intuition is wrong ~80% of the time on hot paths.
- N+1 queries — fetching parent then looping single-row child fetches. Use `IN (...)`, JOINs, or batch-loader primitives.
- `SELECT *` on large rows when you need 3 columns. Network + parse cost adds up at scale.
- Hold a DB transaction across an external API call. Connection pool exhaustion at peak.
- Regex compilation inside a hot loop — compile once, reuse.
- Direct stdout / unstructured print calls (any language's `console.log` / `print` / `fmt.Println`) in hot paths (request handlers, render loops). Logging is I/O.
- Block the async runtime / event loop with CPU work > 50ms — offload to a worker thread / pool / queue / separate process.
- Cache responses that depend on user/tenant identity without including that identity in the cache key.

## Should

- Prefer architecture wins over micro-wins: add a queue, CDN, or read replica before optimizing a mapper function.
- Use the language's structured-concurrency primitive for independent I/O (`Promise.all` / `asyncio.gather` / errgroup / `Task.WhenAll` / Kotlin coroutines `async/await` / Rust `join!` / equivalent) — sequential `await` of independent calls is forbidden in hot paths (see `concurrency-discipline.md`).
- Bound worker pools and concurrency limits — unbounded fan-out kills downstreams.
- Frontend: lazy-load routes, virtualize long lists with the framework's virtualisation primitive, use the platform's lazy-image features (e.g., `<img loading="lazy">` + `srcset`), tree-shake bundles.
- Backend: stream responses for large payloads, gzip/brotli at the edge, HTTP/2 or HTTP/3.
- Set realistic SLOs (e.g. p95 < 300ms on key endpoint) and alert on regression — performance without an SLO is just vibes.
- An SLA/SLO is only validated by a load / stress / soak campaign on a prod-parity env (same instance class, DB tier, data volume) under a realistic request mix — single-VU or laptop numbers are round-trip latency of an idle system, not capacity. See `load-test.md`. Boundary: `profile-endpoint.md` diagnoses ONE slow subject; `@capacity-planner` (distributed-systems) estimates the breakpoint analytically; the campaign empirically confirms or refutes it and quantifies headroom.
- Instrument SPA route transitions (router `beforeEach` / `afterEach` + `performance.mark`, or the Soft Navigations API where available) and budget route-change-to-paint. The Soft Navigations heuristic is emerging / origin-trial — gate any reliance on it behind `where available`, not as a stable cross-browser guarantee.
- A monotonically-growing heap under steady load is a leak — hunt it with heap-diff-over-time (two-plus snapshots under flat load, attribute the growing retained set, confirm with a flat-heap soak), never a memory-limit bump or a periodic restart. Ship bounded caches (TTL / max-size / LRU) and clean up listeners, subscriptions, timers, and connections on teardown so they never become the finding. See `memory-leak-hunt.md`. Boundary: `profile-endpoint.md` (and `profile-perf`'s Memory axis) diagnoses ONE snapshot's hot path; `memory-leak-hunt.md` is the over-TIME growth hunt.

## Review checklist

- [ ] Before/after numbers in the PR description for any "perf" PR (p50/p95/p99 + RPS).
- [ ] New endpoint has pagination if it returns a list.
- [ ] New cache has a documented TTL and invalidation strategy.
- [ ] New query has been EXPLAIN-ed (the project's DB plan-explainer); no full table scan on tables > 10k rows.
- [ ] No new sync I/O in async handlers.
- [ ] Frontend bundle delta checked via the project's bundle-budget CI check.

## Enforcement

- Frontend bundle-size CI check (e.g., `size-limit`, `bundlesize`, framework-native budget) — fail-on-regression.
- Web-vitals budget in CI (Lighthouse CI or equivalent) on Core Web Vitals (LCP < 2.5s, INP < 200ms, CLS < 0.1) plus TTFB < 600ms (server-response-time) for browser frontends.
- Load tests on critical endpoints in staging using the project's load-tester (k6 / Artillery / Locust / Gatling / vegeta / wrk — pick one and keep results comparable).
- Slow query log enabled in dev + staging; review weekly.
- APM with alerts on p95 regression (the project's APM — Datadog / New Relic / Sentry Performance / Grafana Tempo / Honeycomb / OpenTelemetry-backed equivalent).
