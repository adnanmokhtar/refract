---
name: read-replicas
description: "Pattern: Read Replicas — read traffic routed to replicas MUST tolerate replication lag; read-your-writes-sensitive reads go to the primary or use a consistency token."
kind: ai-pattern
pack: database
---

# Pattern: Read Replicas

> **Hard rule:** Any read routed to a replica MUST tolerate replication lag. A read that depends on a write the same actor just made (read-your-writes), or any correctness-sensitive read (auth, balance, authorization, uniqueness check), goes to the **primary** or uses a consistency token (session/LSN) — never blindly to a possibly-lagging replica. Routing a just-written record's read to an async replica and trusting the result is forbidden. Cite the engine + version, the replication mode (sync/async), the observed/max lag, and the read's routing decision at `<path:line>` — or halt.

**Ownership boundary:** `distributed-systems` `consistency-models` owns the **theory** — CAP, linearizability vs eventual/causal consistency, the guarantees and their proofs. THIS pattern owns the **concrete replica-routing mechanics**: primary/replica topology, which query goes where, read-your-writes via primary-pinning or LSN tokens, lag monitoring, and failover. `sharding-partitioning` owns the **horizontal write split** (more shards = more write capacity); replicas scale **reads** only and don't partition data. When a finding is about *which consistency model the system promises*, defer to `consistency-models`; when it's about *this query hitting a stale replica*, it's here; when it's about *write throughput exceeding one primary*, it's `sharding-partitioning`.

**When to apply**
- Read load saturates the primary and the workload is read-heavy (reports, dashboards, search, feeds).
- Analytics / heavy aggregate queries compete with OLTP on the primary and should be offloaded.
- A read replica already exists and you must decide, per query, primary vs replica.

**When NOT to apply**
- Write throughput is the bottleneck — replicas don't help writes; that's `sharding-partitioning` / vertical scaling.
- The workload is small enough that one primary serves reads comfortably — a replica adds lag surface and ops cost for no gain.
- Strong per-request consistency is required everywhere and lag can't be tolerated — keep reads on the primary or use synchronous replication with eyes open on its latency cost.

**Halt conditions / mandatory cites**
- The DB engine + version + replication mode (synchronous vs asynchronous) MUST be extracted — lag semantics differ (Postgres streaming/`synchronous_commit`, MySQL async/semi-sync/Group Replication, Aurora ~ms replica lag). Without it, halt.
- Every finding MUST cite the read at `<path:line>` AND its routing target (primary/replica) AND whether a preceding write by the same actor exists.
- A claim of "reads are on replicas safely" MUST cite the read-your-writes handling (primary-pin window / session token) AND a lag monitor. Missing either is the bug.
- A claim of "we route to replicas" MUST cite lag monitoring + a failover/promotion plan — routing to an unmonitored replica is flying blind.
- Hand-wave grep on `etc.`, `...`, `appears consistent`, `lag is negligible` is forbidden when claiming a replica read is safe.

A read replica is an **asynchronously lagging copy** by default — it reflects the primary as of some milliseconds-to-seconds ago. Replicas scale reads beautifully *if* every read that lands on one can tolerate seeing the recent past. The engineering is not "add a replica"; it's *classifying each read's staleness tolerance* and routing accordingly, with lag measured and a failover plan ready.

## Topology and replication mode

- **Primary (writer)** — takes all writes; the source of truth.
- **Replica(s) (reader)** — stream changes from the primary; serve reads only. A write to a replica is an error.
- **Synchronous replication** — the primary waits for the replica to confirm before acknowledging the commit → zero (or bounded) lag, but every write pays the round-trip latency and a stalled replica can stall writes. Postgres `synchronous_commit`/`synchronous_standby_names`, MySQL semi-sync, Group Replication.
- **Asynchronous replication (default)** — the primary acks immediately; the replica catches up "soon." Fast writes, **real lag**. This is what most replicas are, and the reason the hard rule exists.

