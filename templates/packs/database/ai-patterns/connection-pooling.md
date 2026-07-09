---
name: connection-pooling
description: "Pattern: Connection Pooling — every app talks to the DB through a bounded pool sized to the server's real connection ceiling, in the right pooler mode, never a raw connection per request."
kind: ai-pattern
pack: database
---

# Pattern: Connection Pooling

> **Hard rule:** Every process talks to the database through a **bounded** connection pool whose size is derived from the DB's real connection ceiling — never a fresh connection per request and never a pool sized by guesswork. `pool_size_per_instance × instance_count` MUST stay below the server's `max_connections` (minus superuser + replication reserve). An unbounded connection strategy, a per-request `connect()`, or a transaction-mode pooler used with prepared statements / session state is forbidden. Cite the engine + version, the server `max_connections`, the pool config at `<path:line>`, and the deployed instance count — or halt.

**Ownership boundary:** THIS pattern owns **pool sizing and pooler mode** — the arithmetic against `max_connections`, transaction-vs-session-vs-statement mode, idle/lifetime/validation settings, and the serverless-proxy decision. The `database-optimizer` agent tunes the *specific* numbers case-by-case against a live workload (this pattern sets the invariants it must respect). The backend pack's `transaction-boundary` owns **not holding a connection across external I/O** — the connection-leak-across-a-network-call hazard is *detected* here but *fixed* by narrowing the transaction scope there. Sizing/mode = here; per-workload tuning = `database-optimizer`; don't-hold-across-IO = `transaction-boundary`.

**When to apply**
- Any service that opens DB connections under request or job concurrency.
- A `max_connections`-exhaustion incident: "too many clients"/"remaining connection slots" errors, or requests timing out waiting for a connection.
- Serverless / autoscaling deployments where instance count multiplies the connection footprint.
- Adding a second app/worker fleet against a shared DB — the ceiling is now shared.

**When NOT to apply**
- A single-process CLI / one-off migration script with one connection — a pool is noise.
- An embedded / file DB (SQLite) with no client-server connection model.
- The bottleneck is query time on a well-sized pool — that's `indexing-strategy` / `query-optimizer`, not pool sizing.

**Halt conditions / mandatory cites**
- The server `max_connections` MUST be extracted (config, cloud parameter group, `SHOW max_connections`). Without it, sizing is guesswork — halt.
- Every finding MUST cite the pool config at `<path:line>` AND the deployed instance/replica count — a per-instance pool is only safe relative to the fleet total.
- A claim of "the pool is fine" MUST cite `per_instance_max × instances < server_max − reserve`. Missing that arithmetic is the bug.
- A transaction-mode pooler MUST be cited alongside a check that the app uses no prepared statements / session-level features it will break. Missing that check is a latent outage.
- Hand-wave grep on `etc.`, `...`, `appears bounded`, `should be enough` is forbidden when claiming the connection footprint is safe.

Database connections are a **hard, finite, server-side resource** — each one costs memory and a backend process/thread. The app's job is to multiplex many requests over a small, bounded pool, not to mint a connection per unit of work. Size the pool to the ceiling, pick the pooler mode the app can actually tolerate, and never let a connection sit idle inside a transaction across a network call.

## Sizing the pool

Bigger is not better — past the DB's parallelism, more connections mean more context-switching and *lower* throughput. Two constraints:

- **Per-instance size** — a small pool saturates the DB's real concurrency. A common heuristic (PostgreSQL wiki): `connections ≈ (core_count × 2) + effective_spindle_count`. On SSD/cloud storage `effective_spindle_count` is small; the practical answer for many services is a pool of ~5–20, not 100. Measure the knee, don't inflate.
- **Fleet ceiling** — the invariant that actually causes outages: `per_instance_pool_max × instance_count + other_clients ≤ server_max_connections − superuser_reserve − replication_slots`. Twenty app pods each with a 30-connection pool = 600 connections; a default Postgres `max_connections` of 100 is exhausted six times over. Autoscaling multiplies this silently.

When the fleet ceiling and the per-instance need conflict, the answer is a **server-side pooler** (below), not a raised `max_connections` — Postgres backends are expensive processes, and thousands of them thrash.

