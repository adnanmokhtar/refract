# Precedents — data (integrity, concurrency, migrations, types, tenancy, connections)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **correctness** class of the data domain: schema integrity, transactions and
concurrency, migrations, types and constraints, tenancy and soft delete, poolers, replicas,
timeouts, backups and retention. Cost classes (plans, indexes, query shape, N+1, unbounded reads,
pool sizing) are in [`performance.md`](performance.md). The three cross-domain precedents (tests and
seeds, mechanisms the engine does not have, numbers no tool produced) are in
`refute-before-report.md § 4`.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**; the flip evidence makes it a candidate again.
Numbers are stable: detectors cite `precedents/data.md § <n>`.

## Transactions and concurrency

1. **A single SQL statement is atomic.** `UPDATE … SET n = n - 1 WHERE id = $1 AND n >= 1` needs no explicit transaction. Under READ COMMITTED, Postgres re-checks the `WHERE` against the newest row version after waiting, and InnoDB DML reads the latest committed row, so the conditional atomic update is the **fix** for a lost update, not a race. *Flips back:* the value is computed in application memory and written back (`SET n = :new`).
2. **A race needs a concrete interleaving and a concrete loss** — an oversell, a double redeem, a negative balance, a duplicate row. "Not in a transaction" with no invariant at risk is Hardening at most. *Flips back:* name the two operations, the read both make, and the invariant the second write breaks.
3. **`get_or_create`, `find_or_create_by`, `firstOrCreate` and `upsert` are safe with a unique constraint behind them** and the loser's duplicate-key error handled. *Flips back:* no unique index on the lookup columns, or a unique index that does not match them (case, tenant scope, NULLs).
4. **Optimistic locking or SERIALIZABLE without a retry is the finding — not their use.** A version column, or SSI with a bounded retry on `40001`/`40P01` (MySQL 1213) that re-runs the **whole** transaction with side effects outside it, is a correct design.
5. **Savepoints in moderation are fine.** Nested transactions (`atomic()` inside `atomic()`, `requires_new`, `begin_nested()`) are a finding only inside loops on hot paths at volume. *Flips back:* reads go to replicas and long-running transactions are common — GitLab (2021-09-29) found that a single `SAVEPOINT` inside a long-running transaction, under heavy concurrent writes, stalled its replicas, and removed savepoints entirely. Past 64 open subtransactions per backend, lookups also spill to `pg_subtrans`.
6. **An outbox insert inside the transaction is the correct pattern** for a side effect; the publish happens after commit. External I/O (HTTP, queue publish, email, payment SDK) between the transaction's open and its commit is the finding.
7. **Last-writer-wins is correct where overwriting is the semantics** (display name, preferences) or where one writer owns each key. Append-only inserts lose nothing.
8. **One statement reads one snapshot.** A report computed in a single statement at READ COMMITTED cannot read skew; a report that sums across two statements can (it needs a REPEATABLE READ or `SERIALIZABLE READ ONLY DEFERRABLE` snapshot).
9. **`FOR UPDATE SKIP LOCKED` belongs on queue-like tables only.** It returns an inconsistent view by design (Postgres `SELECT` docs). A single consumer needs neither it nor `FOR UPDATE`; the finding is two or more workers claiming with a bare `SELECT` then `UPDATE`.
10. **Advisory locks with a documented scope are fine.** The finding is a **session-level** `pg_advisory_lock` behind a transaction-mode pooler (the lock lands on an arbitrary backend), or one not released on the error path; `pg_advisory_xact_lock` inside an explicit transaction is the remedy.
11. **Money, stock, quota and single-use races belong to security** (`logic-race-scan`) when the security pack is installed; this domain lists them as `owner: security` and dedupes by `<file:line>`. Non-abuse counters and fields stay here.

## Migrations

