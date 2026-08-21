---
name: performance-principles
kind: example
pack: performance
---

# Performance Principles

> **Hard rule.** Every "perf" PR MUST attach a baseline AND post-change measurement (p50 / p95 / p99 + RPS). Optimization without a profile, N+1 queries, unbounded caches, sync I/O on the event loop, and external calls held inside DB transactions are forbidden.

Prevents the two failure modes: optimizing the wrong thing, and shipping a regression because no one measured.

## Must

- Establish a baseline BEFORE changing code: p50 / p95 / p99 latency, RPS, memory, error rate. No baseline = no proof of improvement.
- Profile before optimizing. `clinic.js` / `0x` / `node --prof` (Node), `py-spy` / `cProfile` (Python), `pprof` (Go), Chrome DevTools Performance (frontend). The bottleneck is rarely where you guessed.
- Every list endpoint paginates. Cursor pagination (`WHERE id > :lastId LIMIT N`) for deep lists; offset is fine for shallow.
- Every cache entry has a TTL or an explicit invalidation path. Unbounded caches = memory leak you'll find at 3am.
- Cache stampede protection on hot keys: singleflight (Go), `dataloader` (Node), `getOrSet` with locking, or `cachetools` `cached` lock.
- Indexes on every column appearing in WHERE, ORDER BY, or JOIN of slow queries. Verify with `EXPLAIN ANALYZE`.
- Async I/O on the event loop. Sync `fs.readFileSync` / blocking DB drivers in a request handler is a stop-the-world bug.

## Must not

- Optimize without a profile. Intuition is wrong ~80% of the time on hot paths.
- N+1 queries — fetching parent then looping `findById(child)`. Use `IN (...)`, JOINs, or DataLoader batching.
- `SELECT *` on large rows when you need 3 columns. Network + parse cost adds up at scale.
- Hold a DB transaction across an external API call. Connection pool exhaustion at peak.
- Regex compilation inside a hot loop — compile once, reuse.
- `console.log` / `print` in hot paths (request handlers, render loops). Logging is I/O.
- Block the event loop with CPU work > 50ms — offload to a worker thread / queue / separate process.
- Cache responses that depend on user/tenant identity without including that identity in the cache key.

## Should

- Architecture wins beat micro-wins: add a queue, CDN, or read replica before optimizing a mapper function.
- `Promise.all` / `asyncio.gather` / errgroup for independent I/O. Sequential `await` of independent calls is wasted wall-clock.
- Bound worker pools and concurrency limits — unbounded fan-out kills downstreams.
- Frontend: lazy-load routes, virtualize lists > 100 items (`react-window`, `vue-virtual-scroller`), use `<img loading="lazy">` + `srcset`, tree-shake bundles.
- Backend: streaming responses for large payloads, gzip/brotli at the edge, HTTP/2 or HTTP/3.
- Set realistic SLOs (e.g. p95 < 300ms on key endpoint) and alert on regression — performance without an SLO is just vibes.

## Review checklist

- [ ] Before/after numbers in the PR description for any "perf" PR (p50/p95/p99 + RPS).
- [ ] New endpoint has pagination if it returns a list.
- [ ] New cache has a documented TTL and invalidation strategy.
- [ ] New query has been `EXPLAIN`-ed; no full table scan on tables > 10k rows.
- [ ] No new sync I/O in async handlers.
- [ ] Frontend bundle delta checked (`size-limit` / `bundlesize` CI report).

## Enforcement

- `size-limit` or `bundlesize` CI check on frontend bundles.
- Lighthouse CI budget on Core Web Vitals (LCP < 2.5s, INP < 200ms, CLS < 0.1).
- k6 / Artillery / Locust load tests on critical endpoints in staging.
- Slow query log enabled in dev + staging; review weekly.
- APM (Datadog / New Relic / Sentry Performance / Grafana Tempo) with alerts on p95 regression.
