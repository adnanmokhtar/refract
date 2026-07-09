---
name: connection-pooling
kind: example
pack: database
---

# Pattern: Connection Pooling

Every process talks to the database through a **bounded** connection pool whose size is derived from the DB's real connection ceiling — never a fresh connection per request and never a pool sized by guesswork. `pool_size_per_instance × instance_count` MUST stay below the server's `max_connections` (minus superuser + replication reserve). An unbounded strategy, a per-request `connect()`, or a transaction-mode pooler used with prepared statements / session state is forbidden. Sizing/mode is here; per-workload tuning is `database-optimizer`; don't-hold-across-IO is backend `transaction-boundary`. Extract the server `max_connections` first — sizing without it is guesswork.

## Adapt to the codebase

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

1. **No pool / new connection per request.** BAD: `connect()` / `new Client()` inside a request or job handler — reconnect per request, unbounded under concurrency. GOOD: a module-level bounded pool borrowed per request.
2. **Pool × instances exceeds server max.** BAD: `pool.max = 30` on 20 pods against `max_connections = 100`. GOOD: `per_instance × instances < max − reserve`, or a server-side pooler. Do the arithmetic.
3. **Transaction-mode pooler with prepared statements / session state.** BAD: pgbouncer `pool_mode = transaction` with server-prepared statements or `SET`/`LISTEN`/temp tables. GOOD: disable server-prepared (`pgbouncer=true` / driver flag) or use session mode.
4. **Serverless with raw connections (no proxy).** BAD: a Lambda/edge function opening a native DB connection per invocation — connection storm. GOOD: RDS Proxy / Data API / sidecar pooler + pool size 1.

## Related

- `transaction-isolation.md` — a lock/`FOR UPDATE` held too long pins a pooled connection; short transactions keep the pool healthy.
- `read-replicas.md` — replicas need their own pools; the fleet connection ceiling is per-target, not global.
- `backend` `transaction-boundary` — no external I/O inside a transaction, so connections aren't held across the network.
