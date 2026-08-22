---
description: Generate a safe, reversible, deploy-compatible DB migration. Expand-contract for breaking changes on populated tables. Rehearsed against realistic data before prod.
---

# /add-migration

Migrations are the highest-risk code in a repo. One bad migration = hours of prod pain. This command enforces the discipline.

## The Premise (read this first, internalize, do not deviate)

**Existing migrations are the truth. Mirror their shape: naming, reversibility pattern, transactional wrapping, batch-size for backfills.**

The repo already has N migrations that shipped to prod and worked. Their shape — file naming (`<NNNN>-<slug>.ts` vs `<timestamp>_<slug>.sql`), `up()`/`down()` symmetry, transactional vs `CONCURRENTLY` boundary, batch size constants (1000 vs 5000), `SKIP LOCKED` usage, locale of comments — IS the convention. A new migration that deviates from that shape is wrong by default, regardless of whether the SQL is correct.

**The agent's job is exactly this:**
1. Read the 3-5 most recent migrations on the same table family.
2. Mirror their shape: same file-name template, same `up`/`down` symmetry, same wrapping idiom, same batch constant, same comment style.
3. Write the new SQL inside that shape. Never invent a new shape.

**The agent does NOT:** ask about file naming, batch size, `down()` shape, or transactional wrapping when ≥1 sibling migration exists. The sibling IS the answer. No ADR-as-closure for shape divergence.

**The agent ONLY asks the user when:** no sibling migrations exist, sibling shapes contradict each other, or the change is irreversible by physics (DROP COLUMN with data loss) and `down()` cannot mirror sibling pattern. Three escalation triggers; everything else is silent shape-mirroring.

## Closure-verb tiers (mandatory dispatch table)

Severity is a function of the **operation class** *and* of whether the engine permits writes through it (§ Phase 2) — never of the row count. Row count sets how long a rebuild takes; the class decides whether there is a rebuild at all; the engine's `Permits Concurrent DML` column decides whether it needs a window. Do not collapse the last two.

| Severity | Closure | User prompt? |
|---|---|---|
| **P0** — an op on a populated table that **blocks concurrent writes** per the engine's own DDL table (MySQL `ALGORITHM=COPY`; Postgres holding `ACCESS EXCLUSIVE` across a scan or rewrite), or any breaking op (DROP / RENAME / type-incompat) whose readers are still live | `escalate` | YES — surface expand-contract plan, wait |
| **P0** — `synchronize: true` / auto-migrate path detected in config | `escalate` | YES — halt, no migration generated until removed |
| **P0** — the op is class-1/2 on paper but the target table fails its engine's fast-path probe (§ Phase 2) — the op silently becomes class-3 | `escalate` | YES — name the failed condition before generating |
| **P1** — class-2 on a populated table (index build, constraint validation, batched backfill), **or a class-3 rebuild the engine permits writes through** (e.g. MySQL `SET NOT NULL` in place). Long and IO-heavy: needs disk headroom and a replica-lag plan, not a maintenance window | `code-edit` (mirror sibling expand-contract) | NO — auto-generate multi-step |
| **P2** — class-1 (metadata-only) op that passed the fast-path probe | `code-edit` (single migration, sibling shape) | NO — auto-generate |
| Sibling migrations contradict OR none exist | `escalate` | YES — halt, ask for canonical shape |

**Every tier is conditional on the definition-lock pre-flight** (§ Phase 2 → "The lock nobody classifies"). A class-1 op still takes the table down if it queues behind a long-running transaction. P2 means "the statement itself is cheap", never "run it now".

**Forbidden:** asking the user about file naming, batch size, transactional wrapping, or `down()` emptiness when ≥1 sibling migration exists. The sibling IS the answer. Equally forbidden: assigning a tier from a row count without naming the operation class.

## Mechanical halt — sibling-shape gate

**Before generating, the agent MUST run the sibling-shape scan:**

1. List the 3-5 most recent migration files in the project's migration folder.
2. Extract the shape signature: file-name template, `up()`/`down()` presence, transactional boundary, batch constant (if backfill), comment header style.
3. The new migration's shape signature MUST match. If it diverges on any axis without justification recorded in the migration's comment header, HALT.
4. The validator-equivalent check: `gaps_in: <shape-axes-checked>` and `gaps_matched: <shape-axes-matched>` must be equal.

If `gaps_matched != gaps_in` → HALT. Surface the divergence (e.g., "siblings use `down()` with reverse SQL; this draft has empty `down()` — refix or escalate").

If no siblings exist → halt and ask user to confirm canonical shape before generating.

## Lightweight default

**Default closure is single-migration generation in sibling shape, no chatter.** The agent does NOT ask questions on file naming, comment header, batch size, or wrapper shape when sibling migrations answer them. It generates, runs the sibling-shape gate, and reports in a batched summary:

```
Auto-applied (no prompt): sibling-shape mirror
  - file naming: <NNNN>-<slug>.ts (matched 5/5 recent siblings)
  - down() symmetry: full reverse SQL (matched 5/5)
  - batch constant: 1000 (matched 3/3 backfills)
  - transactional wrap: outside-transaction for CONCURRENTLY (matched 2/2 index migrations)
Escalated to user: <K>
  - <only genuine P0 / sibling-contradiction / first-of-kind cases>
```

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## `--plan`