12. **A blocking statement on a table created in the same migration, or still empty, is not a finding.** Non-concurrent index, FK, `NOT NULL`, type change — all safe on a new table. Linters flag these; the reader clears them (eugene's own linter skips objects created in the same transaction).
13. **Some DDL that sounds dangerous is metadata-only on modern versions.** Postgres ≥ 11: `ADD COLUMN … DEFAULT <constant>` (non-volatile) does not rewrite; widening `varchar(n)` or `varchar → text` does not rewrite; `DROP COLUMN` does not rewrite. Each still takes `ACCESS EXCLUSIVE` briefly, so the finding, if any, is a missing `lock_timeout` — not a rewrite.
14. **MySQL InnoDB secondary-index builds run in place with concurrent DML permitted.** `pt-osc` or `gh-ost` is required for a table-copy change, or when the build must be throttled or paused — not for every index. *Flips back:* a FULLTEXT or SPATIAL index, which does not permit concurrent DML (and the first FULLTEXT index rebuilds the table unless an `FTS_DOC_ID` column exists).
15. **A lock timeout set by the runner counts as the control.** A `lock_timeout` in the migration-runner config, a wrapper (`strong_migrations`), or `SET LOCAL lock_timeout` at the top of the migration clears a "no lock timeout" candidate. Read the runner before reporting.
16. **"No down migration" is not a finding where the project is forward-only by policy** (documented roll-forward, expand/contract). It is one where the convention is reversible migrations and the step destroys data.
17. **Drop and rename are compatibility issues, not lock issues.** `DROP COLUMN` is fast in Postgres; the finding is the running N-1 code that still selects the column (ORM schema caches, explicit `SELECT` lists, Rails `ignored_columns` not yet shipped). Clear it once the code no longer references the column **and** the ignore step has shipped first.

## Types, constraints and the data model

18. **`float`/`double` is a finding for money only.** Measurements, scores, coordinates, ratios and ML features are legitimately floating point. Integer minor units in `bigint` with a currency column is a correct money type, not a float.
19. **`timestamp without time zone` is right for wall-clock values that are not instants** — a store's opening time, a future local appointment stored with its IANA zone (zone rules change; UTC-only storage breaks those). It is a finding for instants (`created_at`, `paid_at`, `expires_at`) compared across zones. `date` is right for date-only facts.
20. **Postgres `varchar(n)` vs `text` is style**, unless `n` silently truncates (MySQL without strict mode) or rejects valid input on a hot path.
21. **Natural-key uniqueness has a skip list.** Log, event, audit and line-item tables have no natural key; a missing unique constraint there is not a finding.
22. **NULLs are distinct in a unique constraint by default**, which is the intended "optional but unique if present" semantics. *Flips back:* the business rule is "exactly one per tenant, including the NULL case" (Postgres ≥ 15 `NULLS NOT DISTINCT`, or a partial unique index).
23. **Sequence gaps are normal.** `nextval` is not rolled back. Gaps are a finding only where consecutive numbering is a legal requirement (invoice and receipt numbers), which needs a counter row updated under lock in the issuing transaction.
24. **`int4` keys are fine on bounded lookup tables.** On append-heavy tables (events, logs, messages) they are a finding with the growth rate cited — Basecamp spent about five hours read-only on 2018-11-09 when an `integer` id overflowed.
25. **A relation without a database FK is a known trade-off where an FK is impossible** (cross-database or sharded references) or where rows must outlive the parent (audit, logs), provided a scheduled orphan anti-join exists. A polymorphic association is the same: the finding is an orphan-producing delete path with no cleanup.
26. **`ON DELETE CASCADE` on owned children is intended.** On a shared or reference table, or from a root aggregate (users, tenants, accounts) into records of fact (invoices, ledger, audit), it is a data-loss finding.
27. **A constraint that is not enforced is not a control.** Postgres 18 `NOT ENFORCED` CHECK/FK constraints are documentation; SQLite parses FKs but enforces them only on connections that ran `PRAGMA foreign_keys = ON`. Neither clears a missing-constraint candidate.
28. **An intentionally nullable column with a stated reason is not a finding.** The finding is a column the code dereferences without a null check, declared nullable by default.

## Tenancy, soft delete and access

29. **RLS is defence in depth when the database is private.** With a private DB and an application role, a missing RLS policy is not itself the finding — the missing tenant predicate in the application's data access is. When clients reach the database directly (PostgREST or Supabase anon key, Hasura, direct client connections), RLS off on an exposed table is critical, and it routes to security.
30. **Unfiltered soft-deleted rows are correct in audit, admin, restore and erasure paths** when they use the ORM's explicit escape (`withDeleted`, `unscoped`, `withTrashed`, `filters: false` with a comment naming the path). Implicit bypass — raw SQL, a join, an aggregate — on a user-facing path is the finding.
31. **A view or RLS policy that applies the soft-delete or tenant filter is the control** for every query that reads through it. Check the view is `security_invoker` (Postgres ≥ 15) when it sits over RLS tables.
32. **A global unique key is right on a genuinely global identity table.** On a tenant-owned table it is a finding twice: it blocks the same email in two tenants, and the duplicate-key error tells tenant A that tenant B's value exists.

## Connections, poolers, replicas and timeouts

33. **Protocol-level prepared statements work behind PgBouncer's transaction mode** from 1.21 (2023-10-16) when `max_prepared_statements > 0`; the default is 200 from 1.24 (2025-01-10). SQL-level `PREPARE`, session `SET`, `LISTEN`, `WITH HOLD` cursors and session advisory locks remain the finding there.
34. **`SET LOCAL` and `set_config(…, true)` inside a transaction are safe behind a transaction pooler**; a session-scope `SET` of tenant or role context is the finding (the next client inherits it).
35. **Read-only analytics routed to a replica is fine.** Read-after-write on a replica is the finding; a sticky-primary window after writes, or a GTID/LSN wait, is the control.
36. **A global `statement_timeout` in `postgresql.conf` is not the expected control.** Postgres docs advise against it; a per-role (`ALTER ROLE … SET`) or per-connection setting is. ETL, migration and reporting roles with deliberately larger per-role limits are intended.
37. **A pool that validates on borrow, or whose max lifetime sits below the server's and the load balancer's idle limits, is not exposed to "server has gone away"** after idle; the finding is a lifetime at or above them.

## Backups and retention

38. **Derivable data needs no restore drill** — caches, search indexes and read models rebuildable from a source of truth. Records of fact do.
39. **Ephemeral and test stacks may skip the final snapshot and deletion protection.** Flag those settings on production modules only.
40. **A legal hold, or an undo window with a TTL purge, is not an erasure finding.** An erasure workflow that only sets `deleted_at` and never purges is.

---

Sources (accessed 2026-10-02 unless dated): PostgreSQL 18 docs — *Transaction Isolation*, *Explicit
Locking*, *Constraints*, *SELECT* (`SKIP LOCKED`), *Client Connection Defaults* (timeouts),
*Sequence Functions*, *CREATE VIEW*; PostgreSQL 15 and 18 release notes (2022-10-13, 2025-09-25);
MySQL 8.4 Reference Manual — *Consistent Nonlocking Reads*, *FOREIGN KEY Constraints*, *Online DDL
Operations* (index operations table);
SQLite *Foreign Key Support*; PgBouncer *Features* and changelog (1.21.0, 1.24.0); eugene README
(MIT, <https://github.com/kaaveland/eugene>); Basecamp postmortem of the 2018-11-09 read-only outage
(signalvnoise.com); GitLab, *Why we spent the last month eliminating PostgreSQL subtransactions*
(about.gitlab.com, 2021-09-29; fetched 2026-10-02). Paraphrased; no text reproduced.