## Pooler modes (pgbouncer / ProxySQL / RDS Proxy)

A server-side pooler multiplexes thousands of client connections onto a few real DB connections. The **mode** decides what the app may safely do:

- **Session mode** — a client holds a real connection for the whole client-session. Safe for everything (prepared statements, `SET`, temp tables, `LISTEN`), but multiplexing ratio ≈ 1:1 — least connection savings.
- **Transaction mode** — a real connection is assigned only for the duration of each transaction, then returned. **Highest** multiplexing (thousands of clients → dozens of connections). The default for serverless/high-fan-out. **Cost:** anything that spans transactions breaks — server-side **prepared statements**, session `SET` vars, `LISTEN/NOTIFY`, session-level advisory locks, temp tables. The app MUST disable prepared statements (or use protocol-level handling) and avoid session state.
- **Statement mode** — connection returned after every statement; forbids multi-statement transactions entirely. Rare; only for pure autocommit workloads.

The **transaction-mode / prepared-statement incompatibility is the classic silent break**: an ORM defaulting to server-side prepared statements (e.g. some Postgres drivers) against pgbouncer transaction mode fails intermittently ("prepared statement does not exist") because the next statement lands on a different backend. Fix: set the driver/ORM to disable server-prepared statements, or run session mode.

## Exhaustion symptoms vs the fix

| Symptom | Real cause | Fix |
|---|---|---|
| "remaining connection slots reserved" / "too many clients" | fleet total > `max_connections` | server-side pooler or shrink per-instance pools |
| requests hang, then time out acquiring a connection | pool too small OR connections held too long | grow pool to the knee, or stop holding across I/O (`transaction-boundary`) |
| DB CPU high with modest QPS | pool oversized → context-switch thrash | shrink the pool to the parallelism knee |
| connections spike on deploy/scale-out | per-instance pool × new instances | pooler; cap autoscale connection budget |

The distinction that matters: **timeouts waiting for a connection** are either "pool too small" or "connections held too long" — never assume the first. A leaked connection held across a slow external call exhausts a correctly-sized pool.

## Serverless / Lambda

Serverless breaks per-instance pooling: each concurrent invocation is its own short-lived environment, and if each opens a raw DB connection, a burst of N invocations = N connections — a **connection storm** that exhausts the DB in seconds, and reconnect cost dominates the invocation.

- Put a **connection proxy in front**: RDS Proxy / a data API (e.g. Aurora Data API) / a pgbouncer sidecar — it holds the warm pool; invocations borrow.
- Keep per-invocation pool size = 1 (or reuse across warm invocations) and lean on the proxy for multiplexing.
- Never point raw serverless functions at the DB's native port at scale.

## Idle, lifetime, validation

- **Max idle / min idle** — reclaim idle connections so an idle service doesn't pin the ceiling; keep a small warm floor to avoid cold-connect latency.
- **Max lifetime** — recycle connections periodically (below any DB/LB idle timeout) so a silently-dead connection is retired before a request gets it. Prevents "server closed the connection unexpectedly" after a failover.
- **Validation / test-on-borrow** — a cheap liveness check (or lifetime cap) so a broken connection isn't handed to a request; keep it light — validating every borrow adds latency.
- **Acquire timeout** — bound the wait for a free connection so a saturated pool fails fast (surfacing back-pressure) instead of hanging every request.

## Connection held across an external call (the leak)

The most common way a correctly-sized pool still exhausts: a connection (often inside an open transaction) is checked out, then the code makes an **HTTP/gRPC/queue/slow-compute call**, holding the connection idle for hundreds of ms. Under load the pool drains and every other request waits.

- Do the external I/O **outside** the transaction and **after** returning the connection.
- This is the pool-side symptom; the *fix* is scoping the transaction to the write-set only — cross-ref backend **`transaction-boundary`**, which owns "no external I/O inside a transaction."

## Adapt to the codebase

Extract the driver/pooler, then map to its sizing knob and mode setting.