Accepts `--plan` (see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md)). With the flag set: run Phases 1-3 read-only (classify the op, size the table, run the sibling-shape scan), then emit the migration file(s) it WOULD generate — full `up()`/`down()` SQL, the expand-contract step sequence, batch constants — as a plan artifact under `.claude/plans/`. **Write no migration file, run no rehearsal, touch `ai/` not at all.** A normal run (no flag) generates as documented.

## Honesty clause

No claim without the artifact behind it: do not report a duration, lock window, or rollback time without a real `migration-rehearsal` timed run (per its "no number without a real timed run" discipline); do not list a Phase-3 read (e.g. `zero-downtime-deploys.md`) the agent did not actually open; do not mark a safety-checklist line ✓ without verifying it against the generated SQL. Unrun checks are reported as `not run`, never as ✓.

## Migration-Safety Gate — production-grade-or-INCOMPLETE (the closing verdict)

**"It applies on an empty DB" is the FLOOR, not the bar.** A migration that generates cleanly, has a non-empty `down()`, and mirrors sibling shape is merely FUNCTIONAL. The run declares **`Status: COMPLETE`** ONLY when the migration is PRODUCTION-GRADE against all five dimensions below — each PASS backed by a cited artifact, or ADR-JUSTIFIED-and-stated. Any dimension unmet, or whose evidence could not be produced, forces **`Status: INCOMPLETE — <unmet dims named>`**. A `COMPLETE` sitting on bare ✓ marks with no cited evidence is enforcement theater — forbidden here.

| # | Dimension | PASS requires (evidence, not assertion) | ADR-justified alternative (must state the accepted cost, not "should be fine") |
|---|---|---|---|
| **D1 Reversible** | `down()` reverses AND a real rollback was rehearsed | `down()` non-empty + reverse SQL, AND the `migration-rehearsal` report's **Rollback** block shows `Schema: restored ✓ (baseline diff = 0)` — cite that line | ADR at `<path>` declares irreversible-by-physics (data-destroying `down()`), names the accepted one-way cost, and cites the pre-drop backup/archive step |
| **D2 Online / zero-downtime** | The **operation class is named** (1/2/3, § Phase 2) AND the lock + backfill profile is **REPORTED from a real timed run**, never assumed away | Op class stated with its engine-doc citation; the fast-path probe result for a class-1 claim; max lock mode + hold-time on the target table cited from the rehearsal report's **Forward/Locks** block; hold ≤ deploy SLO (default 30s) OR expand-contract splits every step below it; an explicit algorithm clause (`CONCURRENTLY` / `ALGORITHM=…, LOCK=…`) and a **lock timeout** set in the migration | ADR at `<path>` accepts a maintenance-window lock — states the measured hold from rehearsal, the booked window, and why online was rejected |
| **D3 Index coverage** | Every new WHERE / ORDER BY / JOIN column this change introduces is served by an index | Name the `<index_name>` on `<table.(cols)>` for each new access path; leftmost-prefix confirmed via `EXPLAIN` showing Index Scan (not `Seq Scan` + Filter dropping >90%). Index in THIS migration set or a named follow-up migration file on the branch | ADR states the path is intentionally unindexed (write-hot / low-selectivity column) with the write-amplification trade-off |
| **D4 Rename / type-change carries a backfill + dual-read/write plan** | A bare `RENAME COLUMN` / incompatible `ALTER COLUMN TYPE` on a populated table is NEVER production-grade | The expand-contract sequence exists as N real migration files (add → dual-write → backfill → switch-read → drop) AND the app dual-write phase is named in the deploy plan | **none** — no ADR launders a bare rename on a populated table; it breaks rolling deploys by construction |
| **D5 No data loss** | Destructive or narrowing steps are recoverable | `DROP COLUMN`/`DROP TABLE`/narrowing type/dedup-before-unique each cite a pre-step backup or archive-table copy, and `down()` restores OR is D1-ADR'd | ADR states the drop is safe because the column/table has been unread ≥ 1 release — cite the grep proving no code path reads it |

### How this gate is actually enforced (honest mechanism — no theater)

- **D1 + D2 are wired to a REQUIRED OUTPUT ARTIFACT** — the `migration-rehearsal` skill's report. That skill's own halt conditions already **refuse a duration without `time` output** and **refuse rollback-clean without a schema-diff = 0**, so the numbers this gate cites cannot be fabricated. The gate quotes the report's Forward/Locks + Rollback lines verbatim. If the rehearsal harness (a restored prod-sized backup) is **absent**, D1+D2 are marked `SKIPPED — UNVERIFIED`; for a populated table (>100k) that CANNOT be `COMPLETE` — the verdict is `INCOMPLETE (rehearsal-unverified)`, never a faked PASS. [wired-to-required-output]
- **D3 is wired to `EXPLAIN`** when the DB is reachable (Index Scan vs Seq Scan is captured output). When unreachable, D3 falls back to static index-presence only and is marked `UNVERIFIED (no EXPLAIN)`. [wired-to-required-output / partial]
- **D4 is wired to the Phase-6 follow-up-migration grep** shared with `/migration-review` (`git diff --name-only origin/main...HEAD -- '*migration*'` cross-checked against the expand-contract step slugs) — a promise in prose is not a planned migration. [wired-to-required-output]
- **D5 classification** (is this SQL step data-destroying / narrowing?) is judged by reading the SQL; no shell catches a subtle `varchar(64)→varchar(32)` truncation. It is **[self-policed]** and labelled so — the agent must not dress it as mechanical.

