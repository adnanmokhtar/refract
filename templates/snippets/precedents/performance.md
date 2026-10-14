# Precedents — performance (plans, indexes, query shape, request path, memory, caching, capacity, scale, browser)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **cost** class: query plans and indexes, N+1 and query shape, unbounded reads, the
runtime request path, memory growth, caching, capacity, horizontal scale, overload controls, queue
workers, browser load and interaction, and every claim that something is slow.
Correctness classes of the data domain (integrity, concurrency, migrations, tenancy, poolers,
timeouts) are in [`data.md`](data.md). The three cross-domain precedents are in
`refute-before-report.md § 4`.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**; the flip evidence makes it a candidate again.
Numbers are stable: detectors cite `precedents/performance.md § <n>`.

## Measurement and claims

1. **A performance claim without a measurement or an executed scaling oracle is Unconfirmed, never a Finding.** Reading the code can show the *shape* (a query inside a loop); only a counted, planned or timed run shows the *cost*. List it as Unconfirmed with the exact probe from [`proof-oracles.md`](../proof-oracles.md), which usually costs one test run.
2. **A proven defect with no p95 is still a Finding.** When the class oracle fired (query count grows with N, the plan scans, in-flight stays at 1), the finding stands, ranked by an impact model written out and labelled `ESTIMATED` (`N × per-call latency × call rate`). "Speculative" is for claims with no oracle, not for proven defects with no load test.
3. **A delta inside the noise band is `NO-CHANGE`.** Re-run the unchanged baseline at least three times; the spread is the band. A before→after inside it is neither a win nor a regression, and "(noise)" asserted without that spread is not evidence.
4. **A plan from a dev database proves nothing either way.** Plans flip with row counts and statistics: Postgres's own docs warn that results on a toy-sized table cannot be assumed to apply to large ones, because the planner's costs are not linear. Proof is a plan on production-shaped data (a copy, an anonymised clone, or a `generate_series` seed at the production row estimate, then `ANALYZE`), or the production plan from `auto_explain` / `pg_stat_statements`. `SET enable_seqscan = off` proves only that an index *can* be used; `hypopg` plans are estimates.
5. **Statistics that were reset prove nothing.** `pg_stat_statements` and `pg_stat_user_indexes` are cumulative since `stats_reset`; a recent reset, a restart, or a scale-to-zero branch makes "no slow queries" and "unused index" meaningless. Read `pg_stat_database.stats_reset` first.
6. **A micro-benchmark win is not a request-level win** until the function's share of the request is measured (a profile of the real entry point).

## Plans and indexes

7. **A Seq Scan is not a finding on its own.** On a small table, or when the predicate matches a large fraction of rows, a sequential scan is the right plan — on a one-page table Postgres nearly always picks it whether or not an index exists. The finding is a Seq Scan on a table that is large *in production* (row estimate or growth driver cited) with a selective predicate, on a hot path.
8. **A missing FK index is not always a finding.** Postgres never creates an index on the referencing columns itself, and its docs call one "often a good idea" because a parent `DELETE` or key `UPDATE` scans the child — not mandatory. If the parent is never deleted, its key never changes and nothing joins or filters on the column, the index is pure write cost. *Flips back:* a parent delete or key update path, or the column is a join or filter key on a hot path.
9. **Some engines and ORMs create the FK index for you.** MySQL InnoDB creates one on the referencing columns. Django's `ForeignKey` is indexed by default (`db_index=True`), Rails `t.references` adds one, EF Core indexes FK properties by convention, and MikroORM generates an index for a many-to-one on MySQL, MariaDB and SQLite. Not on Postgres: raw `REFERENCES`, TypeORM `@ManyToOne`, Prisma `@relation`, Sequelize, Knex, Drizzle, Laravel `foreignId()->constrained()`, JPA `@JoinColumn`, GORM — and MikroORM (`indexForeignKeys()` returns `false` in `@mikro-orm/postgresql` 6.6.16 and `true` in its other SQL drivers; source read 2026-10-02; on 7.x, dump the DDL). Read the generated migration for the `create index` line before reporting either way.
10. **`idx_scan = 0` does not mean "drop it".** Not when the index backs a PK, unique or exclusion constraint; not when statistics were reset recently (want ≥ 30 days that span month-end jobs); and not until every replica has been checked — usage counters are per node.
11. **The leading-column rule has a version exception.** From Postgres 18, B-tree skip scan can use a multicolumn index when only later columns carry the predicate and the skipped prefix has few distinct values. "An index on (a, b) is useless for `WHERE b = ?`" is still true before 18 and for range predicates. MySQL's skip scan is narrower: one table, no `GROUP BY` or `DISTINCT`, only index columns referenced, equality constants on the parts before the skipped ones, and a range condition on the part after them (MySQL 8.4 manual, *Skip Scan Range Access Method*). Prove it with `EXPLAIN`: `Using index for skip scan` in `Extra`.
12. **An advisor's index proposal is a candidate, not a finding.** dexter, pganalyze, an LLM, or the planner's own suggestion is verified with `hypopg` + `EXPLAIN` and weighed against write amplification: every index slows writes, and an index on an updated column can disable HOT updates. A query with a handful of calls a day does not earn an index.
13. **Some predicates that look non-sargable are not.** `LIKE 'prefix%'` on a `text_pattern_ops` or C-collation column, `lower(email) = ?` with a matching expression index or a `citext` column, and a partial index whose predicate the query repeats exactly all use an index. Infix `'%term%'` needs `pg_trgm`.
14. **UUIDv4 primary keys are a trade-off, not a defect.** Random keys cost index locality on very large, insert-heavy tables (more page splits and buffer reads); on most apps that is Hardening. UUIDv7 (`uuidv7()` built in from Postgres 18) is the remedy when it matters — and leaks creation time, which matters for public ids.