| Layer | Pool / size knob | Mode / proxy |
|---|---|---|
| **Postgres** | `max_connections` (server); app pool `max` | pgbouncer `pool_mode = transaction\|session`; RDS Proxy |
| **MySQL** | `max_connections`; app pool | ProxySQL; RDS Proxy |
| **HikariCP (JVM)** | `maximumPoolSize`, `minimumIdle`, `maxLifetime`, `connectionTimeout` | app-side pool; pgbouncer downstream |
| **Node (pg / mysql2)** | `pool.max`, `idleTimeoutMillis`, `connectionTimeoutMillis` | disable server-prepared for txn-mode pgbouncer |
| **SQLAlchemy** | `pool_size`, `max_overflow`, `pool_recycle`, `pool_pre_ping`, `pool_timeout` | `NullPool` behind an external pooler |
| **Prisma** | `connection_limit` in the URL | `pgbouncer=true` (disables prepared stmts) |
| **Serverless** | pool = 1 per invocation | RDS Proxy / Data API — mandatory |

## Detectors (cite-or-halt)

Each finding cites `<file:line>` for the pool/connection config + the matched pattern + the fix.

1. **No pool / new connection per request.** BAD: `connect()` / `new Client()` inside a request or job handler, closed at the end — reconnect per request, unbounded under concurrency. GOOD: a module-level bounded pool borrowed per request. Grep: `connect(|createConnection|new Client(|psycopg2.connect` inside a handler/route body.
2. **Pool × instances exceeds server max.** BAD: `pool.max = 30` on a fleet of 20 pods against `max_connections = 100`. GOOD: `per_instance × instances < max − reserve`, or a server-side pooler. Cite the pool `max`, instance count, and `max_connections`; do the arithmetic.
3. **Transaction-mode pooler with prepared statements / session state.** BAD: pgbouncer `pool_mode = transaction` with an ORM using server-prepared statements or `SET`/`LISTEN`/temp tables. GOOD: disable server-prepared (`pgbouncer=true` / driver flag) or use session mode. Grep: `pool_mode\s*=\s*transaction` cross-checked against prepared-statement/session usage.
4. **Serverless with raw connections (no proxy).** BAD: a Lambda/edge function opening a native DB connection per invocation. GOOD: RDS Proxy / Data API / sidecar pooler + pool size 1. Grep: DB `connect(` in a serverless handler with no proxy host in the connection string.
5. **Connection acquired then held across a network call.** BAD: transaction open → `await httpClient.post(...)` / external RPC → then commit, holding the connection idle. GOOD: external I/O outside the transaction, after releasing. Cross-ref `transaction-boundary` for the fix. Grep: `fetch(|http|grpc|await client.` between a `begin`/checkout and `commit`/release.
6. **Unbounded / missing lifetime + acquire timeout.** BAD: no `max` (or a huge one), no `maxLifetime`/`pool_recycle`, no acquire timeout — leaks pin the ceiling and dead connections outlive failover. GOOD: bounded `max`, lifetime below the LB/DB idle timeout, a fast acquire timeout. Grep: pool config missing `max`/`maximumPoolSize`, `maxLifetime`/`pool_recycle`, `connectionTimeout`.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete bounded-pool / resized `max` / pooler-mode / disable-prepared / lifetime+timeout / proxy patch.
- `report-flagged` — the fix is a design/ops call (introduce pgbouncer/RDS Proxy; session-vs-transaction mode under measured session usage; the per-workload pool number `database-optimizer` must tune) → surface for ADR.
- `dismiss` — carve-out applies (single-process script; embedded DB; the wait is a slow query, not a small pool → route to `query-optimizer`) → documented with the reason.

## Related

- `transaction-isolation.md` — a lock/`FOR UPDATE` held too long pins a pooled connection; short transactions keep the pool healthy.
- `indexing-strategy.md` — a missing index that makes queries slow keeps connections checked out longer, straining the pool; fix the query before growing the pool.
- `sharding-partitioning.md` — each shard/replica has its own `max_connections`; the fleet ceiling is per-target, not global.
- `backend` `transaction-boundary` — owns the ownership boundary above: no external I/O inside a transaction, so connections aren't held across the network. State the split when a finding is really about scope, not sizing.
- `@database-optimizer` / `@schema-reviewer` — review agents that consume these detectors; `database-optimizer` tunes the case-by-case pool numbers.