### Required output artifact

Every run MUST emit the **Migration-Safety Gate** verdict block (see Output § below): one `D1..D5` line each carrying `PASS <evidence-citation>` | `ADR <path>` | `INCOMPLETE <what's missing>` | `SKIPPED — UNVERIFIED <why>`, then the single `Status:` line. A reader greps this block: a `Status: COMPLETE` whose D-lines carry no citation is an **invalid artifact** — reject it and re-run. `COMPLETE` is reserved for production-grade; everything short of it is `INCOMPLETE` with the gap named, so the next actor knows exactly what remains.

## When to use / NOT to use

- USE: schema change (add/drop/alter column or table).
- USE: data migration (backfill, transformation).
- USE: index addition / removal.
- NOT: mutating data via app code (use a use-case).
- NOT: experimental schema changes (prototype in a branch DB first).

## Phase 1 — Understand (the change)

**Inference-first — do NOT interrogate the user.** Derive the four facts mechanically, then escalate only on a declared trigger:

- **What changes?** — read the entity/schema diff (uncommitted entity edits, or the diff vs `origin/main`). The op (add column / rename / drop / add table / add index / data transformation) IS the diff. No question.
- **Target table(s) + current size** — size up on the project's engine (Phase 3 carries the query for each). Size is an input to *duration* of a class-2/3 op, never to the class itself. Use the live count; fall back to the sibling migrations' recorded estimate if the DB is unreachable.
- **Multi-tenant?** — infer from `.claude/codebase-profile.md` (multi-tenancy declaration) + whether sibling tables on the same family carry `tenant_id`. If siblings have it, the new index gets the tenant prefix.
- **Deploy compatibility** — infer from the op class: breaking ops (DROP / RENAME / type-incompat) ⇒ expand-contract + backward-compat by construction; additive ops ⇒ backward-compat single migration. State the chosen mode; do not ask.

**Escalate to the user ONLY on the three declared triggers** (per The Premise): no sibling migrations exist, sibling shapes contradict, or the change is irreversible by physics and `down()` cannot mirror a sibling. Everything else is silent inference.

State the success criteria: a reversible, concurrent-write-safe migration (or expand-contract sequence) that ships with rehearsal evidence.

## Phase 2 — Organize (classify + choose pattern)

### Classify the operation — by class, not by row count

**Row count is the wrong first question.** A 4M-row table and a 40k-row table cost the same for an operation that never touches a row. What sets the lock window is: does the engine rewrite the rows, and may writers proceed while it does? Three classes:

| Class | What the engine does | Duration scales with | Concurrent writes |
|---|---|---|---|
| **1 — metadata-only** | swaps the table definition; touches no row | nothing (constant) | yes |
| **2 — in-place build / scan** | builds an index or scans to validate; rows stay put | rows × index width, or rows scanned | yes |
| **3 — rebuild / copy** | rewrites every row; needs that much free disk | bytes rewritten ÷ IO throughput | **read it off the engine's table — a rebuild does not imply a block** |

**Class 3 is a statement about cost, not about blocking.** The two are independent and MySQL separates them explicitly: an `ALGORITHM=COPY` rebuild refuses concurrent DML, while an `ALGORITHM=INPLACE` rebuild permits it for all but the brief final phase. Never infer "writes blocked" from "Rebuilds Table = Yes" — read the `Permits Concurrent DML` column, and carry both facts into the tier, because they select different closures.

The engine and version decide the class, not this document. Read the class off the engine's own DDL support table and cite the page in the migration header. Where the classes fall today:

