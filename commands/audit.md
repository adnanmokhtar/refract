---
description: Rank what is WRONG with code that already exists, across eight engineering axes at once. Triggers — 'are we ready for 10x traffic', 'what blocks us at 100K RPS', 'pre-launch hardening sweep', 'audit the orders module for SOLID + perf + security', 'senior-engineer assessment for stakeholders' (--assess). Do NOT trigger on single-axis asks; security-only is /security-audit, perf-only /perf-audit, DB-only /db-audit, AI/LLM-only /ai-audit, design or a11y /design-review. Do NOT silently claim a bare 'pre-launch sweep' with no hardening, security or scale noun — that reading is shared with /polish's finish sweep; ask which axis is meant. Not code quality with no security or scale lens (/optimize), not capability that was never built (/roadmap).
compatibility: Requires PROJECT_KIND resolvable from anchors (every subtree in a polyglot monorepo) and _extracted-idioms.md or codebase-profile.md populated. No language-specific tooling needed at audit time — deeper stack-specific passes such as SAST or a heap profiler are emitted as paste-ready follow-up commands, not run here. Capacity-headroom numbers stay estimates unless ai/observability.md declares current RPS, vitals, or SLOs.
kind: command
pack: orchestration
---

# /audit [<scope>] [--target-rps=<N>] [--target-p95=<ms>] [--plan-only | --assess]

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
   - Sequential awaits where parallelism is safe, sync external HTTP in hot paths, missing cache at known-cacheable sites, in-app filtering pushable to DB, payload bloat, bundle bloat.
   - Render / rebuild waste (stack-routed): oversized state scope, side-effects in the build/render body, missing const / memo / stable subtree, per-item allocations in list hot paths, unvirtualized lists, animation invalidating the whole tree, store over-invalidation. Fingerprints per `PROJECT_KIND`: `mobile-*` → `mobile/rules/render-discipline.md` (Flutter / RN / Compose / SwiftUI tables); `frontend-*` → frontend pack equivalents. Every render-waste fix ships with a before/after rebuild-count or frame-time measurement.

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

   **Unhandled-I/O pass (happy-path-only code — runs alongside the 13 scale-lens detectors, same dispatch wave):** every I/O call site (network / DB / queue / file / external process) with NO error path at all — no catch, no error-return check, no timeout where the medium needs one, no failure state surfaced to the caller or UI. The code works on the happy path and crashes/hangs on the first failure — the canonical AI-generated-code defect. Same detector contract as the align pack's `unhandled-io` class (`align/rules/align-discipline.md`): enumerate I/O sites from `_extracted-idioms.md` primitives, trace the failure path, cross-check the caller chain before flagging. Findings rank **P1 (correctness)** — read-path sites on cold paths may demote to P4 with justification; write-path sites (DB mutation / queue publish / payment) never demote. Closure: route through the project's wrapped I/O primitive; regression test asserts the failure mode now surfaces (same-commit assertion rule).

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

5. **Behaviour-preserving** for architectural / refactoring / dead code / dedup. **Behaviour-changing where safe** for perf + scale fixes (parallelize, batch, cache, circuit-breaker insertion) — adds assertions in same commit. **Security fixes always ship with regression test in same commit.** Before a behaviour-preserving fix touches an UNCOVERED branch, the `test-shield` skill (code-quality pack) pins current behaviour with a characterization test (`/add-test`) first, or marks the finding `blocked` — "tests stay green" only proves preservation when a test exercises the touched branch.

6. **Halts ONLY on genuine blockers** — fix would change observable behaviour where it must be preserved (re-classify, surface to user); idiom missing (e.g., user wants Redis but project has no cache primitive); cross-PR decoupling required (surfaces a small plan); infra change beyond mechanical (e.g., add HPA — surfaces ops ticket).

7. **Boot-check (final)** — after the last fix commit, the `smoke-verify` skill (code-quality pack) boots the app per `PROJECT_KIND` (dev server / server + health probe / CLI / library import) and HALTS if it doesn't start — a green suite doesn't prove the app still wires up (DI / route registration / import cycles). Skippable with `--no-boot-check` for pure libraries. (Not run in `--plan-only` / `--assess`.)

Output: P0 scale-blockers FIRST, then ranked findings, commits, diff stats, test status, perf wins (measured), capacity-headroom delta.

