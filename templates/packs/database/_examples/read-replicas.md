---
name: read-replicas
kind: example
pack: database
---

# Pattern: Read Replicas

> **Hard rule:** Any read routed to a replica MUST tolerate replication lag. A read that depends on a write the same actor just made (read-your-writes), or any correctness-sensitive read (auth, balance, authorization, uniqueness check), goes to the **primary** or uses a consistency token (session/LSN) — never blindly to a possibly-lagging replica. Routing a just-written record's read to an async replica and trusting the result is forbidden. Cite the engine + version, the replication mode (sync/async), the observed/max lag, and the read's routing decision at `<path:line>` — or halt.

Any read routed to a replica MUST tolerate replication lag. A read that depends on a write the same actor just made (read-your-writes), or any correctness-sensitive read (auth, balance, authorization, uniqueness check), goes to the **primary** or uses a consistency token (session/LSN) — never blindly to a possibly-lagging replica. A replica is an **asynchronously lagging copy** by default; the engineering is classifying each read's staleness tolerance and routing accordingly, with lag measured and a failover plan ready. `sharding-partitioning` splits writes; replicas scale reads only. Extract the engine + replication mode (sync/async) first — lag semantics differ.

## Adapt to the codebase

| Layer | Route to replica | Lag signal | Read-your-writes |
|---|---|---|---|
| **Postgres** | second connection / pool to standby | `pg_wal_lsn_diff`, `replay_timestamp` | primary-pin window or LSN token |
| **MySQL** | replica DSN / ProxySQL rule | `Seconds_Behind_Source`, GTID | GTID `WAIT_FOR_EXECUTED_GTID_SET` or pin |
| **Aurora** | reader endpoint | `AuroraReplicaLag` | session consistency mode / pin |
| **Rails / ActiveRecord** | `connected_to(role: :reading)` | adapter lag check | `connected_to(role: :writing)` after writes |
| **Django** | database router (`db_for_read`) | custom check | route writer's reads to `default` |
| **Proxy** | pgpool / ProxySQL / RDS Proxy split | proxy lag eviction | pin/token still required at app layer |

## Detectors (cite-or-halt)

The method lives here. Read-after-write on a replica, no lag awareness, and stale-sensitive reads sent to a replica → `connection-config-scan` §8. Replicas left idle and analytics on the primary → distributed-systems `@capacity-planner` (when installed). No failover plan → infrastructure `dr-audit` (when installed).

## Related

- `sharding-partitioning.md` — replicas scale reads, sharding splits writes; exhaust replicas + caching before sharding.
- `transaction-isolation.md` — a read-your-writes guard before a write must use the primary; replica reads can't hold the locks a consistent read-modify-write needs.
- `connection-pooling.md` — replicas need their own pools; the fleet connection ceiling is per-target (primary + each replica), not global.