| Op | Postgres 11+ | MySQL, InnoDB (version noted per row) |
|---|---|---|
| `ADD COLUMN` NULL, or with a **non-volatile** DEFAULT | **1** — default stored in catalog: "In neither case is a rewrite of the table required" | **1** — "INSTANT is the default algorithm as of MySQL 8.0.12, and INPLACE before that"; subject to the exclusions below |
| `ADD COLUMN` with a **volatile** DEFAULT (`now()`, random/uuid) | **3** — "will require the entire table and its indexes to be rewritten" | not the same split: a MySQL `DEFAULT` "can be a literal constant or an expression" (parenthesized). The row above covers a literal default; for an expression default, read the class from the running version's doc before claiming class 1 |
| `DROP COLUMN` | **1** — column made invisible; space reclaimed lazily by later updates | **1** — but INSTANT is the default only **as of 8.0.29**, INPLACE before that; burns a row version |
| `RENAME COLUMN`, `SET`/`DROP DEFAULT` | **1** | **1** INSTANT |
| `SET NOT NULL` on an existing column | **2** — full scan to verify, no rewrite, but under `ACCESS EXCLUSIVE` | **3, writes continue** — "Making a column NOT NULL": In Place **Yes**, Rebuilds Table **Yes**, Permits Concurrent DML **Yes**. Needs strict SQL mode and fails if any row is NULL, so backfill first |
| `ALTER COLUMN TYPE` (incompatible) | **3** | **3** — "Changing the column data type is only supported with `ALGORITHM=COPY`", Permits Concurrent DML **No** |
| `CREATE INDEX` / `ADD INDEX`, secondary | **2** with `CONCURRENTLY`; blocking without it | **2** — In Place Yes, Rebuilds **No**, Permits Concurrent DML **Yes**: "the table remains available for read and write operations while the index is being created" |
| `ADD FULLTEXT` / `ADD SPATIAL` index | **2** (`CONCURRENTLY` applies) | Permits Concurrent DML **No** — the exception to the row above |
| `ADD FOREIGN KEY` | **2** via `ADD CONSTRAINT … NOT VALID` then `VALIDATE CONSTRAINT` (validation takes only `SHARE UPDATE EXCLUSIVE`) | **3** unless `foreign_key_checks` is disabled: "The INPLACE algorithm is supported when `foreign_key_checks` is disabled. Otherwise, only the `COPY` algorithm is supported." MySQL has **no** `NOT VALID` |
| `UPDATE` all rows (backfill) | **2** if batched; unbatched it is a long transaction, not a DDL class | same |