## N+1 and query shape

15. **N+1 is a client/server problem.** SQLite runs in the application's process, so a query is a function call, not a round trip; sqlite.org runs about 200 statements per dynamic page and calls that fine. Also not a finding: N bounded by a small constant fixed by the domain (three currencies, a handful of tabs).
16. **Prisma batches same-tick `findUnique` calls.** `Promise.all(ids.map(id => prisma.x.findUnique({ where: { id } })))` is batched by Prisma's dataloader (Prisma ORM v7 docs). A sequential `for … await findUnique`, and `findFirst`/`findMany` in a loop, are not.
17. **Batched loads are not N+1.** DataLoader-backed resolvers, `IN (…)` per fixed-size chunk, and identity-map hits (MikroORM `em.findOne` or Hibernate `find` by primary key of an entity already loaded in the unit of work issues no query) — show the query log.
18. **A relation already loaded upstream is not N+1.** Read the query that built the list: `populate`, `include`, `select_related` / `prefetch_related`, `includes` / `preload`, `with()`, `JOIN FETCH`, `@EntityGraph`, `Preload`, `Include`.
19. **A repeated identical query answered by the framework's per-request query cache costs no round trip.** Rails' `assert_queries_count` itself skips query-cache hits. It is Hardening unless the per-row work it hides (hydration, allocation) is measured.
20. **Unbounded is about growth, not syntax.** `findMany()` or `.all()` over a lookup, enum or configuration table whose size the domain fixes is fine; the same call on a table that grows with users, orders or events, reached from a request, is the finding.
21. **Fetching rows to count them is right when the rows are used anyway.** Django's optimisation docs: when the data is needed, evaluate the queryset once and use `len()`; `count()`, `exists()` or `contains()` first would each add a query. *Flips back:* the rows are fetched only to be counted.
22. **Streaming the full set is the remedy, not a finding.** An export, report or job that walks a large table with `iterator()`, `find_each`, a server-side cursor or keyset batches is bounded in memory; an admin one-off export that streams is fine.

## Runtime request path

