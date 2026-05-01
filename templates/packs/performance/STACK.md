# Performance pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A profiler appropriate to the runtime** (`clinic.js` / `0x` / `node --prof` for Node; `py-spy` / `cProfile` / `Pyroscope` for Python; `pprof` for Go; async-profiler / JFR for JVM; Chrome DevTools Performance / Firefox profiler for frontend)
- **A load-testing tool** for endpoint baselines (`k6` / `Artillery` / `Locust` / `wrk` / `vegeta`)
- **An APM / RUM** for production p50/p95/p99 (Datadog / New Relic / Sentry Performance / Grafana Tempo / OTel-based)
- **A bundle analyzer** for frontend (`size-limit` / `bundlesize` / `webpack-bundle-analyzer` / `rollup-plugin-visualizer`)
- **Lighthouse / Core Web Vitals** for frontend perceived perf (LCP, INP, CLS)
- **A query plan tool** for DB perf (`EXPLAIN ANALYZE` Postgres / `EXPLAIN FORMAT=TREE` MySQL 8 / `explain()` Mongo)

## Inline examples in this pack

Wherever this pack's files show concrete syntax, examples lean **Node.js (NestJS) + Postgres + Vue 3 + k6** for illustration. Substitute per stack:

| Node + NestJS (illustrated) | Java + Spring | Python + FastAPI | Go (chi/gin) | .NET (ASP.NET Core) | Substitution source |
|---|---|---|---|---|---|
| `clinic.js` / `0x` flamegraph | async-profiler / JFR | `py-spy record` | `pprof` HTTP endpoint | dotTrace / dotnet-trace | CPU / wall profiler |
| `--inspect` heap snapshot | VisualVM / Eclipse MAT | `tracemalloc` / memory_profiler | `pprof -alloc_objects` | dotMemory | heap profiler |
| `Promise.all` / `pLimit` | `CompletableFuture.allOf` / parallelStream | `asyncio.gather` / Semaphore | `errgroup.WithContext` | `Task.WhenAll` + `SemaphoreSlim` | bounded parallel I/O |
| TanStack Query / DataLoader (Node) | Reactor / RxJava + caches | aiocache / cachetools | singleflight | `IMemoryCache` / `IDistributedCache` | request-coalescing cache |
| `pg_stat_statements` | same (Postgres) / Performance Schema (MySQL) | same | same | same | DB query profiling |
| `EXPLAIN (ANALYZE, BUFFERS)` (Postgres) | same | same | same | same | query plan |
| k6 / Artillery script | same | same / Locust | same / vegeta | NBomber + same | load test |
| `size-limit` (frontend) | bundle analysis tool | n/a (server) | n/a | n/a | frontend bundle gate |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual profiler, load-test runner, APM provider, cache primitive, p95 SLO threshold.
- The project's `_extracted-codebase.md § Performance` — slow-query log path, perf benchmark suite location, RUM / APM dashboard URL.
- The project's `ai/perf-baselines/` — recorded baselines (p50/p95/p99 + RPS) per critical endpoint.

Universal hard rules (baseline before change, profile before optimize, no N+1, paginate every list, every cache has TTL, no sync I/O on event loop, no DB transaction across external call) apply across all stacks.