Sync vs async is a per-write latency/consistency trade — you rarely make *all* writes synchronous; you route the *reads* that can't tolerate async lag to the primary instead.

## The lag reality

Replica lag is not zero and not constant: it spikes under write bursts, long transactions on the primary, replica-side vacuum/DDL, network hiccups, and single-threaded apply on some engines. Measure it as a first-class signal:

- **Postgres** — `pg_last_xact_replay_timestamp()`, `pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)` (bytes behind).
- **MySQL** — `Seconds_Behind_Master` / `Seconds_Behind_Source` (coarse), or GTID-based lag.
- **Aurora / managed** — `ReplicaLag` / `AuroraReplicaLag` CloudWatch metric.

The number you route against is *observed p99 lag*, not the happy-path average.

## Read-your-writes (the core correctness case)

The classic bug: a user updates their profile (write → primary), the UI immediately re-reads it (read → replica), the replica hasn't caught up, and the user sees their *old* data — "my save didn't work." Fixes, cheapest to strongest:

- **Primary-pin window** — after a write, route that session/user's reads to the **primary** for a short window (a few seconds, longer than p99 lag). Simple, covers the vast majority of read-your-writes cases.
- **Session / LSN consistency token** — capture the write's log position (Postgres commit LSN, MySQL GTID) and route the follow-up read to a replica **only once it has replayed past that token** (or wait). Aurora exposes a session-consistency mode; some proxies do this automatically. Precise, no blanket primary load.
- **Read from primary for that entity** — for a small set of always-read-your-writes entities, just never route them to a replica.

Pick per read, driven by *who* made the preceding write, not a global switch.

## Routing strategies

- **Per-query annotation** — mark each query `writer`/`reader`/`reader-consistent`. Explicit, auditable; the default for app-level routing.
- **Writes + recent-reads → primary** — the primary-pin window applied automatically after any write in the session.
- **Analytics / reports → replica (or a dedicated read-only replica)** — heavy aggregates offloaded so they never touch OLTP. A stale dashboard is fine.
- **Proxy-based** — pgpool / ProxySQL / RDS Proxy / a driver read-write split can route by statement type, but statement-type routing alone does **not** solve read-your-writes — a `SELECT` right after an `UPDATE` still needs the pin/token. Treat proxy split as transport, not consistency.

## Lag monitoring and failover

- **Monitor lag continuously**, alert past a threshold, and — ideally — let the router **eject** a replica whose lag exceeds the tolerance so stale reads stop flowing to it automatically.
- **Failover / promotion** — when the primary dies, a replica is promoted to primary. Have the plan: automated (Patroni, RDS Multi-AZ, Aurora failover, Orchestrator) with a bounded RTO, and know that an *async* replica promoted after a primary crash can **lose the un-replicated tail** of writes (RPO > 0) — a consistency/durability decision to make deliberately, not discover during an incident.
- A replica set with no failover plan is a read-scaling tool that becomes an outage the moment the primary dies.

## The stale-read blast radius

Classify each read by what a few seconds of staleness costs:

- **Fine on a replica** — dashboards, reports, search results, feeds, "recently viewed," analytics, most list views. Staleness is invisible or harmless.
- **NOT fine on a lagging replica** — an **auth/authorization check** (a revoked permission must not still read as granted), a **balance/inventory** guard before a write, a **uniqueness** pre-check, anything the same actor just wrote, anything a subsequent write conditions on. These go to the primary or use a token.

"Route reads to replicas" is never global — it's this classification applied per read. A stale dashboard is a shrug; a stale auth check is a security hole.

## Adapt to the codebase

Extract the engine + how the app selects a connection, then map to routing + lag + read-your-writes.

