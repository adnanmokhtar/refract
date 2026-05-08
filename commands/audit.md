---
description: One command full-stack engineering audit. Scans the codebase against system-design + engineering principles — architecture quality, SOLID, clean code, maintainability, security (OWASP + auth + tenant + secrets + deps), database performance (schema + indexes + query plans), runtime performance (N+1, hot paths, caching), scalability + resilience (fan-out, sync I/O in critical path, lock contention, queue back-pressure, write amplification, blast radius, capacity headroom), infrastructure + capacity, observability gaps. **Works on ANY codebase — any language, any framework, any project shape: backend (Node / Python / Go / Java / Ruby / .NET / Rust / Elixir / PHP / Kotlin / Scala / Haskell / OCaml), frontend (Vue / React / Svelte / Angular / Solid / Qwik / vanilla), mobile (iOS / Android / React Native / Flutter), data (SQL / NoSQL / pipelines / streaming), CLI / TUI tools, libraries / SDKs, serverless / edge functions, monoliths, microservices, monorepos.** Each axis routes through `PROJECT_KIND` so the SAME 13 scale-lens detectors apply meaningfully whether the artefact is an HTTP request handler, a route component mount, a screen render, a CLI subcommand, a library entry point, or a Lambda invocation. Detects gaps across ALL axes in one pass, generates a unified prioritized fix plan ranked by `impact-at-target-scale × blast-radius × fix-cost`, then fixes in parallel waves. NO phases visible, NO terminology, NO mid-run questions. Output is brief: critical scale-blockers FIRST, axis-specific findings second, commits, diff stats, test status, perf wins. The simple-surface alternative to running /optimize + /security-audit + /db-audit + /perf-audit + /design-system separately.
kind: command
pack: orchestration
---

# /audit [<scope>] [--target-rps=<N>] [--target-p95=<ms>] [--plan-only]

## What this does

**Single command. Audit the codebase against engineering + system-design principles, generate a fix plan, execute it.** Deep multi-agent scan + scale-first cross-axis ranker + parallel fix waves. Whole project or scoped.

**Universal across stacks.** Works on:

- **Backend services** — REST / GraphQL / gRPC / tRPC / JSON-RPC / WebSocket / SSE / message-driven; any framework (Express / NestJS / Fastify / Koa / Hapi / Django / Flask / FastAPI / Starlette / Rails / Sinatra / Hanami / Laravel / Symfony / Lumen / Spring / Quarkus / Micronaut / Ktor / ASP.NET / Phoenix / Echo / Gin / Fiber / Actix / Axum / Rocket / Warp / Vapor / Genie); any language (Node / TS / Python / Ruby / PHP / Java / Kotlin / Scala / C# / F# / Go / Rust / Elixir / Erlang / Crystal / Haskell / OCaml / Swift / Julia).
- **Frontend apps** — SPA / SSR / SSG / ISR / streaming-SSR / islands / RSC / static; any framework (Vue 2/3 / Nuxt / React / Next / Remix / Svelte / SvelteKit / Solid / SolidStart / Qwik / Astro / Angular / Lit / Stencil / Preact / Inferno / vanilla / jQuery legacy).
- **Mobile** — iOS native (Swift / SwiftUI / UIKit / Obj-C), Android native (Kotlin / Compose / Java / XML), React Native, Flutter, Expo, Capacitor / Ionic, Xamarin / .NET MAUI, Kotlin Multiplatform.
- **Data layer** — relational (Postgres / MySQL / MariaDB / SQL Server / Oracle / SQLite), document (Mongo / Couch / DynamoDB / Firestore), key-value (Redis / Memcached / KeyDB / Etcd), wide-column (Cassandra / ScyllaDB / HBase), graph (Neo4j / Dgraph), search (Elasticsearch / OpenSearch / Meilisearch / Typesense), time-series (Influx / Timescale / Prometheus), warehouse (Snowflake / BigQuery / Redshift / Databricks); pipelines (Airflow / Dagster / Prefect / Luigi / dbt); streaming (Kafka / Pulsar / Kinesis / RabbitMQ / NATS / Redpanda).
- **CLI / TUI tools / scripts / libraries / SDKs** — startup time, memory ceiling, fork bomb risk, lazy-load gaps, public API surface contract.
- **Serverless / edge** — AWS Lambda, Cloudflare Workers, Vercel Edge, Deno Deploy, Fastly Compute, Azure Functions, GCP Cloud Functions, Cloud Run, Fly Machines.
- **Monorepos / polyglot** — Nx / Turborepo / Bazel / Pants / Buck / Lerna / Rush / pnpm workspaces / Yarn workspaces / Cargo workspaces / Go workspaces / Gradle multi-project / Maven multi-module. Each project under PROJECT_KIND detection — `/audit` runs the right axis routing per project.
- **Containers / orchestration / IaC** — Docker / Podman / Buildah / Kaniko; Kubernetes / OpenShift / Nomad / ECS / Fargate / Cloud Run; Terraform / Pulumi / CDK / CloudFormation / Bicep / Ansible / Chef / Puppet — infra axis adapts.

**Stack-agnostic by construction**, not by accident. Three load-bearing mechanisms:

1. **`PROJECT_KIND` routes detectors.** Every detector is shape-based, not name-based. A "hot path" is `every entry-point × invoke-rate × cost-per-invoke` — concrete entry-point shape varies (HTTP handler, route mount, screen render, CLI subcommand, Lambda invoke, library export, cron task, queue consumer), but the detector logic is the same. Resolved from `_extracted-codebase.md` / `codebase-profile.md` / `_extracted-idioms.md` anchors.
2. **Specialist agents are themselves stack-agnostic.** `architectural-diagnosis` reads dependency graphs (works for any import system); `security-auditor` checks OWASP Top 10 (universal); `database-optimizer` adapts to whichever DB the project uses; `system-architect` reasons about boundaries and ownership; `performance-optimizer` covers N+1, sequential awaits, sync I/O, missing cache — all language-agnostic patterns.
3. **No hard-coded language tokens.** No grep for `app.get(` or `useState`. The agent reads the project's idioms file, learns its primitives, then runs the universal detectors against those primitives. New stack = no detector change.

The agent:

1. **Detects gaps across ALL principle axes in one pass** — not one axis per command, not "run /optimize then /security-audit then /db-audit". One scan, all axes:

   **Architecture quality** (own + dispatch via `architectural-diagnosis`):
   - Layer violation, cyclic dependency, bottleneck module, god module, anemic module, wrong-level responsibility, cross-cutting duplication, missing abstraction.

   **SOLID / clean code / maintainability** (dispatch via `core-discipline.md` + `refactoring-sweep`):
   - SRP/OCP/LSP/ISP/DIP violations, long functions, deep nesting, magic numbers, bad naming, redundant comments, dead code, dedup, over-abstraction.

   **Security** (dispatch `security-auditor` + `auth-reviewer` + `secret-scan` + `deps-audit` + `threat-model`):
   - OWASP Top 10 + Top 25 CWE, auth/session/JWT/oauth flaws, tenant-isolation leaks, hard-coded secrets, vulnerable dependencies, missing input validation, SQLi / XSS / SSRF / CSRF / IDOR / mass assignment, broken access control, sensitive-data exposure in logs.

   **Database performance** (dispatch `database-optimizer` + `query-optimizer` + `schema-reviewer` + `schema-consistency-audit`):
   - Missing indexes, wrong index shape (composite ordering), unbounded `SELECT *`, N+1, sequential scans on large tables, missing pagination, no batch insert, no connection pool sizing, no read replica routing, no query timeout, transaction-too-long, lock-escalation patterns, write amplification, missing FKs / cascading deletes, schema drift.

   **Runtime performance** (dispatch `performance-optimizer` + `caching-architect` + `n-plus-one-scan` + `profile-endpoint`):
   - Sequential awaits where parallelism is safe, sync external HTTP in hot paths, missing cache at known-cacheable sites, in-app filtering pushable to DB, payload bloat, render thrash, bundle bloat.

   **Scalability + resilience** (the differentiating axis — dispatch `system-architect` + `resilience-reviewer` + own 13 scale-lens detectors). Each detector routes through `PROJECT_KIND` so the SAME axis applies to every stack — only the concrete fingerprint changes. Stack-conditional detector matrix:

   | # | Scale-lens axis | Backend service | Frontend app | Mobile | CLI / library / SDK | Serverless / edge | Data pipeline / job |
   |---|---|---|---|---|---|---|---|
   | 1 | **Hot-path scan** | every endpoint × RPS × cost-per-call | every route mount × visit-rate × LCP cost | every screen × open-rate × jank cost | every subcommand / public function × invoke-rate × wallclock | every handler × invoke-rate × billed-ms | every step × per-batch row count × stage time |
   | 2 | **Fan-out depth** | 1 request → N downstream HTTP/DB/RPC calls | 1 route mount → N waterfall fetches (network waterfall) | 1 screen → N RPC waves on appear | 1 invoke → N subprocess / subtask calls | 1 invoke → N downstream calls (SQS / EventBridge / DDB) | 1 task → N source/sink calls |
   | 3 | **Sync I/O in critical path** | sync external HTTP in request handler (no circuit breaker / timeout) | sync XHR (`async:false`), sync `localStorage` parse on render, blocking long task on main thread | sync network on UI thread, sync disk on main thread | sync HTTP / DNS in fast-path command | sync external HTTP without timeout (cold-start budget killer) | sync I/O in batch loop (should be batched / parallelised) |
   | 4 | **Single-instance bottleneck** | one module every request funnels through | one component / store every render funnels through | one singleton / coordinator every screen depends on | one global mutex / global registry | one warm-pool dependency that pins concurrency | one shared resource serializing the pipeline |
   | 5 | **Lock contention** | long DB transactions, table-level locks, advisory locks across I/O, optimistic-lock retry storms | long main-thread tasks (>50 ms), layout thrash, sync-rendering loops | UI thread blocking, ANR risk windows | fcntl / file locks, global mutex contention | DDB conditional-write contention, per-shard lock | cluster lock primitive contention (ZK / Etcd) |
   | 6 | **Queue back-pressure** | producer without bounded buffer, consumer without rate limit, no DLQ, no replay path | unbounded `setState` / `dispatch` flood, unbounded `MessageChannel` queue, unbounded service-worker fetch queue | unbounded UI event queue, unbounded background-task channel | unbounded stdin reader, unbounded subprocess fan-out | unbounded EventBridge / Kinesis fan-in, no DLQ | unbounded source backlog, no checkpoint, no retry budget |
   | 7 | **Write amplification** | 1 user action → N row inserts (cascading writes, missing batch) | 1 user action → N component re-renders, N store updates, N localStorage writes | 1 tap → N redraws, N animation-frame mutations | 1 invoke → N log lines / temp files / network calls | 1 invoke → N DDB writes / SNS publishes | 1 input row → N output rows (unbounded fan-out) |
   | 8 | **Tenant blast radius** *(multi-tenant only — N/A for single-tenant / consumer / library)* | one slow tenant query stalls shared pool; missing per-tenant rate-limit / pool partition / circuit breaker | one tenant theme bundle bloats shared bundle for all tenants; cross-tenant CSS leakage | n/a (per-user, not per-tenant) | n/a | one tenant's burst exhausts shared concurrency | one tenant skews shared cluster |
   | 9 | **Capacity headroom** | RPS-now vs target-RPS, peak-RPS vs spare capacity | bundle size vs target, FCP/LCP vs target, JS heap ceiling | APK/IPA size vs target, cold-launch time vs platform target, memory ceiling | startup time × invoke-rate, memory ceiling vs RAM budget | concurrency × billed-ms vs free-tier ceiling, package size vs cold-start budget | throughput vs SLA, lag vs target |
   | 10 | **SLO-vs-actual delta** | observed p50/p95/p99 vs declared SLO per endpoint | Lighthouse / web-vitals (FCP / LCP / TTI / CLS / INP) vs target | jank rate, ANR rate, frame-time p95 vs target | wallclock target vs measured | p99 invoke duration vs target, cold-start ratio vs target | end-to-end lag vs SLA, success rate vs target |
   | 11 | **Idempotency gaps** | write endpoints without idempotency key; retries cause duplicate state mutations | form-submit re-fire on double-click or navigation, optimistic-update reconcile drift | tap-spam, retry-on-network-recover causing duplicate writes | re-runnable subcommands; partial-success cleanup | retry without idempotency token; SNS at-least-once duplicate handling | source replay → duplicate rows downstream; missing dedup key |
   | 12 | **Statelessness violations** | in-process caches without invalidation, in-memory rate limiters, in-memory sessions, in-memory locks (none scale horizontally) | in-component state that should be in store / URL / server, prop-drilling deep state | in-app singletons that don't survive process death, missing state restore | cwd / env / temp-file assumptions that break under parallel invocation | warm-instance assumptions, `/tmp` cross-invoke leakage | in-worker accumulators without checkpoint |
   | 13 | **Cold-start cost** | boot time × restart frequency × replica count (rolling-deploy stall risk) | bundle parse + first paint, hydration cost, font/css load sequence | cold-launch time, prewarm absence, dex/PGO budget | import startup, lazy-load gaps, eager top-level work | unzip + init time × cold-rate × billed-ms penalty | DAG cold-start, executor warmup, JIT warmup |

   The detector's *logic* is universal; the *fingerprint* the agent looks for adapts per `PROJECT_KIND`. A detector that has no meaningful fingerprint for a given `PROJECT_KIND` is marked N/A and skipped — not silently ignored. Multi-tenant axis (#8) is the only axis that's gated on a tenancy-anchor; everything else applies to every stack.

   **Polyglot monorepo handling**: when scope spans multiple `PROJECT_KIND` (e.g., a Next.js frontend + a NestJS API + a Python data pipeline), each subdirectory's PROJECT_KIND drives axis routing for that subtree. Per-tier fixes still cross subtrees when blast-radius requires it (e.g., adding idempotency keys to the API also requires the frontend retry handler to send them — `/audit` files both fixes under the same plan row).

   **Infrastructure + capacity** (dispatch `infra-architect` + `k8s-reviewer` if infra files present):
   - Missing horizontal pod autoscaler, no readiness/liveness probes, missing resource requests/limits, single replica for stateful services, no PodDisruptionBudget, no spread constraints, no graceful shutdown, missing connection-pool sizing relative to replica count.

   **Observability gaps** (dispatch `observability-reviewer` + `telemetry-architect` + `sre-engineer`):
   - Missing structured logs at boundaries, missing trace propagation, missing histogram metrics for latency, missing error-rate / saturation / utilization counters, no SLO dashboard, no alert on error budget burn, no per-tenant metrics (multi-tenant only).

2. **Cross-axis ranks findings** by `impact-at-target-scale × blast-radius × fix-cost` — NOT by axis. A missing DB index on a hot path that fires 10K times/sec ranks above a clean-code finding in test fixtures, and above a SOLID violation in a cron job. A scale-blocker (silent corruption under load, irrecoverable saturation, unbounded memory growth) ranks above everything else.

   Rank tiers (internal, surfaced in plan):
   - **P0 — scale-blocker** — would cause an incident at target RPS (corruption, deadlock, OOM, irrecoverable failure).
   - **P1 — security/correctness** — exploitable security gap OR observable correctness bug.
   - **P2 — high-leverage scale fix** — touches a hot path, measurable p95 / cost win.
   - **P3 — architectural foundation** — cascades many downstream findings (same dispatch as `/optimize` Phase 0).
   - **P4 — tactical cleanup** — clean code, dedup, refactoring, dead code.

3. **Generates ONE unified plan** at `ai/audit/plan.md` — all findings, ranked, with closure verb + estimated fix cost + dependency on other findings. NOT one plan per axis.

4. **Executes the plan** — P0 blockers FIRST (sequentially, with verification), then P1 (sequential, with assertions added), then P2 (parallel waves with measurement), then P3 (architectural foundations, sequential — each cascades dissolves P4 candidates), then P4 (parallel waves). After each phase, re-detects against the now-changed tree.

5. **Behaviour-preserving** for architectural / refactoring / dead code / dedup. **Behaviour-changing where safe** for perf + scale fixes (parallelize, batch, cache, circuit-breaker insertion) — adds assertions in same commit. **Security fixes always ship with regression test in same commit.**

6. **Halts ONLY on genuine blockers** — fix would change observable behaviour where it must be preserved (re-classify, surface to user); idiom missing (e.g., user wants Redis but project has no cache primitive); cross-PR decoupling required (surfaces a small plan); infra change beyond mechanical (e.g., add HPA — surfaces ops ticket).

Output: P0 scale-blockers FIRST, then ranked findings, commits, diff stats, test status, perf wins (measured), capacity-headroom delta.

## When to use

- "Audit the whole project for engineering + scale issues." → `/audit`
- "Are we ready for 10× traffic?" → `/audit --target-rps=50000 --target-p95=200`
- "Audit the orders module against SOLID + perf + security." → `/audit the orders module`
- "What would block us from going to 100K RPS?" → `/audit --target-rps=100000 --plan-only`
- "Pre-launch hardening sweep." → `/audit`

## When NOT to use

- For UI/UX visual / design work → `/enhance-ui` or `/ui-sweep` or `/polish`.
- For V1→V2 port → `/migrate`.
- For convention drift specifically (without scale lens) → `/align`.
- For code-quality only (no security, no scale lens) → `/optimize`.
- For new features / bug fixes → `/add-feature` / `/fix-bug`.
- For pre-launch security sign-off (regulatory) — pair `/audit` with `/security-audit` for a second pass + the project's external SAST.

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.
- `--target-rps=<N>` (optional, **backend-flavoured**) — target requests/sec. Anchors capacity-headroom + hot-path ranking on backends / serverless / data pipelines (where input rate is the dominant axis). Defaults to 2× current measured RPS (read from observability) OR 100 if no telemetry wired.
- `--target-p95=<ms>` (optional, **backend / serverless / pipeline**) — target p95 latency per entry-point. Defaults to declared SLOs from `ai/observability.md`, OR 200ms.
- `--target-vitals=<spec>` (optional, **frontend**) — target Core Web Vitals. Format: `fcp:1500,lcp:2500,tti:3000,inp:200,cls:0.1` (any subset). Anchors hot-path ranking on routes, fan-out depth on waterfalls, capacity headroom on bundle size. Defaults pulled from `ai/observability.md` / Lighthouse budget if wired, else `fcp:1500,lcp:2500,tti:3000,inp:200`.
- `--target-cold-start=<ms>` (optional, **serverless / mobile**) — target cold-start time. Defaults: serverless 1000 ms, mobile 1500 ms.
- `--target-startup=<ms>` (optional, **CLI / library / SDK**) — target startup-to-first-byte time. Default: 100 ms.
- `--target-bundle=<bytes>` (optional, **frontend / mobile**) — target compressed bundle size. Format: `300KB`, `2MB`, `bytes`. Default: project-budget from `ai/observability.md` else 250KB (frontend) / 50MB (mobile).
- `--plan-only` — scan + rank + write plan; no fixes.

When NO target flag matches the project's `PROJECT_KIND`, the agent picks the right one from anchors and warns once. When MULTIPLE flags are provided in a polyglot monorepo, each `PROJECT_KIND` subtree uses its applicable flags; flags that don't apply to a subtree are ignored for that subtree.

Examples:
```
# Backend service
/audit --target-rps=50000 --target-p95=120         # 10× scale + tight latency

# Frontend app (storefront)
/audit --target-vitals=fcp:1200,lcp:2000,inp:150 --target-bundle=200KB

# Serverless (Lambda / Edge)
/audit --target-cold-start=400 --target-rps=10000

# Mobile (iOS / Android / RN / Flutter)
/audit --target-cold-start=900 --target-bundle=30MB

# CLI / library / SDK
/audit --target-startup=80                          # fast-CLI target

# Polyglot monorepo (Next.js + NestJS + Python ETL)
/audit --target-rps=30000 --target-vitals=lcp:2000  # each kind takes what applies

# Whole project, default targets
/audit
/audit --plan-only                                  # produce plan, don't fix
/audit "request path only" --target-rps=100000     # request-path hot loop only
/audit --focus=security,db                          # narrow axes
/audit --focus=security                             # security-only scan (any stack)
/audit packages/web --target-vitals=lcp:2500       # one workspace in a monorepo
```

## What happens internally (silent)

**Discipline:** MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code fixes (SOLID + clean-code single source of truth). MUST read [`templates/packs/migration/rules/migration-discipline.md`](../templates/packs/migration/rules/migration-discipline.md) `§ Structure → V2 wins; observable behaviour → V1 wins` if scope overlaps an in-flight migration (audit findings on V1 do NOT block V2 ports; surfaced to V1 retirement plan).

### Phase 0 — Resolve scope + targets
- Semantic resolution of `<scope>` to source paths.
- Resolve `--target-rps` / `--target-p95`: explicit > observability-derived > sensible default.
- Read `_extracted-idioms.md`, `ai/architecture.md`, `ai/observability.md`, `ai/decisions/` (skim), `CLAUDE.md`.
- Detect `PROJECT_KIND` (frontend-* / backend-* / data-* / mobile-*) from anchors — drives which detector packs activate.

### Phase 1 — Multi-axis scan (parallel)

Dispatched in **one fan-out wave** (8 concurrent subagents):

| Sub-wave | Agent / skill | Reads | Emits to |
|---|---|---|---|
| Architecture | `architectural-diagnosis` skill | source + `_extracted-idioms.md` | `ai/audit/_arch.md` |
| SOLID + clean code | `code-reviewer` agent + `refactoring-sweep` skill | source + `core-discipline.md` | `ai/audit/_quality.md` |
| Security | `security-auditor` agent + `auth-reviewer` (if auth surface) + `secret-scan` + `deps-audit` + `threat-model` | source + manifests | `ai/audit/_security.md` |
| DB perf | `database-optimizer` + `query-optimizer` + `schema-reviewer` + `schema-consistency-audit` | migrations + queries + ORM models | `ai/audit/_db.md` |
| Runtime perf | `performance-optimizer` + `caching-architect` + `n-plus-one-scan` | source + `ai/patterns/caching-strategy.md` + `indexing-strategy.md` | `ai/audit/_perf.md` |
| **Scale/resilience** (own detectors) | `system-architect` + `resilience-reviewer` + scale-lens scan | source + `ai/observability.md` + dashboards if wired | `ai/audit/_scale.md` |
| Infra/capacity | `infra-architect` + `k8s-reviewer` (if k8s files) | Dockerfile + manifests + IaC | `ai/audit/_infra.md` |
| Observability | `observability-reviewer` + `telemetry-architect` + `sre-engineer` | source + dashboards + alert config | `ai/audit/_obs.md` |

Each emits findings as `<id>` + `<axis>` + `<file:line>` + `<closure-verb>` + `<estimated-impact>` + `<estimated-cost>`. NOT shown to user.

### Phase 2 — Cross-axis rank
- Single ranker reads all 8 axis files; produces `ai/audit/plan.md` with findings ranked into P0–P4 tiers per the rule above.
- Each finding has: id, axis, summary (1 line), file:line, closure verb, dependency-on (other findings that must land first), tier, impact-at-target-rps, blast-radius, fix-cost.
- Validates: `impact-at-target-rps` for every P0/P2 finding cites a measured baseline OR an explicit estimate (RPS × cost-per-call). No hand-waved "would be slow at scale".
- Writes plan; emits brief summary to user (headline counts per tier + 3 example P0/P1 findings).

### Phase 3 — Plan-only short-circuit
If `--plan-only`: stop here. User reads `ai/audit/plan.md`. Re-run without flag to execute.

### Phase 4 — Execute P0 (scale-blockers, sequential)
- One commit per P0 finding. Each commit:
  1. Re-detect (idiom may have changed).
  2. Apply closure verb (closed vocabulary: `add-circuit-breaker`, `add-timeout`, `bound-buffer`, `add-idempotency-key`, `add-rate-limit`, `partition-tenant-pool`, `extract-from-request-path`, `add-dlq`, `add-replay-path`, `make-stateless`, `add-pool-sizing`).
  3. Add load test OR chaos test asserting the failure mode no longer reproduces (dispatched via `chaos-test` skill).
  4. Verify scoped tests pass + regression assertion passes.
  5. Commit.

### Phase 5 — Execute P1 (security/correctness, sequential)
- One commit per finding. Each commit ships with:
  - Regression test asserting the gap (call the unsafe path, assert it now rejects / sanitizes / authorizes correctly).
  - Closure verb from security-auditor's vocabulary (`add-input-validation`, `parameterize-query`, `escape-output`, `add-authz-check`, `rotate-secret`, `pin-dep-version`, `add-tenant-scope`).
- For OWASP Top 10 issues: assertion file linked from `ai/security/regression-suite.md`.

### Phase 6 — Execute P2 (high-leverage scale fixes, parallel waves)
- Up to `--max-parallel` (default 5) concurrent subagents.
- Each finding: baseline measurement → apply fix → post-fix measurement → verify parity tests + scoped tests → commit.
- Closure verbs: `parallelize`, `batch`, `cache-with-explicit-ttl`, `add-index`, `project-columns`, `push-down-filter`, `add-read-replica-routing`, `move-to-background-job`, `add-pagination`, `precompute`.
- After this phase, **re-runs Phase 1 axis detectors on changed files** — many P3/P4 findings dissolve.

### Phase 7 — Execute P3 (architectural foundations, sequential)
- Same closure verbs as `/optimize` Phase 1: `move-responsibility`, `introduce-abstraction`, `fix-layering`, `centralize-cross-cutting`, `split-god-module`, `decouple-cycle`.
- One commit per foundation. Re-runs typecheck + scoped tests after each.

### Phase 8 — Execute P4 (tactical cleanup, parallel waves)
- Same closure verbs as `/optimize` Phase 2 — refactoring + dead code + dedup + over-abstraction.
- After this phase, re-runs Phase 1 axis detectors one final time. Plan rows that re-detect clean → marked `verified`. Rows that re-detect → flipped `halted` and surfaced.

### Phase 9 — Verify continuously
- Lint + typecheck + scoped tests after EACH commit. Coverage must not drop.
- For perf/scale fixes: baseline measurement + post-fix measurement attached to commit message.
- For security fixes: regression assertion in same commit.

### Phase 10 — Self-resolve common questions
- Closure verbs are mechanical. Agent doesn't ask permission per fix.
- HALTS only on the failure modes below.

## Progress tracking (multi-day workflow)

Single source of truth: **`ai/audit/progress.md`**.

### How it works

- **First run** → builds findings inventory + writes progress file. Executes P0 + P1 then pauses (high-blast tiers serial).
- **Subsequent runs** → reads progress file, picks up at next pending tier OR module. Already-`done` findings skipped.
- **`/audit --status`** → read-only progress; no work.

### Progress file shape

```markdown
# Audit progress

Started: 2026-05-08
Codebase: <project-root>/src/
Targets: 50000 RPS, 200ms p95

## Summary
- P0 scale-blockers:    3  (3 done, 0 pending)
- P1 security/correct:  7  (7 done, 0 pending)
- P2 scale fixes:      28  (12 done, 14 pending, 2 halted)
- P3 architectural:     5  (0 done, 5 pending)
- P4 tactical:        134  (0 done, 134 pending)

## Halted findings
- F-S-019: queue back-pressure on /webhooks/stripe
  Reason: requires Redis Streams primitive — project has no streaming primitive.
  Next: /setup-project --refine to add one, then re-run /audit --resume.

- F-S-024: tenant pool partitioning
  Reason: cross-PR refactor (touches DB + service layer + ops manifest).
  Next: see ai/audit/plan-F-S-024.md for the multi-PR breakdown.
```

### Daily workflow

```
Day 1:  /audit --target-rps=50000   # first run — P0 + P1 land
Day 2:  /audit                       # P2 parallel wave
Day 3:  /audit --status              # check overall progress
        /audit                       # continue
...
```

### Overrides

```
/audit the orders module             # specific area, skips ahead
/audit --status                      # progress report only
/audit --resume                      # pick up halted findings
/audit --reset F-S-019               # re-detect a specific finding
/audit --refresh                     # RE-SCAN codebase, MERGE into existing plan
                                     #   - new findings appended as pending
                                     #   - existing rows preserved
                                     #   - Summary recounted
/audit --re-audit                    # IGNORE cached verdicts; re-detect all axes
                                     #   - rows that re-verify clean stay verified
                                     #   - rows that re-detect → halted, re-fix in same run
/audit --restart                     # wipe progress, start over (commits NOT reverted)
/audit --ignore-ledger               # truly fresh scan (re-runs all 8 axes from scratch)
```

## What you see (output)

Backend example (a multi-tenant SaaS API):

```
Audit complete

Scope:               whole project (backend-laravel, multi-tenant)
Targets:             50000 RPS, 200ms p95

P0 scale-blockers (3 fixed):
  /webhooks/stripe — sync HTTP to Stripe in request path (60s timeout, no circuit breaker)
    → moved to background job + idempotency key + DLQ
  Tenant connection pool — single 50-conn pool shared across all tenants (1 slow tenant stalls all)
    → partitioned to per-tier pool with shared overflow + per-tenant rate limit
  Webhook replay — no DLQ, no replay path (failed events lost)
    → added DLQ + replay endpoint + monitoring

P1 security/correctness (7 fixed):
  IDOR on /api/orders/:id — missing tenant scope on direct lookup
  XSS in order-note rendering — unescaped output
  Hard-coded API key in config/services.php
  4 outdated deps with known CVEs (HIGH severity)

P2 scale fixes (12 fixed, 14 pending):
  N+1 on GET /api/orders index (1 + N customer lookup) — batched, p95 410ms → 95ms
  Missing index on (tenant_id, status, created_at) — added migration, p95 220ms → 38ms
  Sequential awaits in /api/dashboard — parallelized (4× speedup)
  9 more measured wins (see ai/audit/perf-wins.md)

P3 architectural (deferred — see plan):
  Split OrderController (god class, 47 actions) → 5 responsibility-aligned controllers
  Move data fetching from controllers → repository layer

Commits:             22 (3 P0 + 7 P1 + 12 P2)
Diff:                +1247 / -2891 = -1644 lines
Tests:               498/498 passing (12 new regression tests)
Coverage:            76.2% → 78.1%
Wall-clock:          47m 12s

Capacity headroom delta:
  Before: ~12000 RPS at p95=200ms (24% of target)
  After:  ~58000 RPS at p95=140ms (116% of target — passes)

Next:
  /audit                              # continue P2 parallel wave (14 pending)
  /audit --status                     # progress detail
  Read ai/audit/plan.md for full ranked list
```

Frontend example (a heavily-trafficked storefront):

```
Audit complete

Scope:               whole project (frontend-vue3, storefront)
Targets:             100K daily users, FCP 1.5s, TTI 3s

P0 scale-blockers (1 fixed):
  Storefront product page — sync analytics HTTP in critical path (blocks render on slow 3G)
    → moved to beacon + sendBeacon fallback

P1 security/correctness (4 fixed):
  XSS in user-review rendering — unescaped v-html
  Stored token in localStorage (vulnerable to XSS) — moved to httpOnly cookie + CSRF
  CSP missing — added strict CSP header
  3 outdated npm deps with HIGH CVEs

P2 scale fixes (8 fixed):
  Bundle: 2.4MB → 980KB (route-level code split + lodash treeshake + moment → dayjs)
  Image lazy-loading + responsive srcset
  Fetch parallelized on dashboard load (4 → 1 wave)
  CDN cache headers fixed on static assets

Commits:             13
Diff:                +412 / -1623 = -1211 lines
Tests:               167/167 passing (5 new regression tests)
Bundle delta:        -59% (2.4MB → 980KB)
Lighthouse:          P 64 → 91, FCP 2.8s → 1.1s, TTI 5.4s → 2.6s
Wall-clock:          22m 41s
```

Mobile example (a React Native shopping app):

```
Audit complete

Scope:               whole project (mobile-react-native, iOS + Android)
Targets:             cold-start 1500ms, bundle 30MB, jank rate <1%

P0 scale-blockers (2 fixed):
  Cart screen — sync `AsyncStorage` read on mount (UI-thread blocking 280ms median)
    → moved to background + skeleton state
  Checkout fan-out — 7 sequential `fetch` calls on appear (waterfall 2.4s)
    → batched into 2 parallel waves (560ms)

P1 security/correctness (3 fixed):
  Stored auth token in AsyncStorage unencrypted — moved to Keychain / EncryptedSharedPreferences
  Deep-link unvalidated host — added allowlist + scheme check
  2 npm deps with known iOS-specific CVEs

P2 scale fixes (9 fixed):
  Hermes bytecode caching enabled (-340ms cold start)
  Image cache strategy: heap → disk-LRU (memory-pressure crashes -89%)
  FlatList virtualization on Orders tab (-12MB peak)
  Reanimated v2 → v3 (jank rate 4.1% → 0.8%)
  ProGuard rules tightened (APK 38MB → 24MB)

Commits:             14
Tests:               203/203 passing (jank assertions added)
Cold start:          2.1s → 0.95s (iOS), 2.6s → 1.3s (Android)
Bundle:              JS 18MB → 11MB; APK 38MB → 24MB; IPA 45MB → 28MB
```

Serverless / edge example (an AWS Lambda image-processing pipeline):

```
Audit complete

Scope:               services/image-pipeline (serverless-lambda, Node 20)
Targets:             cold-start 400ms, p95 800ms, RPS 5000

P0 scale-blockers (2 fixed):
  Cold path — sync `require('sharp')` at top of handler (450ms init)
    → moved to dynamic-import inside handler + Lambda layer for native binary
  Retry without idempotency token — duplicate S3 writes on at-least-once delivery
    → added SQS message-id-based idempotency + DDB conditional-put

P1 security/correctness (4 fixed):
  Pre-signed URL signature lifetime 24h → 5min
  Function role had wildcard s3:* — narrowed to bucket prefix
  2 deps with HIGH CVE
  CloudWatch logs leaked customer email — redaction layer added

P2 scale fixes (6 fixed):
  Bundle: 18MB → 4.2MB (esbuild + external aws-sdk)
  Cold start: 1100ms → 320ms
  Concurrency: 50 → 200 reserved (capacity headroom 4×)
  X-Ray tracing wired (was missing → required for SLO measurement)

Commits:             12
Tests:               89/89 passing (5 new chaos tests for retry semantics)
Cold start p95:      1100ms → 320ms (within target)
p95 latency:         1240ms → 410ms
Cost:                $187/day → $73/day (-61%)
```

CLI / SDK example (a developer-facing TypeScript SDK):

```
Audit complete

Scope:               whole project (library-typescript, public SDK)
Targets:             startup 80ms, public-API surface stable

P0 scale-blockers (1 fixed):
  Top-level `await crypto.subtle.generateKey()` at import — blocks every
  consumer's startup by 220ms even when they never call the affected method
    → moved to lazy-init inside `getOrCreateKey()`

P1 security/correctness (3 fixed):
  `eval()` used for plugin loading — replaced with `Function` constructor + AST validate
  Default `fetch` lacked timeout — added 30s default + `AbortSignal` plumbing
  1 dep with HIGH CVE

P2 surface fixes (5 fixed):
  Tree-shake regression: `import * as` re-exports → named exports (consumers' bundle -34%)
  ESM/CJS dual-export wired (was ESM-only — broke half the consumer base)
  Public-API contract: 4 internal symbols were leaking via type re-export — narrowed

Commits:             9
Tests:               142/142 passing (8 new contract tests)
Startup:             220ms → 35ms
Bundle (consumer):   -34% on tree-shaking sites
Public API:          61 → 53 surface symbols (8 internals hidden)
```

Polyglot monorepo example (Next.js frontend + NestJS API + Python data pipeline):

```
Audit complete

Scope:               whole monorepo
PROJECT_KINDs:       apps/web (frontend-next), apps/api (backend-nest), pipelines/etl (data-airflow)

apps/web (frontend-next):
  P0:  storefront LCP image not preloaded → +1.4s LCP on slow 3G
  P1:  CSP missing
  P2:  bundle 1.8MB → 740KB; lighthouse 71 → 92

apps/api (backend-nest):
  P0:  N+1 on /api/orders index (1 + N customer lookup) → batched
  P0:  no idempotency on POST /orders → key added (frontend updated to send it — cross-PROJECT_KIND fix bundled)
  P1:  IDOR on /api/orders/:id (missing tenant scope)
  P2:  pool sizing, sequential awaits, missing index

pipelines/etl (data-airflow):
  P0:  unbounded source backlog on Kafka consumer (no max-poll, no checkpoint)
  P1:  PII in log lines (3 DAGs)
  P2:  task-level write batching (per-row insert → batch 1000)

Cross-cutting:
  API idempotency keys propagated to frontend retry handler in same plan row.
  Observability — added trace-id propagation across all 3 PROJECT_KINDs.

Commits:             37 (8 web + 19 api + 7 pipeline + 3 cross-cutting)
Tests:               1247/1247 passing
Wall-clock:          1h 14m
```

## What you DON'T see

- "Phase 1 of 10"
- "Tier promotion needed"
- "Halt: gap-count parity"
- "Ledger updated to status: verified"
- "Per-axis dispatch wave 3 of 8"

All internal. Just results.

## Optional flags

- `--target-rps=<N>` — target throughput (anchors P0 + P2 ranking).
- `--target-p95=<ms>` — target latency.
- `--plan-only` — scan + rank + write plan; no fixes.
- `--dry-run` — show what would be fixed, no edits.
- `--strict` — forwarded to **`validate-audit-artifacts.sh`** (planned): every P0/P1/P2 finding must cite `<file:line>` + a measured or explicitly-estimated impact; no hand-waves.
- `--quiet` — forwarded to validator (`-q`) when invoking from hooks / CI.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent dispatch in P2/P4 (default 5).
- `--focus=<list>` — narrow to specific axes (e.g., `--focus=security,db,scale`). Default: all 8.
- `--exclude=<scope>` — exclude areas (e.g., `--exclude=tests,migrations,_examples`).
- `--surface-blockers` — show all halted findings, not just the summary.
- `--skip-p4` — skip P4 tactical cleanup (focus on P0–P3 only).

## Pre-requisites

- `_extracted-idioms.md` OR `codebase-profile.md` populated. The agent reads these to learn the project's language / framework / primitives — there is NO hard-coded grep for `app.get(` / `useState` / `def view(`. New language or new framework = no detector change required; the agent picks up the project's idioms via these anchors.
- `PROJECT_KIND` resolvable from anchors (set during `/setup-project`). For polyglot monorepos, every subtree's PROJECT_KIND must be set.
- Mechanical CI green.
- Working tree clean (or `--allow-dirty`).
- For meaningful capacity-headroom delta: `ai/observability.md` should declare current RPS / web-vitals / cold-start / SLOs (else defaults to estimates and confidence is reduced).
- **No language-specific tooling required at audit time.** Specialist dispatches use the project's own toolchain: `database-optimizer` runs whatever DB the project uses; `performance-optimizer` reads framework idioms from anchors; security agents (`security-auditor`, `auth-reviewer`) operate on universal OWASP / CWE patterns. If a stack-specific deeper pass is needed (e.g., language-specific SAST, JVM heap profiler, Rust lifetime analysis), the audit emits a paste-ready follow-up command — it does not require those tools to be installed.

## Final report contract

Every run that produces `ai/audit/final-report.md` MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every deferred / out-of-scope / "consider doing this" finding gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. Routes deferrals to receivers:

- P3 architectural deferrals → `/optimize <scope> --focus=<arch verb>`.
- Security regulatory follow-up → `/security-audit` (deeper external SAST pass).
- DB schema changes needing migration rehearsal → `/db-audit` + `migration-rehearsal`.
- Infra changes → `/k8s-generate` or `/provision-tier`.
- Observability gaps → `/add-metrics`, `/add-tracing`, `/alert-design`.
- Cross-PR refactors → `/refactor` with explicit scope.

## Hard rules (internal)

Applied silently per the discipline:

- **Scale-lens detector pass is mandatory.** *(Agent-side.)* The 13 scale-lens detectors (hot-path, fan-out depth, sync HTTP in request path, single-instance bottleneck, lock contention, queue back-pressure, write amplification, tenant blast radius, capacity headroom, SLO delta, idempotency gaps, statelessness violations, cold-start cost) run on every `/audit` invocation. They are the differentiation vs `/optimize` — skipping them collapses `/audit` into `/optimize` + axis fan-out, which is not the contract.
- **P0 findings must cite the scale failure mode.** *(Mechanical — `validate-audit-artifacts.sh § check_p0_failure_mode_cited`, planned.)* "Would deadlock at 50K RPS because lock held across HTTP call" is acceptable; "would be slow at scale" is rejected.
- **P0 + P1 findings ship with regression assertions in same commit.** *(Agent-side verification.)* Without an assertion, the gap reappears on the next refactor.
- **P2 perf/scale findings ship with baseline + post-fix measurement.** *(Agent-side.)* Same rule as `/optimize` — speculative wins under 5% are discarded.
- **Cross-axis ranker enforced.** *(Mechanical.)* Plan ordered by `impact-at-target-rps × blast-radius × fix-cost`, NOT by axis. A "fix all security first then all DB then all perf" order is rejected — that's just running 5 separate audits sequentially.
- **No hand-waves in plan.** *(Mechanical — `validate-audit-artifacts.sh § check_no_handwaves_audit_plan`, planned.)* Greps `etc.`, `...`, `&...`, `N+ items`, `would be slow`, `at scale this is bad`. Every finding has a citation + measured-or-estimated impact.
- **Foundation-first within tier.** *(Agent-side.)* P3 architectural fixes land before P4 tactical. P3 may dissolve dozens of P4 findings.
- **Behaviour preserved** for architectural / refactoring / dead-code / dedup. Perf/scale/security fixes ship with assertions OR measurements.
- **One commit per finding** (P0, P1, P2, P3, P4). Multi-finding commits hide regressions.
- **Closure verbs from a closed vocabulary.** No new abstractions invented; `introduce-abstraction` only when ≥3 sites duplicate the same shape.
- **Re-detect after each tier.** Gap-count parity (`gaps_in == gaps_closed`) before the tier advances.
- **Halts on**: idiom missing (e.g., scale fix needs Redis but project has no cache primitive); cross-PR decoupling required; behaviour change risk; infra change beyond mechanical (surfaces ops ticket).

User sees the result, not the policing.

## Failure modes

- **No findings detected** → outputs "Codebase already passes the audit at the requested target. No fixes needed."
- **Pre-flight red** (CI / typecheck) → halts; surfaces what to fix first.
- **All P0 findings blocked** → halts after writing plan; surfaces blockers + next-steps.
- **Behaviour change risk** (e.g., `parallelize` would race against shared state) → that finding skips with note; rest continue.
- **Target unrealistic** (e.g., `--target-rps=1000000` on a single-instance Postgres) → halts at Phase 2 with capacity-physics explanation; user reduces target OR accepts that infra changes are required (surfaces a different command — `/provision-tier`).
- **Observability not wired** → emits soft warning at Phase 0; defaults targets; reduces measurement confidence on P2 wins (still computes, but flagged "estimated").

## Related (advanced — granular surfaces)

`/audit` dispatches these internally with sensible defaults. Use them directly for specialist or class-specific runs:

- `/optimize` — code-quality + tactical perf only (no security, no scale lens).
- `/security-audit` — security-only deep audit (OWASP + auth + tenant + secrets).
- `/db-audit` — database-only (schema, indexes, query plans).
- `/perf-audit` — runtime perf only.
- `/profile-perf` — runtime profile capture.
- `/design-system <feature>` — system-design doc (cross-service / data-ownership / consistency).
- `/audit-distributed-tx` — distributed transaction review (saga, 2PC, outbox).
- `/cost-audit` — infra cost + capacity tier.
- `/threat-model` — security threat model.
- `architectural-diagnosis` skill — layer-violation / god-module detection.
- `n-plus-one-scan` skill — N+1 hunt.
- `chaos-test` skill — failure-mode assertion authoring.
- `system-architect` agent — boundary / consistency / failure-mode review.
- `resilience-reviewer` agent — failure-mode matrix.

`/audit` is the simple-surface alternative that fans out to all of these in one pass and merges the findings into one ranked plan.
