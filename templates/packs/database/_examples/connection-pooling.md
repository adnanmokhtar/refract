---
name: connection-pooling
kind: example
pack: database
---

# Pattern: Connection Pooling

> **Hard rule:** Every process talks to the database through a **bounded** connection pool whose size is derived from the DB's real connection ceiling — never a fresh connection per request and never a pool sized by guesswork. `pool_size_per_instance × instance_count` MUST stay below the server's `max_connections` (minus superuser + replication reserve). An unbounded connection strategy, a per-request `connect()`, or a transaction-mode pooler used with prepared statements / session state is forbidden. Cite the engine + version, the server `max_connections`, the pool config at `<path:line>`, and the deployed instance count — or halt.

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

The method lives here; each class has one detector. No pool per request → `connection-config-scan` §1 · pool × instances over `max_connections` → §2 · transaction-mode pooler with session features → §3 · serverless raw connections → §4 · no acquire timeout or lifetime → §7 · a connection held across a network call inside a transaction → `transaction-scan` §1.

## Related

- `transaction-isolation.md` — a lock/`FOR UPDATE` held too long pins a pooled connection; short transactions keep the pool healthy.
- `read-replicas.md` — replicas need their own pools; the fleet connection ceiling is per-target, not global.
- `backend` `transaction-boundary` — no external I/O inside a transaction, so connections aren't held across the network.