| Layer | Route to replica | Lag signal | Read-your-writes |
|---|---|---|---|
| **Postgres** | second connection / pool to standby | `pg_wal_lsn_diff`, `replay_timestamp` | primary-pin window or LSN token |
| **MySQL** | replica DSN / ProxySQL rule | `Seconds_Behind_Source`, GTID | GTID `WAIT_FOR_EXECUTED_GTID_SET` or pin |
| **Aurora** | reader endpoint | `AuroraReplicaLag` | session consistency mode / pin |
| **Rails / ActiveRecord** | `connected_to(role: :reading)` | adapter lag check | `connected_to(role: :writing)` after writes; automatic replica-lag window |
| **Django** | database router (`db_for_read`) | custom check | route writer's reads to `default` |
| **Prisma / TypeORM** | replica URL / `replication` config | manual | route post-write reads to primary |
| **Proxy** | pgpool / ProxySQL / RDS Proxy split | proxy lag eviction | pin/token still required at app layer |

## Detectors (cite-or-halt)

Each finding cites `<file:line>` for the read + its routing target + the matched pattern + the fix.

1. **Read-after-write routed to a replica (stale read).** BAD: an `UPDATE`/`INSERT` on the primary followed by a `SELECT` of the same record on a replica in the same request/session — user sees stale data. GOOD: primary-pin window or LSN/GTID token for that read. Grep: a `reader`/replica `SELECT` in a handler that also performed a write on the same entity.
2. **No lag awareness / monitoring.** BAD: reads routed to replicas with no lag metric, alert, or router eviction. GOOD: continuous lag monitoring + threshold alert + eject-on-lag. Grep: replica routing config with no reference to `ReplicaLag`/`Seconds_Behind`/`replay_lsn`/lag threshold.
3. **All reads to primary (replicas wasted).** BAD: replicas provisioned but every `SELECT` hits the writer — paying for read scaling, getting none. GOOD: staleness-tolerant reads (reports, feeds, search) routed to replicas. Flag for routing work; cite the primary CPU/read load evidence.
4. **All reads to a replica (stale-sensitive ones break).** BAD: a blanket "reads → replica" rule that also sends auth checks, balance guards, and read-your-writes to a lagging copy. GOOD: per-read classification; sensitive reads to primary/token. Grep: a global read-split with no carve-out for auth/consistency-critical queries.
5. **Analytics / report queries on the primary.** BAD: heavy aggregate/report/export queries running on the writer, competing with OLTP. GOOD: offload to a replica or a dedicated read-only/analytics replica. Grep: large `GROUP BY`/`JOIN`/export queries pinned to the primary connection.
6. **No failover / promotion plan.** BAD: replica routing with no automated promotion, RTO, or acknowledged RPO for async loss-of-tail. GOOD: documented failover (Patroni/RDS/Aurora/Orchestrator) + RTO/RPO stance. Flag for ADR — routing without a promotion plan is an outage-in-waiting.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete primary-pin / LSN-or-GTID-token / route-analytics-to-replica / lag-monitor+eviction patch.
- `report-flagged` — the fix is a design/ops call (introduce failover automation; sync-vs-async for a class of writes; the RPO the business will accept; which reads are staleness-tolerant) → surface for ADR.
- `dismiss` — carve-out applies (write-bound workload where replicas don't help → `sharding-partitioning`; a genuinely staleness-immune read; single-primary is sufficient at current load) → documented with the reason.

## Related

- `sharding-partitioning.md` — the boundary above: replicas scale reads, sharding splits writes; exhaust replicas + caching before sharding.
- `transaction-isolation.md` — a read-your-writes guard before a write must use the primary; replica reads can't hold the locks a consistent read-modify-write needs.
- `connection-pooling.md` — replicas need their own pools; the fleet connection ceiling is per-target (primary + each replica), not global.
- `distributed-systems` `consistency-models` — owns the CAP/linearizability theory this pattern's routing enforces in practice; state the split when a finding is really about the promised consistency model.
- `@database-optimizer` / `@schema-reviewer` — review agents that consume these detectors.