## When to use

- "Audit the whole project for engineering + scale issues." → `/audit`
- "Are we ready for 10× traffic?" → `/audit --target-rps=50000 --target-p95=200`
- "Audit the orders module against SOLID + perf + security." → `/audit the orders module`
- "What would block us from going to 100K RPS?" → `/audit --target-rps=100000 --plan-only`
- "Pre-launch hardening sweep." → `/audit`
- "Give me a senior-engineer assessment of the frontend — what's good, what to improve, what to unify, what to extract, what to simplify, what to redesign, what to remove, what to optimize." → `/audit --assess`
- "Senior engineer write-up of the NestJS / Django backend quality and scalability." → `/audit --assess apps/api`
- "Architecture review report for stakeholders — no fixes yet, just the lay of the land." → `/audit --assess`

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
- `--plan-only` — scan + rank + write `ai/audit/plan.md` (ranked P0–P4 fix-plan with `<file:line>` citations + closure verbs). No fixes. The handoff artifact for "agent / human executor will pick this up later". Mutually exclusive with `--assess`.
- `--assess` — scan + write `ai/audit/assessment.md` (senior-engineer narrative report, 8 sections: what's already good / what needs improvement / what should be unified / what should be extracted-or-shared / what should be simplified / what should be redesigned / what should be removed / what should be optimized). No ranked plan, no closure verbs, no fixes. The handoff artifact for "show me a written assessment of the codebase a senior engineer or tech lead would read". **Stack-conditional rendering** — frontend-* assessments inline component-structure / composable-design / state-management / routing-organisation / styling-architecture / design-system / a11y / typing narrative; backend-* inline module-shape / DTO / validation / guards-interceptors-filters / repository / transaction / API-design / testing-quality narrative; mobile-* / data-* / serverless inherit the same 8 sections with stack-appropriate axis emphasis. Mutually exclusive with `--plan-only` and with execution. Distinct from `--plan-only`: the plan is a closure-verb checklist for an executor; the assessment is prose for a reader.

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
/audit --plan-only                                  # produce ranked fix-plan, don't fix
/audit --assess                                     # senior-engineer narrative assessment, no plan, no fix
/audit --assess apps/web                            # narrative assessment of one workspace
/audit --assess --focus=arch,quality,scale         # narrative scoped to specific axes
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

**Resolve the review matrix.** No new detection — three file reads:

```
SURFACES  ←  `.claude/_extracted-codebase.md` § 11 `technical_signals`   (∩ _review-model.md §2.1)
           +  structural surfaces `_database` `_deployment` `_routes` `_screens`,
              gated on the project_kind set from `detect-project-kind.sh`
AXES      ←  _review-model.md §4  +  the conditional gates in §5
DISPATCH  ←  _review-matrix.md §2 — the concern checklist for each resolved surface
```

**§ 11 has two spellings in the wild, and BOTH must be accepted.**
[`phase-2-profile.md`](../templates/phases/phase-2-profile.md) specifies `technical_signals: [...]`
on its own line; live profiles also emit a markdown-decorated variant
(``**`technical_signals` (canonical registry keys):**`` followed by the array on the next line).
Measured on a real NestJS monorepo: the specified grep returned **0 matches** against a profile that
carried the data, so a parser accepting only the spec'd form drops to degraded mode on a repo that
needs no degrading. Accept both and **report which was found** — a silent accept hides the drift.
The same run had **no `technical_signal_confidence:` block at all**; the ratios were prose, so no
cell got a denominator, which is the defect `phase-2-profile.md` documents about itself.

**Cross-check the array against its own evidence table.** That run declared 8 canonical keys while
the verdict table directly above it listed 11 signals as confirmed or partial. `ai`, `i18n`,
`payment` and `search` were evidenced and **absent from the array Phase 4.4 actually reads** — their
domains never applied, their cells never dispatched. `media-processing` and `webhook` were in the
array with no evidence row. Report both directions; neither is visible from the array alone.

[`scripts/resolve-review-matrix.sh`](../scripts/resolve-review-matrix.sh) performs this resolution
and prints the Phase 2b ledger for a target repo.

Vocabulary is fixed by [`templates/_review-model.md`](../templates/_review-model.md): surface names
are literal keys from `templates/domains/_registry.md`, and kind gates use the closed set
`browser | server | mobile | cli | any` from `templates/packs/_project-kind.md`. The
`frontend-*` / `backend-*` / `data-*` families above are **prose for detector-pack routing only**
and MUST NOT be used to gate a matrix cell — nothing emits them, so a cell gated on one is never
dispatched and never reported missing.

**§ 11's confidence ratio becomes a denominator, not a label.** `multi-tenant: partial 117/242`
means 125 entity files sit outside tenant scope. Today that number is prose and changes nothing —
[`phase-2-profile.md`](../templates/phases/phase-2-profile.md) says so in its own words: *"The
demotion was cosmetic."* Here it is the denominator of every cell on that surface, so
`Tenancy × _database` stops being "is isolation present" and becomes "isolation covers 117 —
here are the other 125."

**Degraded mode.** If `§ 11` is absent (no `/setup-project` run), surfaces resolve from
`project_kind` + structural only. Say so in the report and mark every signal-surface cell
`unresolved — § 11 missing`. Never silently fall back to the flat 8 buckets.

### Phase 1 — Matrix scan (parallel, surface-major)

**Dispatch is surface-major; cells are the output granularity, not the dispatch granularity.**
12 concerns × ~12 surfaces is ~144 cells and cannot be 144 agents. One agent per **resolved
surface** carries that surface's whole concern checklist, so the agent reading the queue code
checks all 12 concerns while it is in there instead of 12 agents re-reading the same files —
cheaper, and a finding that needs two concerns at once (a job payload carrying a raw token =
Authorization + Security + Data Privacy) is visible to a single reader.

```
wave A — one agent per resolved surface, checklist from _review-matrix.md §2
   agent(public-api)  agent(_database)  agent(background-jobs)  agent(file-upload)
   agent(real-time)   agent(integrations)  agent(_deployment)   … (N ≈ 8–14)

wave B — the axes with no single surface, dispatched globally
   01 Architecture · 22 Modularity · 08 Testing · 10 Maintainability
   30 Developer Experience · 21 Requirements / Business Fit
```

Wave B is the table below — it is unchanged and still correct, because those agents were always
global. **Only the axis agents that were secretly surface-shaped moved into wave A.**

Every finding is tagged with its cell: `(concern | axis) × surface`. A finding that cannot be
placed in a cell is a bug in the matrix, not a finding — report it as such.

Wave B (global axes, unchanged — 8 concurrent subagents):

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
- Single ranker reads all wave-A surface files **and** all wave-B axis files; produces `ai/audit/plan.md` with findings ranked into P0–P4 tiers per the rule above.
- **Every finding carries its cell** `(concern | axis) × surface`. A concern's headline number is the roll-up of its cells — `Security: 14` is computed from `Security × {every resolved surface}`, never filled by a separate agent. A concern is never also a standalone axis bucket; double-counting there is what made the ranker compare a finding against itself.
- **`blast-radius` uses the surface's real population as denominator**, not an estimate — the § 11 confidence ratio from Phase 0. "125 of 242 entity files" outranks "could affect many models".
- Each finding has: id, axis, summary (1 line), file:line, closure verb, dependency-on (other findings that must land first), tier, impact-at-target-rps, blast-radius, fix-cost.
- Validates: `impact-at-target-rps` for every P0/P2 finding cites a measured baseline OR an explicit estimate (RPS × cost-per-call). No hand-waved "would be slow at scale".
- Writes plan; emits brief summary to user (headline counts per tier + 3 example P0/P1 findings).

### Phase 2b — The cell ledger (leads every artifact)

**This is the architecture review.** The ranked findings say what is wrong with what was looked
at; the ledger says *what was looked at* — and, more usefully, what was not.

Written as the **first section** of `ai/audit/plan.md` and of `ai/audit/assessment.md`, before any
finding. Every cell in the matrix resolved at Phase 0 lands in exactly one of three columns:

| Column | Meaning | Row must carry |
|---|---|---|
| **Reviewed** | cell had material, an agent ran it | findings below, or an explicit clean verdict |
| **N/A** | the cell has no meaningful fingerprint in *this* project | **a reason string, always** |
| **Live, unreviewed** | the surface exists and the concern applies, but **no detector exists** | the surface's population, so the gap is sized |

```
## Cell ledger — 11 surfaces × 12 concerns = 132 cells

Reviewed          78   findings ranked below
N/A               31   each with a reason
Live, unreviewed  23   ← nobody is looking at these

### Live, unreviewed
| Cell | Surface population | Why nothing ran |
|---|---|---|
| Authorization × background-jobs | 34 job classes | no detector exists in any pack or domain |
| Data Lifecycle × _database      | 242 entity files | no retention rule ships for this surface |
| Configuration × file-upload     | 12 upload sites | matrix cell empty (both signals silent) |
```

**Hard rules.**
- A cell may **never** be silently absent. Absent = a bug in Phase 0 resolution, and the run says so.
- **No bare `N/A`.** Every N/A row carries its reason. This inherits the discipline already
  documented for the 13 scale detectors above — *"A detector that has no meaningful fingerprint
  for a given `PROJECT_KIND` is marked N/A and skipped — not silently ignored"* — applied one
  level up, to cells instead of detectors.
- **`Live, unreviewed` is never merged into `N/A`.** They are opposite claims: N/A says *this does
  not apply here*; live-unreviewed says *this applies and nobody is looking*. Collapsing the second
  into the first is how a coverage gap disguises itself as a scoping decision, and it is the single
  failure this ledger exists to prevent.
- The three counts must sum to the resolved cell count. Print the arithmetic.

**This ships value before a single new detector is written** — it names the unreviewed cells using
only what exists today. `--plan-only` and `--assess` both emit it.

### Phase 3 — Plan-only short-circuit
If `--plan-only`: stop here. User reads `ai/audit/plan.md`. Re-run without flag to execute.

**Two plan artifacts, two executors — do not conflate them.** `ai/audit/plan.md` is this command's *own* artifact: a ranked P0–P4 closure-verb checklist in the audit format, validated by `validate-audit-artifacts.sh`, and executed by re-running this command without the flag. It is **not** the universal handoff format, and `/execute-plan` rejects it as malformed because it carries none of the eight canonical headers ([`templates/repo-baseline/.claude/commands/execute-plan.md`](../templates/repo-baseline/.claude/commands/execute-plan.md) § Mechanical halt).

So when `--plan` (the universal alias, per [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md)) is passed instead of `--plan-only`, this phase writes **both** artifacts before stopping:

1. `ai/audit/plan.md` — unchanged; exactly what `--plan-only` has always produced.
2. `.claude/plans/audit-<short-slug>-<YYYYMMDD-HHmm>.md` — the eight-header handoff: `## Goal` / `## Context` / `## Inputs` / `## Outputs` / `## Steps` / `## Constraints` / `## Verification` / `## Status`, plus the Plan ID. The tier order P0→P4 becomes `## Steps`; every finding's cited `<file:line>` site becomes `## Outputs`; the tier rules ("P0 lands sequentially", "every ranked impact is measured or explicitly estimated", "no fix outside the ranked set") become `## Constraints`; the project's lint / typecheck / test commands plus each P0/P1 finding's named failure-mode check become `## Verification`; the 8 axis subfiles plus the idioms oracle become `## Inputs`.

Either spelling still stops here — no fix, no commit, no tier advance. What differs is only which executor can pick the run up: a re-run of this command for the ranked plan, `/execute-plan <file>` for the handoff file. Writing only the ranked plan under a universal-flag spelling is the defect this split exists to close — it advertised a handoff loop that could not complete.

### Phase 3a — Assessment short-circuit (`--assess`)

If `--assess`: skip ranking + skip execution. Instead, read all 8 axis subfiles + the project's `_extracted-idioms.md` / `_extracted-codebase.md § Gold standards` / `ai/architecture.md` / `ai/conventions.md` and **author a narrative senior-engineer report** at `ai/audit/assessment.md`. Stop after writing. No `plan.md`, no `progress.md` advance, no commits.

**Report contract — the cell ledger (Phase 2b), then exactly 8 top-level sections in this order.**
The ledger leads: a reader must be able to answer *"what is nobody looking at"* from the top of the
report, without reading a single finding. In `--assess` it is rendered as narrative prose rather
than the table, but the same three columns and the same no-bare-N/A rule apply.


1. **What's already good** — load-bearing strengths the codebase has earned. Concrete: "feature modules are well-isolated with one-import-graph-per-module; cross-cutting concerns (auth / logging / error envelope) are centralised in `<path>`; tests cover the critical paths in `<path>`; design tokens cover ~80% of color + spacing usage; the validation pipeline at `<path>` is reused across N forms". Cite `<file:line>` per claim. **No empty-praise prose** ("the code is well organised") — every line names a specific artefact + cites it. If the codebase has < 3 genuine strengths, say so honestly: "Strengths are thin — see § What needs improvement; foundation work required before optimisation has leverage."

2. **What needs improvement** — substantive engineering quality gaps that aren't structural enough to be "redesign" but aren't trivial cleanup either. Examples: "DTO definitions are inconsistent across modules — `apps/api/users/` uses class-validator decorators, `apps/api/orders/` uses plain interfaces; pick one"; "guards / interceptors / filters are partially wired — `OrdersModule` is missing the global tenant guard"; "composable design — 3 of 17 composables encode 2+ responsibilities and should split". Group by axis where natural; cite `<file:line>`.

3. **What should be unified** — visible inconsistencies across instances of the SAME surface or pattern. Frontend: "11 tables with 4 different filter-bar shapes — canonical wrapper at `<path>` exists; 7 consumers don't use it"; "forms — 3 validation patterns coexist (composable-based at `<path>`, ad-hoc in `<path>`, server-only in `<path>`); pick one"; "page headers — 5 shapes; canonical `<PageHeader>` at `<path>`". Backend: "response envelope drift — 4 modules return `{ data, meta }`; 2 return naked arrays; 1 returns `{ result }`"; "error contract — `HttpException` direct-throws in `<path>`, custom error class in `<path>`, returned status codes diverge". Route candidates to `/unify-surfaces` (frontend) / `/polish` (backend API consistency).

4. **What should be extracted or shared** — repeated logic / markup / styles / queries / DTOs / utilities that should be promoted to the shared layer. Examples: "3 components reimplement debounced-search-input — extract to `composables/`"; "5 services re-implement the same `findActiveByTenant` query — extract to a shared repository base"; "color values `#1d4ed8` / `#2563eb` / `#3b82f6` are scattered across N components — promote to design tokens"; "the order-status badge appears in 7 places with 4 visual variants — single shared component". Cite the sites and propose the destination.

5. **What should be simplified** — over-abstraction, unnecessary wrappers, premature interfaces, excessive layering for the actual size of the codebase. Examples: "5 wrapper composables that just re-export the underlying function — inline + delete"; "`OrderService` → `OrderServiceImpl` indirection serves no DI need — collapse"; "deeply nested provider/factory pattern in `<path>` where a single function would do". Be specific about which simplification + estimated effort.

6. **What should be redesigned** — load-bearing things that are architecturally wrong and need rework, not cleanup. Examples: "tenant isolation is enforced at the controller layer in some modules and at the repository layer in others; pick one boundary"; "state management — 3 stores hold overlapping order data that drifts; consolidate to one store with derived selectors"; "auth middleware composes JWT + tenant + permission in one giant guard; split into 3 composable guards"; "router structure mixes feature-grouped and role-grouped routes — pick one organising principle". These are bigger commits; route to `/optimize <scope>` or surface as ADR-needed decisions.

7. **What should be removed** — dead code, unused styles, unused components / utilities / DTOs / endpoints, deprecated patterns. Examples: "12 components in `<path>` have zero references"; "4 SCSS utilities with no consumers"; "3 unused API endpoints — telemetry shows zero traffic"; "legacy auth middleware at `<path>` replaced by `<newer path>` but not deleted". Cite each. Route to `/optimize --focus=dead-code`.

8. **What should be optimized** — concrete performance / scale / cost wins. Examples: "N+1 on `GET /orders` index (1 + N customer lookup)"; "bundle 2.4MB — moment.js + lodash full imports + 3 oversized images"; "queries on `(tenant_id, status, created_at)` need a composite index"; "sequential awaits in `<path>` parallelize safely". Cite + name target win where reasonable. Route to `/audit` (no flag) to execute, or `/audit --plan-only` for the ranked fix-plan.

**Closing paragraph** — 3-5 sentence senior-engineer verdict: how production-grade the codebase is, how scalable for large teams, how easy to maintain long-term, the 2-3 highest-leverage next steps named with their commands. No empty superlatives; honest grading.

**Section content rules**:
- Every claim cites `<file:line>` — same anti-hand-wave grep that `--strict` enforces on the fix-plan (rejects `etc.` / `several places` / `multiple endpoints` / `appears to`).
- Every section labels findings with axis (e.g., `[scale]`, `[security]`, `[arch]`, `[quality]`, `[styling]`, `[a11y]`) so a reader can filter mentally.
- Stack-conditional sub-headings under each top-level section — the agent picks the project's vocabulary from `_extracted-idioms.md` and uses those terms (e.g., "composables" for Vue, "hooks" for React, "modules" for NestJS, "service+repo" for layered backends).
- Cross-references to closure verbs from `/optimize` / `/polish` / `/align` / `/unify-surfaces` wherever a finding has a natural execution path — but `--assess` itself NEVER drafts closure verbs as the primary surface (those are for the executable fix-plan, not the narrative).
- **`## Actionable next steps` at the end of the report** (per `templates/snippets/actionable-next-steps.md`) — paste-ready follow-up commands per the universal report contract: `/audit` (execute the implicit plan), `/audit --plan-only` (write the ranked plan), `/optimize <scope>` (architectural fixes), `/polish` (consistency drift), `/unify-surfaces` (surface-type unification), `/align` (convention drift), `/security-audit` (deep security pass).

**Failure modes for `--assess`**:
- Phase 1 axis scan returned zero findings → assessment is mostly § What's already good (honest) + a short "no urgent improvements" note in the remaining sections. The 8-section shape is preserved (skipped sections explicitly say "no findings").
- Codebase too small to be meaningfully assessed → still emits the report; closing paragraph names the smallness as the verdict.
- `_extracted-idioms.md` absent → soft warning; agent still produces the report using generic stack vocabulary. Recommends running `/setup-project --refresh` to anchor future assessments.

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

Not validated:       load test at target 50000 RPS (no load-test env) — P2 wins measured at dev concurrency; 14 P2 + P3/P4 tiers still pending
Risks:               tenant-pool partition (P0) changes connection allocation under contention — staging soak recommended before prod
Revert:              git revert <first-sha>..<last-sha>  (one commit per finding — P0 land first; revert the tail range to keep blockers fixed)

Next:
  /audit                              # continue P2 parallel wave (14 pending)
  /audit --status                     # progress detail
  /review-changes                     # independent pass before merge
  /learn-from-task                    # promote audit learnings into the knowledge layer
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
  XSS in user-review rendering — unescaped HTML interpolation (`v-html` / `dangerouslySetInnerHTML`)
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

Not validated:       real-device throttled-3G pass (Lighthouse ran emulated) — verify LCP on a physical mid-tier Android
Risks:               httpOnly-cookie + CSRF move changes the auth flow — smoke login/logout before release
Revert:              git revert <first-sha>..<last-sha>  (one commit per finding)
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

Not validated:       low-end-device jank pass (measured on iPhone 14 + Pixel 7 only) — verify on a 2GB-RAM Android
Risks:               Keychain / EncryptedSharedPreferences migration leaves legacy AsyncStorage tokens until next login — confirm migration path
Revert:              git revert <first-sha>..<last-sha>  (one commit per finding)
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

Not validated:       sustained 5000-RPS load with cold-start churn (measured single-invoke + warm p95) — run a load profile before the traffic ramp
Risks:               idempotency via DDB conditional-put adds a write per invoke — confirm the table's WCU headroom at target RPS
Revert:              git revert <first-sha>..<last-sha>  (one commit per finding)
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

Not validated:       downstream-consumer build matrix (verified ESM + CJS import locally, not against real consumer repos) — verify before publishing
Risks:               narrowing 8 internal symbols is a potential breaking change for consumers reaching past the public API — note in the changelog
Revert:              git revert <first-sha>..<last-sha>  (one commit per finding)
```

`--assess` example (Vue 3 frontend, storefront — `/audit --assess`):

```
Assessment complete

Scope:               whole project (frontend-vue3, storefront)
Report:              ai/audit/assessment.md (8 sections, ~2400 words)

Headline verdict:
  Foundation is solid; surface inconsistency + design-token drift are the two
  highest-leverage next steps. Production-grade once those are closed.

Section highlights:
  § What's already good       — feature-module isolation, validation pipeline reuse,
                                ~80% token coverage for color
  § What needs improvement    — composable design (3 over-scoped), state mgmt drift
                                across 2 stores
  § What should be unified    — 11 tables / 4 filter shapes; 5 page-header shapes;
                                3 validation patterns
  § What should be extracted  — debounced-search-input (3 sites); order-status badge
                                (7 sites, 4 variants); shared error-list renderer
  § What should be simplified — 5 pass-through composables; 2 unnecessary wrapper
                                layers in feature/orders
  § What should be redesigned — router mixes feature- and role-grouped routes;
                                pick one principle
  § What should be removed    — 12 unreferenced components; 4 unused SCSS utilities
  § What should be optimized  — bundle 2.4MB (moment + lodash full); LCP image not
                                preloaded; N+1 on dashboard

Next steps (paste-ready):
  /unify-surfaces --surfaces=tables,headers,validation   # unify the 3 surface drifts
  /optimize the composables layer                        # simplify over-scoped
  /audit --plan-only                                     # generate ranked fix-plan
  /audit                                                 # execute fixes
```

`--assess` example (NestJS / Django-class backend — `/audit --assess apps/api`):

```
Assessment complete

Scope:               apps/api (backend-nest, multi-tenant)
Report:              ai/audit/assessment.md (8 sections, ~2800 words)

Headline verdict:
  Module boundaries are clean; DTO + error-contract drift are the two surface gaps;
  one tenant-isolation P1 finding requires attention before scale-out is safe.

Section highlights:
  § What's already good       — module isolation, repository pattern consistent,
                                test coverage on critical endpoints
  § What needs improvement    — DTO authoring inconsistent across 5 modules;
                                guards/interceptors partially wired (OrdersModule)
  § What should be unified    — response envelope drift (4 shapes); error contract
                                drift; pagination contract across 6 endpoints
  § What should be extracted  — findActiveByTenant query (5 sites); audit-log
                                emission (8 sites)
  § What should be simplified — 3 service interface indirections with single impl;
                                deeply-layered provider factory in UsersModule
  § What should be redesigned — tenant isolation enforced at 2 layers
                                inconsistently; pick one boundary
  § What should be removed    — 3 unused endpoints; deprecated auth middleware;
                                7 unused DTOs
  § What should be optimized  — N+1 on /orders index; missing index
                                (tenant_id,status,created_at); sequential awaits
                                in /dashboard

Next steps (paste-ready):
  /security-audit apps/api                              # close tenant-isolation P1
  /polish apps/api --focus=envelope,error-contract     # API consistency drift
  /optimize the tenant-isolation boundary              # architectural redesign
  /audit --plan-only                                    # full ranked fix-plan
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

Not validated:       end-to-end trace propagation across all 3 PROJECT_KINDs under load (wired, asserted in unit tests, not load-exercised) — verify in staging
Risks:               idempotency keys now flow frontend → API → pipeline; a mismatch silently drops retries — smoke the full retry path before prod
Revert:              git revert <first-sha>..<last-sha>  (one commit per finding — cross-cutting commits land last; revert them first to keep per-kind fixes)
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
- `--plan-only` — scan + rank + write `ai/audit/plan.md` (ranked fix-plan); no fixes. Its executor is a re-run of this command. The universal `--plan` spelling is accepted as an alias and additionally writes the eight-header handoff file under `.claude/plans/` so `/execute-plan` can consume it — the ranked pack plan alone is not a valid handoff artifact. See § Phase 3 — Plan-only short-circuit and [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md).
- `--assess` — scan + write `ai/audit/assessment.md` (8-section senior-engineer narrative); no plan, no fixes. For reader handoff. Mutually exclusive with `--plan-only`.
- `--dry-run` — show what would be fixed, no edits.
- `--strict` — forwarded to **`validate-audit-artifacts.sh`**: every P0/P1/P2 finding must cite `<file:line>` + a measured or explicitly-estimated impact; no hand-waves.
- `--quiet` — forwarded to validator (`-q`) when invoking from hooks / CI.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent dispatch in P2/P4 (default 5).
- `--focus=<list>` — narrow to specific axes (e.g., `--focus=security,db,scale`). Default: all 8.
  **The 8 legacy keys keep working and are now documented aliases for cell sets** — nothing that
  worked before changes meaning:

  | `--focus=` | Resolves to |
  |---|---|
  | `security` | `C1 Security × {every resolved surface}` |
  | `perf` | `C2 Performance × {every resolved surface}` |
  | `obs` | `C3 Observability × {every resolved surface}` |
  | `db` | `{every concern} × _database` |
  | `infra` | `{every concern} × _deployment` |
  | `arch` | axes `01 Architecture`, `22 Modularity / Boundaries` (wave B) |
  | `quality` | axes `10 Maintainability`, `03 Correctness` (wave B) |
  | `scale` | axes `04 Scalability`, `17 Resilience`, `19 Capacity Planning` + the 13 scale-lens detectors |

- `--surface=<list>` — restrict to named surfaces (`--surface=public-api,background-jobs`). Names
  must be literal `_registry.md` keys or a structural surface; an unknown name HALTS rather than
  resolving to nothing.
- `--concern=<list>` — restrict to named concerns (`--concern=C8,C9` or
  `--concern=authorization,idempotency`). Combines with `--surface` to address a cell directly.
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
- **P0 findings must cite the scale failure mode.** *(Mechanical — `validate-audit-artifacts.sh § check_p0_failure_mode_cited`.)* "Would deadlock at 50K RPS because lock held across HTTP call" is acceptable; "would be slow at scale" is rejected.
- **P0 + P1 findings ship with regression assertions in same commit.** *(Agent-side verification.)* Without an assertion, the gap reappears on the next refactor.
- **P2 perf/scale findings ship with baseline + post-fix measurement.** *(Agent-side.)* Same rule as `/optimize` — speculative wins under 5% are discarded.
- **Cross-axis ranker enforced.** *(Mechanical.)* Plan ordered by `impact-at-target-rps × blast-radius × fix-cost`, NOT by axis. A "fix all security first then all DB then all perf" order is rejected — that's just running 5 separate audits sequentially.
- **No hand-waves in plan.** *(Mechanical — `validate-audit-artifacts.sh § check_no_handwaves_audit_plan`.)* Greps `etc.`, `...`, `&...`, `N+ items`, `would be slow`, `at scale this is bad`. Every finding has a citation + measured-or-estimated impact.
- **Foundation-first within tier.** *(Agent-side.)* P3 architectural fixes land before P4 tactical. P3 may dissolve dozens of P4 findings.
- **Behaviour preserved** for architectural / refactoring / dead-code / dedup. Perf/scale/security fixes ship with assertions OR measurements.
- **One commit per finding** (P0, P1, P2, P3, P4). Multi-finding commits hide regressions.
- **Closure verbs from a closed vocabulary.** No new abstractions invented; `introduce-abstraction` only when ≥3 sites duplicate the same shape.
- **Re-detect after each tier.** Gap-count parity (`gaps_in == gaps_closed`) before the tier advances.
- **Halts on**: idiom missing (e.g., scale fix needs Redis but project has no cache primitive); cross-PR decoupling required; behaviour change risk; infra change beyond mechanical (surfaces ops ticket).
- **Honesty clause in the summary block is mandatory.** The three lines `Not validated:` / `Risks:` / `Revert:` close every run summary — name what did NOT run (or `none — <what fully ran>`), residual risks (or `none identified`), and the exact revert command for this run's commit range. `Tests: N/N passing` alone hides the negative space — the same Trusted Summary failure mode. `/audit` executes P0–P4 commits, so the clause is non-negotiable: load tests, prod-sized data, and unavailable environments that the scale/perf wins could not exercise MUST be named.

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
- `/ai-audit` — LLM/AI surface only (eval coverage, prompt, retrieval, ANN index, agent budgets, gateway cost).
- `/threat-model` — security threat model.
- `architectural-diagnosis` skill — layer-violation / god-module detection.
- `n-plus-one-scan` skill — N+1 hunt.
- `chaos-test` skill — failure-mode assertion authoring.
- `system-architect` agent — boundary / consistency / failure-mode review.
- `resilience-reviewer` agent — failure-mode matrix.

`/audit` is the simple-surface alternative that fans out to all of these in one pass and merges the findings into one ranked plan.