Sources to cite, not to paraphrase: [PostgreSQL `ALTER TABLE` § Notes](https://www.postgresql.org/docs/17/sql-altertable.html) and [MySQL 8.4 § Online DDL Operations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html). For any engine not listed, the class is `UNKNOWN` until its DDL table is read — generate nothing on an unknown class.

#### The MySQL fast-path probe — run it before calling an op class-1

`ALGORITHM=INSTANT` is the *default*, not a guarantee. MySQL falls back to an in-place rebuild or a copy, and its docs name exactly when. Probe the target table:

```sql
SHOW CREATE TABLE `<table>`\G          -- look for ROW_FORMAT=COMPRESSED and any FULLTEXT KEY
SELECT NAME, TOTAL_ROW_VERSIONS
  FROM information_schema.INNODB_TABLES
 WHERE NAME = '<schema>/<table>';      -- ceiling is 64 (255 as of MySQL 9.1.0)
```

INSTANT is refused when any of these holds:
- `ROW_FORMAT=COMPRESSED`, a `FULLTEXT` index on the table, a table in the data dictionary tablespace, or a temporary table (temp tables support `ALGORITHM=COPY` only).
- The row-version ceiling is reached — `ERROR 4092 (HY000): Maximum row versions reached for table <db>/<t>. No more columns can be added or dropped instantly. Please use COPY/INPLACE.` Every instant `ADD COLUMN`/`DROP COLUMN` burns one version, and only a table rebuild or `OPTIMIZE TABLE` resets `TOTAL_ROW_VERSIONS` to 0. **An expand-contract sequence spends two versions per column** (add, then drop the old one) — a table that has churned columns for years can sit near the cap.
- The addition would exceed the max row size (`ERROR 4092`) or the 1022-column internal representation limit (`ERROR 4158`).
- The statement combines the add with another action that has no INSTANT support.
- **Before 8.0.29** INSTANT could add a column only as the *last* column of the table, and did not check the row size at all — so a pre-8.0.29 server changes both the eligibility rule and the failure mode. Read the class off the doc for the running version, not the latest one.

**MariaDB is a different engine here.** Its instant-DDL support, its version thresholds, and its `ALGORITHM` semantics diverge from MySQL's; do not carry a MySQL row across. If the project runs MariaDB, the class is `UNKNOWN` until MariaDB's own DDL documentation for that version is read.

Record the probe result in the migration header, and write `ALGORITHM=INSTANT` (or `INPLACE`) explicitly: a stated algorithm turns a silent downgrade into an error CI can see, for the same reason `CONCURRENTLY` is written explicitly on Postgres.

#### The lock nobody classifies — the definition-lock queue

**This is the failure that gets reported as "the instant ALTER took the site down".** It is class-independent: even a metadata-only change must take an exclusive lock on the table definition to swap it in.

- MySQL: "An online DDL operation may briefly require an exclusive metadata lock on the table during its execution phase, and **always requires one in the final phase** of the operation when updating the table definition… A long running or inactive transaction that holds a metadata lock on the table can cause an online DDL operation to timeout." ([Online DDL Limitations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-limitations.html))
- Postgres: most `ALTER TABLE` forms take `ACCESS EXCLUSIVE`, which conflicts with every other lock mode — plain `SELECT` included.

The mechanism that turns a wait into an outage is the **queue**: the DDL waits behind one open transaction, and every statement arriving afterwards queues behind the DDL's pending exclusive request — including reads that would have conflicted with nothing. The table is down for as long as the oldest transaction runs, not for as long as the DDL runs.

Pre-flight on the engine actually being shipped to:

```sql
-- MySQL: what holds a lock on the table, and what is the oldest open transaction?
SELECT OBJECT_TYPE, OBJECT_SCHEMA, OBJECT_NAME, LOCK_TYPE, LOCK_STATUS, OWNER_THREAD_ID
  FROM performance_schema.metadata_locks WHERE OBJECT_NAME = '<table>';
  -- the wait/lock/metadata/sql/mdl instrument is enabled by default; if it was disabled at startup
  -- this returns empty whether or not a lock is held, so confirm the instrument before trusting an empty result
SELECT trx_id, trx_started, trx_mysql_thread_id, trx_query
  FROM information_schema.INNODB_TRX ORDER BY trx_started;   -- oldest first
```

```sql
-- Postgres: blockers on the target relation
SELECT l.pid, l.mode, l.granted, a.state, now() - a.xact_start AS xact_age, a.query
  FROM pg_locks l JOIN pg_stat_activity a USING (pid)
 WHERE l.relation = '<table>'::regclass ORDER BY xact_age DESC;
```

Then bound the wait **inside the migration**, always:

- **MySQL** — `SET SESSION lock_wait_timeout = <seconds>;` before the `ALTER`. The default is `31536000` seconds, one year ([server system variables](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html)). Unbounded is the shipped default, and unbounded is the outage.
- **Postgres** — `SET lock_timeout = '<n>s';` so a failed attempt drops out of the queue instead of holding it, and retry.

A DDL migration with no lock timeout is a REQUEST-level finding whatever its op class.

### Choose the pattern

**Simple additions (new column NULL, new table)**: single migration.

**Breaking changes**: expand-contract. The step sequences — add NOT NULL with default, rename a column, change a type incompatibly, drop a column — are owned by `ai/patterns/migrations.md` (§ Expand-contract for breaking changes), which carries the app-deploy phase for each. Read it and mirror the sequence; do not re-derive it here. This command's job is the per-step SQL in sibling shape, the op class of each step, and the two engine-specific recipes below that the pattern does not carry.

#### Add unique on populated column
```
# Verify no existing duplicates
SELECT col, COUNT(*) FROM t GROUP BY col HAVING COUNT(*) > 1;

# Then create
CREATE UNIQUE INDEX CONCURRENTLY ...
```

#### Add FK on a populated table

**Postgres** — `NOT VALID` splits the lock: creation commits immediately without a scan; validation takes only `SHARE UPDATE EXCLUSIVE` and does not lock out concurrent updates.
```sql
-- Migration 1: commits immediately, no scan
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (parent_id) REFERENCES parent(id) NOT VALID;
-- Migration 2: validates pre-existing rows under a weak lock
ALTER TABLE child VALIDATE CONSTRAINT fk_name;
```

**MySQL / InnoDB has no `NOT VALID`.** `ADD FOREIGN KEY` is `ALGORITHM=COPY` — a class-3 full rebuild — unless `foreign_key_checks` is disabled, which is the only path to `INPLACE`. That trade is real and must be stated, not taken silently: with checks off the engine does **not** verify existing rows, so the constraint can be created over data that violates it. The honest sequence is:
```sql
-- 1. Prove the data is already clean (this is the check you are turning off)
SELECT c.id FROM child c LEFT JOIN parent p ON p.id = c.parent_id
 WHERE c.parent_id IS NOT NULL AND p.id IS NULL LIMIT 10;   -- must return zero rows
-- 2. Index the referencing column first if it is not already the leftmost column of an index
-- 3. Add in place. Pick LOCK from the two options below - do not default to NONE.
SET SESSION foreign_key_checks = 0;
SET SESSION lock_wait_timeout = <seconds>;
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (parent_id) REFERENCES parent(id),
  ALGORITHM=INPLACE, LOCK=<SHARED|NONE>;
SET SESSION foreign_key_checks = 1;
```
If step 1 returns rows, fix the data first — do not create an unvalidated constraint.

**Step 1 is not a barrier, and `LOCK=NONE` is what breaks it.** Between the anti-join and the ALTER's completion, `LOCK=NONE` lets writes proceed while `foreign_key_checks=0` means the engine verifies nothing — and there is no constraint yet to verify against. A row inserted in that window is never checked, before or after: MySQL has no `VALIDATE CONSTRAINT`, so the constraint begins enforcing *new* writes and silently tolerates the violating row forever. Choose explicitly, and state the choice in the migration header:

- **`LOCK=SHARED`** — reads continue, writes block for the build. No row can arrive in the window, so step 1's proof still holds when the ALTER commits. This is the option that makes the recipe sound; take it unless the write outage is unaffordable.
- **`LOCK=NONE`** — writes continue, so **re-run the step-1 anti-join immediately after the ALTER commits**. That second run covers exactly the window, because writes after the commit are constraint-checked. If it returns rows, the constraint is live over data that violates it: fix or delete those rows by hand, and record in the migration header that the constraint was never engine-validated.

If `ON DELETE CASCADE`/`SET NULL` is part of the definition, `LOCK=NONE` is refused on that table thereafter (see § Index-creation strategy), which forces the `SHARED` path anyway.

### Index-creation strategy

- **Postgres, populated tables**: `CREATE INDEX CONCURRENTLY` — must run outside a transaction. TypeORM / Prisma may need a raw migration. A failed build leaves the index `INVALID`: `DROP INDEX` and retry.
- **MySQL / MariaDB (InnoDB), populated tables**: `ALTER TABLE <t> ADD INDEX <name> (<cols>), ALGORITHM=INPLACE, LOCK=NONE;` — in place, no table rebuild, "the table remains available for read and write operations while the index is being created". Write the clause explicitly so an unsupported case errors instead of silently copying the table.
- **When `pt-online-schema-change` / `gh-ost` still earn their place** — *not* because native `ALTER` blocks (for a secondary index it does not), but for what native online DDL cannot do, per MySQL's own limitations page: there is **no mechanism to pause an online DDL operation or to throttle its I/O or CPU**, its rollback is expensive if it fails mid-way, and a long one **causes replication lag** because a replica cannot start the DDL until the source finishes it. Reach for the external tool when you need a pausable / abortable build, replica-lag-aware throttling, or the op is class-3 anyway (type change, `ADD FOREIGN KEY` with checks enabled). **Name which of those three reasons applies** — "native ALTER locks" is not one of them.
- **`LOCK=NONE` is not always legal**: "The `ALTER TABLE` clause `LOCK=NONE` is not permitted if there are `ON…CASCADE` or `ON…SET NULL` constraints on the table." A table with cascading FKs cannot take `LOCK=NONE`; plan for `LOCK=SHARED` (reads continue, writes block) or the external tool, and state which.
- **New tables**: a plain `CREATE INDEX` in the same migration is fine — nothing is concurrent yet.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

DB-SPECIFIC:
- `ai/patterns/migrations.md`, `indexing-strategy.md`. Also `ai/patterns/zero-downtime-deploys.md` (infrastructure pack, if present) — read only when it exists; never claim a read of it otherwise.
- Engine + migration tool (TypeORM / Prisma / Alembic / Django / Flyway / goose / Laravel / Rails) from `.claude/codebase-profile.md` — the canonical engine/ORM source for every Retrieve phase in this pack.
- Size up target table(s) on the project's engine — size drives the *duration* of a class-2/3 op (§ Phase 2), never the class:
  - Postgres: `SELECT count(*) FROM <t>; SELECT pg_size_pretty(pg_total_relation_size('<t>'));`
  - MySQL / MariaDB: `SELECT TABLE_ROWS, DATA_LENGTH, INDEX_LENGTH, DATA_FREE, ROW_FORMAT FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '<t>';` — `TABLE_ROWS` is an InnoDB *estimate*; take an exact `count(*)` when the value straddles a decision boundary. `DATA_LENGTH + INDEX_LENGTH` is the bytes a class-3 rebuild must rewrite, and the free disk it needs.
- Read existing migrations in the repo — match naming + style.
- The ORM entity / schema file the migration will sync with.

## Phase 4 — Generate (the migration file)

Per tool:

- **TypeORM**: `pnpm migration:generate -- src/migrations/<Name>` (auto from entity diff) then EDIT.
- **Prisma**: `prisma migrate dev --name <name>` (dev); `prisma migrate deploy` (prod).
- **Alembic**: `alembic revision --autogenerate -m "<name>"` then EDIT.
- **Django**: `python manage.py makemigrations` then EDIT if needed.
- **Laravel**: `php artisan make:migration <name>`.
- **Rails**: `rails generate migration <Name>`.
- **Raw (Flyway / goose / sqlx)**: write `up` + `down` files by hand.

Review the generated file:

- `up()` / `down()` both present.
- `down()` ACTUALLY reverses (not empty, not `DROP TABLE IF EXISTS` for a mutation).
- Concurrent-write safety matches target size (see classification above).
- Index creation uses `CONCURRENTLY` where needed.
- No mixing of schema + data in one migration (separate files).
- Single deploy concern per migration (schema OR data OR index).

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/architecture.md` schema section reflects new state.
- `ai/status.md` Recent Changes entry mentioning the migration + deploy-compatibility declaration.
- ADR if an architectural decision was made (new table introducing a new module, schema pattern change).
- `ai/dynamic/changelog.md` one-line summary.
- If multi-step expand-contract → document the deploy plan in `ai/runbooks/<slug>-deploy.md`.

## Phase 6 — Validate (rehearse + safety check)

### Rehearse (populated tables, mandatory)

Run the `migration-rehearsal` skill on the **engine lane matching the project** (it carries a Postgres lane and a MySQL lane; both produce the same report shape):
- Restore a prod-sized backup (anonymized if regulated).
- Apply the migration; measure duration + the lock profile, including any wait for the definition lock.
- Test app compatibility post-migration.
- Apply `down()` — confirm reversibility.
- Report: is forward < SLO? Is rollback clean? Which algorithm did the engine actually pick?

A rehearsal that cannot run (no harness, no prod-sized copy) yields `SKIPPED — UNVERIFIED`, never a guessed number. If the harness exists but the *engine lane* does not, that is a gap in the skill — say so explicitly rather than reporting the migration as unsafe.

### Safety checklist — evidence-bearing, maps 1:1 to the Migration-Safety Gate

**Every line below is `PASS <cited-evidence>` | `ADR <path>` | `UNVERIFIED <why>` — never a bare ✓.** A ✓ with no citation is exactly the enforcement theater this gate forbids. The Gate verdict (§ above) is computed from these lines.

- **D1 Reversible** — `down()` reverses (cite the SQL) AND rehearsal Rollback shows `baseline diff = 0` (cite report line). No rehearsal harness → `UNVERIFIED (rehearsal-absent)`.
- **D2 Online-safe** — op class named + engine-doc cited; fast-path probe result recorded for any class-1 claim; algorithm clause and lock timeout present in the SQL; lock/backfill profile REPORTED (cite rehearsal Forward/Locks: mode + hold-time + definition-lock wait); hold ≤ SLO or expand-contract splits it. Never "should be fast", and never a class inferred from a row count.
- **D3 Index coverage** — each new WHERE/ORDER BY/JOIN column names its `<index_name>`; `EXPLAIN` shows Index Scan (cite), or `UNVERIFIED (no EXPLAIN)`.
- **D4 Backfill/dual-write for rename/type-change** — expand-contract step files present on branch (cite the grep) + app dual-write phase named. Bare rename = INCOMPLETE.
- **D5 No data loss** — destructive/narrowing steps cite a backup/archive step; `down()` restores or D1-ADR'd. [self-policed — read the SQL]
- **Hygiene** — data step batched with `SKIP LOCKED`; schema ≠ data in one file; NO `synchronize: true` / auto-migrate path (grep the config — this is always a P0 escalate).

### Verify with `schema-diff` skill — entity matches DB after migration (cite the drift-report `diff = 0`).

If any D-line is unmet or `UNVERIFIED` on a populated table: the migration is **INCOMPLETE**, not COMPLETE. HALT, name the unmet dimension in the Gate verdict, do not paper over with a ✓.

## Phase 7 — Improve (feed the learning loop)

- If this migration revealed a NEW expand-contract recipe (e.g., specific to project's ORM quirks): queue to `ai/dynamic/learned-patterns.md`.
- If rehearsal surfaced a slow-down (e.g., index creation took 10x expected time on production-like data): append to `ai/dynamic/drift-log.md` for capacity planning.
- If a coordination concern arose (devops needs to know about multi-step deploy): mention in handoff + queue to `ai/dynamic/decisions-pending.md` if it warrants an ADR.
- Run `/learn-from-task` post-migration.

## Example — complex migration design

User asks: "add `status` column to `orders` (a populated table), values from a fixed list".

The single-migration form (`ADD COLUMN … NOT NULL DEFAULT 'pending'` plus a CHECK in one statement) is REJECTED — not because adding the column is expensive (on both engines that step is class-1), but because enforcing NOT NULL over existing rows and flipping the app's read path cannot both happen in one deploy. Proposed:

```
Migration 001: add-orders-status-nullable
  SET SESSION lock_wait_timeout = <seconds>;        -- MySQL; Postgres: SET lock_timeout
  ALTER TABLE orders ADD COLUMN status VARCHAR(32) NULL;
  -- class 1 (metadata-only) on PG 11+ and on InnoDB 8.0.12+ via ALGORITHM=INSTANT.
  -- MySQL: confirm the fast-path probe passed before claiming class 1.

App deploy 1:
  - On write: set status = <computed default based on row state>.
  - On read: tolerate NULL (treat as 'pending').

Migration 002: backfill-orders-status (DATA migration)
  -- Separate script, batched:
  UPDATE orders SET status = 'pending'
  WHERE id IN (
    SELECT id FROM orders WHERE status IS NULL
    FOR UPDATE SKIP LOCKED
    LIMIT 1000
  );
  -- Loop with sleep 100ms between batches, run off-peak.
  -- Monitor: rows remaining. When 0, proceed.

App deploy 2:
  - Read + write status only. Stop computing fallback.

Migration 003: enforce-orders-status-not-null
  ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
  ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'pending';
  ALTER TABLE orders ADD CONSTRAINT orders_status_check
    CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled'));

Migration 004 (optional, index): add-orders-status-index
  -- Postgres:
  CREATE INDEX CONCURRENTLY idx_orders_tenant_status_created_desc
    ON orders (tenant_id, status, created_at DESC);
  -- MySQL / InnoDB:
  --   SET SESSION lock_wait_timeout = <seconds>;
  --   ALTER TABLE orders ADD INDEX idx_orders_tenant_status_created_desc
  --     (tenant_id, status, created_at DESC), ALGORITHM=INPLACE, LOCK=NONE;
  -- Class 2 (in-place build, concurrent writes permitted).
  -- Build time: <measured-forward> from migration-rehearsal. Do not write a range here.
```

Total deploy: 4 migrations + 2 app deploys, sequenced by the app-deploy soak time the team actually uses.

Note what decided the shape: M1 is class-1 on both engines (`ADD COLUMN … NULL`), so it is cheap **whatever the row count** — the expand-contract here exists to make the NOT NULL enforcement and the app rollout safe, not because adding the column is expensive. On MySQL, run the fast-path probe first: if the table is `ROW_FORMAT=COMPRESSED`, carries a `FULLTEXT` index, or is near the row-version cap, M1 is class-3 instead and this plan changes.

## Output

```
✅ Migration generated: <name>

Phase 1 (Understand): ADD COLUMN status to <table> (<row-count> rows), fixed enum.
Phase 2 (Organize): expand-contract — <N> migrations + <M> app deploys.
Phase 3 (Retrieved): migrations.md, indexing-strategy.md, 7 universals.
Phase 4 (Generated): migrations/<NNNN>-<slug>.ts (or equivalent).
Phase 5 (Updated): ai/status.md Recent Changes, ai/architecture.md schema section.
Phase 6 (Validated): rehearsal <passed|SKIPPED — UNVERIFIED>; forward <measured-forward>,
                     rollback <measured-rollback>; schema-diff clean.
Phase 7 (Improved): /learn-from-task queued; multi-step deploy plan handed to devops.

Files:
  - migrations/<NNNN>-<slug>.ts (or equivalent)

Classification:
  Target table: <table> (<row-count> rows, <data+index bytes>)
  Engine:       <engine> <version>
  Operation:    ADD COLUMN + BACKFILL + SET NOT NULL
  Op class:     M1 class-1 (metadata-only) — <engine-doc citation>; fast-path probe: <pass|fail + reason>
                M2 class-2 (batched backfill)
                M3 class-<n> (SET NOT NULL — engine-dependent, cite it)
  Lock guard:   lock_timeout / lock_wait_timeout set to <seconds> in every DDL migration
  Approach:     expand-contract (<N> migrations + <M> app deploys)

Migration-Safety Gate (production-grade bar — each line carries evidence, no bare ✓):
  D1 Reversible      PASS  down() reverses; rehearsal Rollback baseline diff = 0
  D2 Online-safe     PASS  op class named per <engine-doc>; algorithm clause explicit;
                           lock timeout set; rehearsal Forward: max lock <mode>, held
                           <measured-hold> (≤ SLO <n>s); definition-lock wait <measured-wait>
  D3 Index coverage  PASS  <index_name> serves the new (<cols>) filter — EXPLAIN: Index Scan
  D4 Backfill/dual-write  PASS  expand-contract M1-M<n> present on branch; app dual-write phase named
  D5 No data loss    PASS  additive only; down() drops the added column; no destructive step [self-policed]
  Hygiene            PASS  backfill batched (SKIP LOCKED); schema≠data split; no synchronize:true

Next migrations planned:
  - <name-step-2>
  - <name-step-3>
  - <name-step-4>

Deploy compat: backward-compatible (app works before + after each migration).
ADR: <path if architectural decision> OR n/a.

Status: COMPLETE — production-grade (all D1-D5 evidenced). Proceed with M1 deploy when devops ready.
  ── OR, if any dimension is unmet/unverified ──
Status: INCOMPLETE (rehearsal-unverified) — D2 lock profile not measured (no restored backup).
  Unmet: D2. Op class is <n> per <engine-doc> and the fast-path probe <passed|failed: reason>;
  that bounds the risk but is not a measurement. Do not ship to prod until migration-rehearsal
  runs on a prod-sized copy of the same engine + version.
```

## Hard rules

- Reversible `down()`.
- Concurrent-write safe on populated tables.
- **Every DDL migration names its operation class and cites the engine doc that assigns it.** A row count is not a class.
- **Every DDL migration sets a lock timeout** (`lock_timeout` / `lock_wait_timeout`) and states the algorithm explicitly (`CONCURRENTLY` / `ALGORITHM=…, LOCK=…`). Defaults are unbounded waits and silent downgrades.
- `CREATE INDEX CONCURRENTLY` for Postgres populated tables (MUST be outside a transaction).
- `ALGORITHM=INPLACE, LOCK=NONE` for MySQL/InnoDB populated-table index builds — `pt-online-schema-change` / `gh-ost` when you need throttling, pausability, or the op is class-3, with the reason named.
- Expand-contract for breaking changes — never single-migration.
- Schema ≠ data migrations — separate files.
- `migration-rehearsal` mandatory for populated tables before prod.
- No `synchronize: true` / auto-migrate in prod — EVER.

## Related

### Sibling commands in database pack
- `/db-audit` — sibling command in database pack
- `/migration-review` — sibling command in database pack
- `/optimize-query` — sibling command in database pack

### Patterns
- `ai/patterns/indexing-strategy.md`
- `ai/patterns/migrations.md`
- `ai/patterns/sharding-partitioning.md`

### Rules
- `.claude/rules/database-principles.md`