23. **Synchronous APIs are fine outside the request path.** The Node.js guide calls the sync `fs`, `crypto`, `zlib` and `child_process` APIs "intended for scripting convenience" and rules them out *in a server*; at module load, at boot, in a CLI or in a build script they are fine.
24. **Dependent awaits are not sequential-await findings.** The second call uses the first's result, needs its side effect (a write then a read of it), or the downstream enforces ordering or a rate limit. Independence is shown, not assumed.
25. **Fan-out over a constant-size list is bounded.** The finding is `Promise.all` / `gather` / a goroutine per element over a request- or data-sized list with no limiter.
26. **CPU work off the request path is fine** — a worker thread, a queue consumer, a CLI. On the request path the finding needs the input size: `JSON.parse` and `JSON.stringify` are O(n) and bite only at large n (the Node.js guide's example is a 50 MB string).
27. **Thread-per-request servers do not have an event loop to stall.** CPU or blocking work in Spring MVC, a Django sync worker or a Puma thread holds its own worker (and, under a GIL or GVL, competes with the process's other threads). The finding is capacity, measured in worker-seconds; the event-loop-delay oracle does not apply. In WebFlux, Netty or an async Python or Node server, it does.
28. **Python caches compiled regular expressions.** The `re` docs state that compiled versions of the most recent patterns passed to `re.compile()` and the module-level functions are cached, so `re.match(p, s)` per call is usually not a recompile. Benchmark within the noise band before reporting.
29. **A thin client wrapper built per call over a shared agent or pool costs an object, not a connection.** The finding is a new agent, pool or connection per call (`new https.Agent()`, `new Redis()`, `new pg.Pool()`, `httpx.Client()` inside a handler); prove it with the socket-count oracle rather than the constructor name.

## Memory

30. **A module-level map keyed by a domain-bounded set is a cache, not a leak** — currencies, feature flags, one compiled template per file. *Flips back:* the key comes from requests, users or ids.
31. **One heap snapshot, or one RSS reading, is not a leak.** A leak is growth across at least three batches, proportional to N, that survives a forced GC. RSS that plateaus after warm-up is the allocator keeping memory, not a leak.
32. **A bounded cache is bounded.** An LRU with `max` (and a TTL where staleness matters), or a `WeakMap` keyed by objects the request owns, is not a growth finding.
33. **A unit of work scoped to the request is bounded.** A request-scoped EntityManager (MikroORM `RequestContext` / `fork()`, a Hibernate session per request) holds only that request's entities; the finding is one unit of work carried across a worker loop or batch without `clear()` / `fork()`, or MikroORM's `allowGlobalContext: true` on a request path.

## Caching

34. **Immutable or content-addressed keys need no TTL** — hash-named static assets, versioned keys (`v3:…`), memoised pure functions of their key. Stale reads inside a documented TTL are the design, not a bug.
35. **A key without a tenant dimension is fine for genuinely global data** — a public catalog, feature-flag definitions. *Flips back:* any field of the cached value is scoped by tenant, user, locale or permission; that is a cross-tenant read and routes to security.
36. **"A cache in front" clears nothing on its own.** It counts as a control only when its key covers this path, its hit ratio is measured, and the miss path is bounded (single-flight on hot keys).

## Capacity and volume

37. **A bigger pool is not a fix.** Connections beyond what the database's cores and disks can serve add contention: HikariCP's pool-sizing notes cite an Oracle demo where shrinking a pool from 2048 to 96 cut response time from about 100 ms to about 2 ms. The finding is per-instance pools × instances exceeding the server's budget, not a small pool.
38. **An unbounded list on a public endpoint is a Finding here** when the table grows with data — a capacity defect — even though security calls volume-only DoS Hardening. Both views are right; this domain owns it.
39. **Admin and back-office paths are not exempt.** Their call rate is low and their N is the largest in the system (exports, "all tenants" reports); weigh call rate × N, not the role.
40. **A load test proves capacity only at stated parity** — instance size, data volume, pool and replica count. A number from a laptop or an empty staging database is not evidence about production.

## Measurement validity — when a measured delta is not real

41. **Three runs per side can never be significant.** An exact two-sided Mann-Whitney test at 3 vs 3 cannot go below p = 0.10, so Go's `-count=3` never yields a significant benchstat line; 4 vs 4 reaches 0.029. Take at least 10 runs per side, never fewer than 5.
42. **Re-running until p < 0.05 is p-hacking.** Across 40 benchmarks, two "significant" results at α = 0.05 is exactly the expected false-positive count; replicate the direction before believing one.
43. **Significant is not relevant.** A 0.3% shift under a 1–2% practical floor is reported as "no meaningful change", whatever its p-value.
44. **All-A-then-all-B measures drift.** Thermal throttling, turbo and background load move between blocks; interleave A and B runs.
45. **Cold against warm is not a comparison.** Page cache, JIT, connection pools and application caches must be in the same state on both sides; a "first run slower" warning is the tell.
46. **Shared CI runners are noisy.** A 2% wall-clock gate on GitHub-hosted runners (CV ≈ 2.7%) raised about 45% false alarms in CodSpeed's measurement; gate there on counts (queries, allocations, bytes), or on a threshold above the measured noise. A baseline from another runner, OS, CPU or tool major version is not comparable.
47. **A "1000× faster" micro-benchmark measured nothing.** The result was unused and eliminated as dead code, a literal input was constant-folded, or a hand-written loop was hoisted; JMH with `forks=0` adds profile pollution.
48. **A closed-model load test understates the tail.** Constant virtual users, plain `wrk`, `hey`, Locust, or `autocannon` without a rate suffer coordinated omission. An open model that dropped iterations, or reached less than its target rate, measured a lower load than claimed; a generator on the same host, or above 80% CPU, measured itself.
49. **p99 averaged across pods or runs means nothing.** Merge the histograms. A better mean or p50 with a worse p99 or max is a tail regression.
50. **Faster because it failed is not faster.** Latency that fell while errors rose (fast 5xx, an open breaker), or throughput that rose because responses shrank, were truncated or were cached, is a regression in disguise.
51. **Debug builds, emulators and single runs are not evidence.** A dev build (React dev, `next dev`, a debug binary), a simulator timing, or one Lighthouse run (±5–10 points) proves nothing either way.
52. **One side paid for a GC cycle.** When the claim is about allocation, compare allocations per operation (a deterministic count), not time.

## Version-aware precedents — check the version before flagging

Each entry names the version condition. Below the condition the pattern is still a candidate; at or
above it, it is Hardening at most. Read the version from the lockfile or manifest (gate 3).

53. **`synchronized` + blocking I/O under virtual threads** — not a finding on **JDK ≥ 24** (JEP 491); pinning remains for native/FFM frames, class initialisation and symbolic resolution.
54. **`time.After` or an unstopped `time.Ticker` in a loop** — not a leak in a module declaring **Go ≥ 1.23** (timers are collectable); staticcheck SA1015 is moot there.
55. **No `automaxprocs` in a container** — not a finding on **Go ≥ 1.25** (GOMAXPROCS follows the cgroup CPU limit).
56. **Python objects with `__del__` in reference cycles** — collectable since **Python 3.4** (PEP 442).
57. **`try`/`except` inside a loop** (Ruff PERF203) — micro only on **Python ≥ 3.11** (zero-cost exceptions).
58. **GIL contention** — not a finding on the **free-threaded Python 3.14** build when `sys._is_gil_enabled()` is false (PEP 779).
59. **Missing `useMemo` / `useCallback`, inline object or function props** — not a finding with **React Compiler 1.0** on (Next `reactCompiler: true`, Expo SDK 54 default, the Vite 8 preset) unless the component opts out with `'use no memo'`.
60. **Compose "unstable parameter" or unstable lambda** — not a finding on **Kotlin ≥ 2.0.20** with strong skipping (lambdas remembered; parameters compared by identity).
61. **No `inlineRequires` in a React Native `metro.config.js`** — `@react-native/metro-config` defaults it to `true`.
62. **Missing `const` constructors in Flutter** — low value since **`flutter_lints` 5.0.0** removed those lints. **Shader-compilation jank** — not a finding with **Impeller** on (the only renderer on iOS; default on Android API 29+) unless the app opted out.
63. **R8 full mode not enabled** — default on from **Android Gradle Plugin 8.0**.
64. **Barrel imports of `lucide-react`, `date-fns`, `lodash-es`, `@mui/*`, `rxjs` and similar** — not a finding for packages on **Next.js's `optimizePackageImports` default list**.
65. **Missing `trackBy` or OnPush** — not a finding on **Angular ≥ 21** zoneless-by-default with signals; on **≥ 22** OnPush is the default (flag an explicit `Eager`).
66. **`n/no-sync` at module top level** — never a finding (boot code; the rule's `allowAtRootLevel`).
67. **Prisma per-row `findUnique` inside `Promise.all`** — batched on **Prisma 2.x through 7** when the calls share a tick and a scalar-equality `where`; unverified on the Prisma 8 release candidate.
68. **A lazy-loading guard as N+1 proof** — never sufficient on **Laravel ≥ 12.15** with automatic eager loading on (`automaticallyEagerLoadRelationships()`, 12.8+, suppresses the violations): prove it with a query count.
69. **MikroORM sibling to-many `populate` (cartesian explosion)** — not the default risk on **MikroORM 7** (`loadStrategy: 'balanced'`, select-in for to-many); still a candidate on v6 (default `joined`) or wherever `joined` is set.

**Defects an upgrade introduced, or kept** — these flip the other way:

70. **Pool with no acquire timeout after Prisma 6 → 7.** The v7 `pg` driver adapter's acquire timeout is 0 (wait forever), where v6's `pool_timeout` was 10 s: a new finding on upgrade.
71. **Node's 5 s `keepAliveTimeout` behind a load balancer** — still a finding through **Node 26**; the 65 s default is merged for the next major but unreleased (nodejs/node PR #62782). Confirm the release before clearing it.

## Horizontal scale, overload and queues

72. **An outer deadline or a client factory sets the timeout.** A call with no timeout in its own arguments is covered when the shared client's factory sets one, or an outer deadline wraps it (`AbortSignal.timeout`, `context.WithTimeout`, a resilience TimeLimiter, a gRPC deadline): read the factory before reporting. Library defaults decide the rest — httpx 5 s per phase and .NET `HttpClient` 100 s set one; Node `fetch` (undici) has no total deadline, axios's `timeout` is 0 and Python `requests` has none. An intentional long-poll with an idle timer is not a missing timeout. *Flips back:* the deadline is per phase while the body may drip forever, or the caller's budget is shorter than the callee's timeout × attempts.
73. **One replica by design is latent, not refuted.** No autoscaler, one process per container and a written single-replica decision make every horizontal-scale row `latent (one replica)`: Hardening until the shape changes. *Flips back:* an autoscaler, a second worker fleet, several processes per container (PM2 cluster mode, gunicorn or Puma workers, `WEB_CONCURRENCY`), or a move behind a load balancer.
74. **Signed, stateless sessions scale.** A signed cookie, or a token verified with a secret or key shared through the environment or a KMS, needs no session store. Stickiness used only for a Socket.IO long-polling handshake is not "sticky sessions relied on". *Flips back:* the secret is generated per process at boot, or the session, the CSRF token, an OAuth `state` or a PKCE verifier is held in memory.
75. **A shared store is the control.** Limiters, sessions, caches, dedupe sets and locks kept in Redis or the database are shared by every replica; an L1 with a short TTL and pub/sub or versioned invalidation in front of a shared L2 is coherent by design; immutable reference data needs neither. A lock that only saves work (a duplicate run is harmless) needs no fencing token. *Flips back:* the limiter's or lock's store is the library's in-memory default, or the lock guards a side effect and the resource checks no fencing token.
76. **One scheduler is the control.** A single-replica scheduler Deployment, a Kubernetes CronJob or cloud scheduler that enqueues, a database lock (ShedLock, Quartz JDBC clustered, Laravel `onOneServer`, `pg_try_advisory_xact_lock`), or a database-deduped recurring queue (solid_queue, good_job) runs each tick once. *Flips back:* the lock is a lease with no fencing while the job has side effects, or a CronJob runs non-idempotent work without `concurrencyPolicy: Forbid`.
77. **A migration that runs once, or under a lock that waits, does not race.** A migration Job, an init container, a Helm hook or a platform release phase runs once per release. At boot, only a runner that takes a cross-process lock **and waits** clears it, read at the installed version from the table below (owner of the class: devops `deploy-safety-scan` §1, whose measured lock column this table carries; performance `request-path-scan` §20 and `precedents/distributed.md` § 24 cite it). ORM auto-sync at boot is never cleared by this precedent. *Flips back:* the runner is a **No** row, or a **Waits** row behind a transaction-mode pooler, or a migration can outlast the wait while siblings boot.

| Runner (version read) | Lock at boot | Behaviour of the other replicas | Source |
|---|---|---|---|
| MikroORM (6.6.16; migrations 7.2.5) | **No** | each runs the migration: a DML migration applied once per replica, DDL crashes the others | measured 2026-10-10 (devops eval); package source 2026-10-14 |
| TypeORM (1.1.2) | **No** (a transaction, no lock) | run concurrently | `MigrationExecutor.js`, 2026-10-14 |
| Sequelize + umzug (3.8.3) | **No** cross-host lock (`FileLocker` is per host, opt-in) | run concurrently | `lib/file-locker.js`, 2026-10-14 |
| Drizzle (0.45.4; 1.0 rc) | **No** (reads the last row outside the transaction) | run concurrently; a migration merged with an older timestamp is silently skipped | `pg-core/dialect.js`, 2026-10-14 |
| Django (6.1.2) | **No** | run concurrently | `migrations/executor.py`; ticket #30490 (wontfix) |
| Alembic (1.20.0) | **No** (users add `pg_advisory_lock` in `env.py`) | run concurrently | `runtime/migration.py`, 2026-10-14 |
| Doctrine Migrations | **No** | run concurrently | backend research C § 3, source read 2026-10-14 |
| Laravel `migrate --isolated` | cache mutex, **skips** | a held or stale mutex (default expiry 1 h) **skips the migrations and exits 0**; `--isolated=1` makes the skip exit non-zero | backend research B-P20d, 2026-10-14 |
| Rails | advisory lock, **fails fast** | the others raise `ConcurrentMigrationError` (a crash-loop, not a wait); breaks under a transaction-mode pooler | `activerecord/lib/active_record/migration.rb`, 2026-10-14 |
| Prisma Migrate (8.0.0-rc.22) | advisory lock, **waits 10 s** | after 10 s the others fail (P1002) and crash-loop on a long migration; `PRISMA_SCHEMA_DISABLE_ADVISORY_LOCK` removes the lock | prisma docs, 2026-10-14 |
| Flyway · Liquibase | **Waits** (PG advisory lock · `DATABASECHANGELOGLOCK` row, up to 5 min) | wait; a killed Liquibase process leaves the row locked | Redgate docs; `StandardLockService.java`, 2026-10-14 |
| Knex (3.3.0) · golang-migrate (v4.20.1) · EF Core ≥ 9 | **Waits** (`knex_migrations_lock` in a transaction · `pg_advisory_lock` · `Migrate()`, `database update`, bundles) | wait; SQL scripts from EF Core take no lock, and its SQLite lock table can be abandoned | `Migrator.js`; `database/postgres/postgres.go`; EF Core 9 *What's new*, 2026-10-14 |
| goose (v3.29.0) | **Opt-in** (`NewPostgresSessionLocker` passed to the Provider) | without it, run concurrently | goose `lock/postgres.go`, 2026-10-14 |

The dated rows with their sources are also `broker-semantics.md` MG1–MG14.
78. **Broadcast, files and background work have shared forms.** A Socket.IO adapter (Redis, Postgres, cluster) or a managed fan-out (Pusher, Ably, API Gateway WebSockets, Azure SignalR) reaches every replica; uploads streamed to object storage, or a deliberate shared (RWX) filesystem, are visible everywhere, and a scratch file consumed inside the same request is fine; an outbox row drained by a worker is durable. Losing best-effort telemetry or cache warming on a restart is an accepted loss. *Flips back:* the event, file or job must reach another replica or survive the process, and nothing above carries it.
79. **Overload controls may live at the edge.** An ingress `limit_req` / `limit_conn`, a gateway rate limit, a serverless concurrency limit, or a bounded executor with a rejection policy counts as admission control once read; a proxy (nginx, Envoy) that terminates keep-alive with correct settings closes the keep-alive mismatch behind it. Absence of load shedding alone is Hardening. *Flips back:* the setting is not in the repo and nobody has read it — the row is Unconfirmed with the setting to read, never cleared by assumption.
80. **Readiness may follow a per-pod dependency.** A local warm-up, a sidecar or the pod's own cache may gate readiness, and a written "no degraded mode" decision makes readiness on a shared dependency a choice. Liveness on a shared dependency is never cleared by this.
81. **Queue settings that look wrong may be deliberate.** A serial queue for per-key ordering, CPU-bound workers at concurrency = cores, low concurrency as the intended throttle on a downstream, a heartbeat that extends the lock or visibility, an idempotent consumer with a dedupe key (redelivery is then harmless), and a dead-letter queue configured in a separate infrastructure repo (read it) are not findings. *Flips back:* the cited arithmetic shows the backlog growing, or a side effect has no dedupe.
82. **Synchronised load needs synchronised triggers.** TTLs with a random component or probabilistic early refresh, schedules spread across the hour, reconnect loops with jittered backoff, and a dependency that scales per tenant do not herd. *Flips back:* every tenant's job fires at the same minute, or co-written keys share one TTL.

## Browser load and interaction

83. **`loading="lazy"` below the fold is correct** — images under the first viewport, carousel slides after the first. Lazy on the LCP element is the finding.
84. **A lazy route chunk is not initial-load cost.** A large `dynamic()`, `React.lazy`, `defineAsyncComponent` or `loadComponent` chunk is paid when the route or island opens, not on first load.
85. **High Total Blocking Time with good field INP is not an INP defect.** TBT is a lab proxy; the field p75 decides.
86. **`async`, `defer` and `type="module"` scripts are not render-blocking.** Judge a third party by its main-thread time (LoAF `scripts[].sourceURL`, `third-party-summary`), not by its presence.
87. **A text LCP needs no `fetchpriority` and no preload.** Those are for a resource the browser has to discover and fetch.
88. **Duplicate packages only in server bundles cost the client nothing** — React Server Components, API routes, server-only modules. Prove the duplicate in the client build's bytes before reporting.
89. **`@vitejs/plugin-legacy` nomodule bundles are skipped by modern browsers.** They are not legacy JavaScript that modern users download.
90. **Dev-server numbers are meaningless.** Chunk sizes and timings from `next dev` or a Vite dev server, and React StrictMode's double render and double effect in development, say nothing about production; measure `next build && next start`, `vite build && vite preview`, or the deployed site.
91. **A keep-alive chain is ordered hop by hop.** At every proxy hop the upstream idle timeout must be shorter than the next hop's client keep-alive timeout; inverted, a request sent on a connection the next hop has just closed comes back 502. Read each hop's value, or its default for the installed version labelled `DEFAULT`: Caddy `reverse_proxy` → `transport http { keepalive }` 2m; ingress-nginx ConfigMap `keep-alive` 75 s and `upstream-keepalive-timeout` 60 s (both docs read 2026-10-15); Node `keepAliveTimeout` 5 s (§ 71). A hop that sets nothing has its default, never "no limit". *Not a finding:* each downstream hop keeps the connection longer than the hop in front of it reuses it.
92. **A fleet lock guards only what runs after it.** A scheduled method that deletes, sends or writes before its first leader-lock call runs those effects on every replica; the lock taken later guards the rest. Idempotent effects make it repeated work (MEDIUM), non-idempotent ones duplicate side effects. *Not a finding:* the effect is per replica by design — the replica's own sockets, temp files or in-memory state.

---

Sources (accessed 2026-10-02): PostgreSQL 18.6 docs — *Using EXPLAIN* (§ Caveats), *Constraints*
(Foreign Keys), PostgreSQL 18 release notes (2025-09-25); SQLite, *Many Small Queries Are Efficient
In SQLite* (<https://www.sqlite.org/np1queryprob.html>); Prisma ORM v7 docs, *Query optimization*;
Rails 7-2-stable `activerecord/lib/active_record/testing/query_assertions.rb`; Django 5.2 docs,
*Database access optimization*; Node.js docs, *Don't Block the Event Loop*; Python 3 docs, `re`
module; HikariCP wiki, *About Pool Sizing* (last edited 2021-12-07); Cybertec, *Unexpected downsides
of UUID keys in PostgreSQL* (2023-06). The noise-band rule is the performance pack's own
(`rules/performance-principles.md`). § 41–71 come from the performance research catalog for this
pack (2026-10-02), which cites: Mann-Whitney exact bounds and benchstat (golang.org/x/perf);
CodSpeed's runner-noise measurement; Barrett et al. (OOPSLA 2017) and Mytkowicz et al. (ASPLOS
2009) on benchmark validity; Grafana k6 docs on open and closed models; OpenJDK JEP 491; the Go
1.23 and 1.25 release notes; PEP 442 and PEP 779; the React Compiler 1.0 announcement
(react.dev, 2025-10-07); Android's strong-skipping guide (2026-01-16) and R8 docs; the Flutter
Impeller docs and `flutter_lints` changelog; the Next.js `optimizePackageImports` docs; Angular
release notes; eslint-plugin-n docs; laravel/framework #55771; Prisma v7 connection-pool docs;
nodejs/node #62782; MikroORM 7.2.3 source (2026-09-30). § 72–82 come from the same catalog's
resilience (RS) and horizontal-scale (SC) rows and their false-positive columns (library timeout
defaults; Socket.IO *Using multiple nodes*; the APScheduler FAQ; Quartz clustering; Kubernetes
CronJob and probe docs; Prisma, Rails, Flyway, Liquibase, Knex and golang-migrate migration locks).
§ 83–90 come from its frontend notes (web.dev on lazy loading, LCP and INP; Lighthouse docs; the
Next.js package-bundling and Script docs; the `@vitejs/plugin-legacy` README). Paraphrased; no text
reproduced beyond short quoted phrases.
