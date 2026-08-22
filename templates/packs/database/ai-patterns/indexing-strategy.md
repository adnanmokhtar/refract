---
name: indexing-strategy
description: "Pattern: Indexing Strategy — decide whether an index is worth its write cost before adding it, using the query's measured share of total execution time against the write path it slows."
kind: ai-pattern
pack: database
---

# Pattern: Indexing Strategy

> **Hard rule:** Every index ships with cited query evidence (`EXPLAIN` output, slow-log entry, or the specific WHERE/ORDER BY clause it serves) **and a completed worth-it verdict** (§ below) whose three inputs were measured, not estimated. "Just in case" indexes, duplicate prefixes of an existing index, and an index whose read saving was never compared against its write cost are forbidden. If the three inputs cannot be measured, the index is proposed as `UNJUSTIFIED — <which input is missing>`, never as a win.

**Ownership boundary:** this pattern owns *whether and which* index. The **lock and algorithm** of actually building it on a populated table belong to `migrations.md` and `/add-migration` (op class, `CONCURRENTLY` / `ALGORITHM=INPLACE, LOCK=NONE`, lock timeout). The **text-search** index and its query belong to `full-text-search.md`. Do not re-derive either here.

**When to apply**
- A plan shows a scan on a hot table and the predicate is selective.
- The slow log shows a repeated query shape a composite index would cover.
- A join column has no index and the join is measurably the dominant cost.

**When NOT to apply**
- The plan already returns nearly every row it reads — the cost is the sort, the join order, or the row width, and no index changes that.
- The predicate is already served by the leading columns of an existing index.
- The write path that maintains the index dominates the read path that uses it (§ worth-it, step 3).

**Halt conditions / mandatory cites**
- Each proposed index MUST cite the query at `<path:line>` AND the plan that motivates it.
- Composite-index column order MUST cite the WHERE/ORDER BY pattern it serves.
- A proposal with no worth-it verdict is a bug — reject it, or label it `UNJUSTIFIED`.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this query is slow".
- If the engine + version + the table's write rate aren't extracted, halt — the verdict is engine-specific and write-rate-specific.

## Is this index worth adding? — the verdict, in three measured inputs

Indexes make reads fast and writes slow. That sentence is true and useless: it names no quantity. The decision is a comparison, and every input to it is already queryable.

### Input 1 — the read side's ceiling: this query's share of the database's total work

An index can only ever win back the time this query already spends. Get that share first, because it caps everything downstream.

```sql
-- Postgres (pg_stat_statements)
SELECT queryid, calls, total_exec_time,
       100 * total_exec_time / SUM(total_exec_time) OVER () AS pct_of_total
  FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;
```
```sql
-- MySQL (performance_schema digest summary)
SELECT DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT,
       100 * SUM_TIMER_WAIT / SUM(SUM_TIMER_WAIT) OVER () AS pct_of_total
  FROM performance_schema.events_statements_summary_by_digest
 ORDER BY SUM_TIMER_WAIT DESC LIMIT 20;
```

If the target query is not a visible share of the total, **stop**. Making a 0.2%-of-total query 100× faster wins 0.2% and costs the write path forever. That is the single most common wasted index.

### Input 2 — how much of that share an index can actually recover

From the plan, compare **rows read** against **rows returned** for the step the index would replace:

```sql
EXPLAIN (ANALYZE, BUFFERS) <query>;   -- Postgres: "Rows Removed by Filter", shared read/hit
EXPLAIN ANALYZE <query>;              -- MySQL 8.0.18+: per iterator, (actual time=... rows=<N> loops=<L>)
```

**MySQL takes no format argument here.** `EXPLAIN ANALYZE` "always uses the `TREE` output format"; `FORMAT=JSON` or `FORMAT=TRADITIONAL` with it "always raises an error" — `ERROR 1235 (42000): This version of MySQL doesn't yet support 'EXPLAIN ANALYZE with JSON format'` ([MySQL 8.4 § EXPLAIN](https://dev.mysql.com/doc/refman/8.4/en/explain.html)). Read the discarded fraction off the tree: the scan iterator's actual `rows=` against the `rows=` of the filter above it. That counter is the total **across all `loops`** — divide by `loops` before comparing it to a per-execution estimate. `rows_examined_per_scan` / `rows_produced_per_join` belong to plain `EXPLAIN FORMAT=JSON` (no `ANALYZE`), which is the optimizer's *estimate* with no execution — usable to shape a guess, never to claim a measurement.

- Reads ≫ returns (a scan discarding most rows) → an index converts that scan into a descent plus the returned rows. **This is the recoverable case.**
- Reads ≈ returns → the rows are all wanted; the time is going to sort, join, or transfer. An index recovers nothing. Fix the actual dominant step.

Recoverable saving ≈ *input 1* × *the fraction of this query's time in that step*. Both numbers come from the two commands above; neither is a guess.

### Input 3 — the write cost, on the specific write path

The index is maintained on every `INSERT`, every `DELETE`, and every `UPDATE` that touches one of its columns. Three multipliers, all measurable:

- **Write rate on this table** — Postgres `pg_stat_user_tables` (`n_tup_ins + n_tup_upd + n_tup_del` over a known window); MySQL `performance_schema.table_io_waits_summary_by_table` (`COUNT_INSERT + COUNT_UPDATE + COUNT_DELETE`).
- **Whether the update path touches the indexed column.** This is where the cost is usually underestimated on Postgres: an update qualifies for a **heap-only tuple (HOT)** — no new index entries at all — only when "the update does not modify any columns referenced by the table's indexes" and the page has free space ([PostgreSQL § Heap-Only Tuples](https://www.postgresql.org/docs/17/storage-hot.html)). Indexing a column that the hot update path writes therefore does not just add one index's maintenance: it disqualifies HOT, so **every** index on the table takes a new entry on **every** such update. Check the column against the update statements before, not after.
- **Whether the index fits in cache.** An index only accelerates reads while its useful pages stay in `shared_buffers` / the InnoDB buffer pool. An index larger than the memory available to it turns one sequential scan into many random reads. Measure the size it will reach (`pg_relation_size` on a built copy, or `information_schema.TABLES.INDEX_LENGTH` deltas) against the pool, and count it against the *other* indexes competing for the same pool.

### The verdict

State it as a comparison, with all three numbers, or state which one is missing:

```
Index: <name> on <table>(<cols>)
  Read share (input 1):   <pct>% of total exec time, <calls> calls/<window>
  Recoverable (input 2):  rows read <R> → rows returned <N>; dominant step <step>
  Write cost (input 3):   <writes>/<window> on <table>; touches indexed column: <yes/no>;
                          HOT impact (PG): <disqualifies / no change>; size vs pool: <bytes> / <pool>
  Verdict: WORTH IT — recovers <pct>% of total for <write-cost> maintenance
        |  NOT WORTH IT — <which side loses>
        |  UNJUSTIFIED — <input> not measurable here; propose, do not claim a gain
```

There is no universal threshold, because the crossing point moves with the read/write ratio of the specific table. What is universal is that a proposal with a blank in that block has not been decided, only asserted.

## Which index shape — the choices that change the answer

Shape matters only after the verdict says yes. Syntax lives in `references/<engine>.md`; what follows is what each shape buys and what it costs.

| Shape | Wins when | Costs |
|---|---|---|
| **Single-column b-tree** | one selective predicate, or a join column | one index's maintenance |
| **Composite** | several predicates always appear together, or a filter + sort pair | wider entries; only usable left-to-right (below) |
| **Covering** (`INCLUDE` on PG 11+, extra trailing columns elsewhere) | the query's whole column list can be served from the index — no heap/row fetch | larger index, so more of the pool consumed; more write amplification per entry |
| **Partial / filtered** (`WHERE` predicate on the index) | the hot query only ever touches a slice (`deleted_at IS NULL`, `status = 'pending'`) | only usable when the planner can prove the query's predicate implies the index's |
| **Expression / functional** | the predicate is `f(col)` (`LOWER(email)`, a date truncation) and cannot be rewritten | the expression is evaluated on every write |
| **Engine-specific** (GIN / GiST / BRIN / hash / spatial) | the data type or access pattern the b-tree cannot serve — containment, ranges, huge append-only clustering | see `references/<engine>.md`; availability differs by engine |

**Composite column order is a rule, not a preference.** Equality predicates first, then the range or the `ORDER BY` column. The index is usable only from its leftmost column rightwards, so `(tenant_id, status, created_at DESC)` serves `WHERE tenant_id = ?`, `WHERE tenant_id = ? AND status = ?`, and that pair with `ORDER BY created_at DESC` — but **not** `WHERE status = ?` alone. This is why a new two-column index is redundant when an existing three-column index starts with the same two: check before proposing (`/optimize-query` halts on exactly this).

## Do not add an index when

- **The table is small enough to live in cache.** The determinant is not a row count — it is whether the whole table fits in a handful of pages that are already resident, versus the planner's random-access cost setting. A wide 800-row table can be worth indexing; a narrow 5,000-row lookup table read entirely on every request is not. Compare the table's byte size to the pool, and check whether the planner already prefers a scan.
- **The column has few distinct values relative to the rows** and there is no partial predicate. What decides this is selectivity — distinct values ÷ rows — not the column's type. Measure it on the column you are proposing to index, which by definition has no index yet:
  - **Postgres** — `SELECT n_distinct, most_common_freqs FROM pg_stats WHERE tablename = '<t>' AND attname = '<col>';` Works on unindexed columns; `ANALYZE` first if the stats are stale.
  - **MySQL** — there is no catalogue answer. `information_schema.STATISTICS` "provides information about table indexes", one row per column *that is part of an index*, and `CARDINALITY` is "an estimate of the number of unique values in **the index**" ([MySQL 8.4 § STATISTICS](https://dev.mysql.com/doc/refman/8.4/en/information-schema-statistics-table.html)) — so it returns nothing for the column in question. Count it directly: `SELECT COUNT(DISTINCT <col>) / COUNT(*) AS selectivity FROM <t>;`, over a bounded PK range if a full scan is too expensive to run in hours.

  A boolean flag that is `true` for 0.1% of rows is worth a partial index; one that is true for half the table is not worth any index.
- **The proposal is insurance.** No plan, no share of total exec time, no index.

## Detect what is already wrong

```sql
-- Postgres: tables taking sequential scans despite having indexes
SELECT schemaname, relname, seq_scan, seq_tup_read, idx_scan
  FROM pg_stat_user_tables WHERE seq_scan > idx_scan AND n_live_tup > 100000
 ORDER BY seq_tup_read DESC;

-- Postgres: indexes nothing reads
SELECT schemaname, relname, indexrelname, idx_scan, pg_relation_size(indexrelid) AS bytes
  FROM pg_stat_user_indexes WHERE idx_scan = 0 AND schemaname NOT IN ('pg_catalog','pg_toast')
 ORDER BY bytes DESC;
```
```sql
-- MySQL: the sys schema answers all three directly
SELECT * FROM sys.schema_unused_indexes;                 -- never-read indexes
SELECT * FROM sys.schema_redundant_indexes;              -- an index that is a prefix of another
SELECT * FROM sys.schema_tables_with_full_table_scans;   -- scan-dominated tables
```

An unused index is a **candidate** for dropping, never an instruction: confirm across a full business cycle (month-end, quarterly jobs, the annual report), and exclude unique constraints and the indexes that enforce foreign keys.

## Foreign keys — the engines differ, and the advice inverts

- **Postgres** does *not* create an index on the referencing column. Add it explicitly: without it, every delete or key-update on the parent scans the child table, and the FK check takes a row lock on it.
- **MySQL / InnoDB** does. "In the referencing table, there must be an index where the foreign key columns are listed as the first columns in the same order. **Such an index is created on the referencing table automatically if it does not exist.** This index might be silently dropped later if you create another index that can be used to enforce the foreign key constraint." ([MySQL § FOREIGN KEY Constraints](https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html))

So on MySQL the FK finding inverts — but *not* into a standing redundancy to go hunting for. Both branches of that second sentence cut against the reflex:

- The later composite **leads with** the FK column → it can enforce the constraint, so InnoDB "might silently" have dropped the single-column index already. Nothing to find; the case self-resolves.
- The later composite does **not** lead with the FK column → it cannot enforce the constraint, so the single-column index is **required**. Calling it redundant and dropping it is a schema break, not a saving.

Dropping it is safe only in the first branch — where the composite can already enforce the constraint and the engine simply has not dropped the index yet ("might", not "will"). So establish that the composite leads with the FK columns *before* proposing any drop; never infer it from a `sys.schema_redundant_indexes` row alone, which reports prefix overlap and does not tell you which index a constraint depends on. The InnoDB action is therefore: read `SHOW INDEX` before reporting "missing FK index" (usually a false positive), and check the FK list before dropping — per § Detect what is already wrong, which already excludes constraint-backing indexes from the unused-index sweep.

## Building it on a populated table

Owned by `migrations.md` / `/add-migration` — read the op class and lock guidance there. The one-line summary, so nobody reaches for the wrong tool: on **Postgres**, `CREATE INDEX CONCURRENTLY` (outside a transaction). On **MySQL/InnoDB**, a secondary index build is In Place, does not rebuild the table, and **permits concurrent DML** — "the table remains available for read and write operations while the index is being created" ([MySQL § Online DDL Operations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html)); write `ALGORITHM=INPLACE, LOCK=NONE` explicitly. `pt-online-schema-change` / `gh-ost` are for throttling, pausability, and replica-lag control — not because the native build blocks.

## Forbidden

- Adding an index with no worth-it verdict, or with a verdict whose inputs were estimated.
- Proposing an index whose leftmost columns duplicate an existing index's.
- Indexing a column the hot update path writes without accounting for the HOT loss (Postgres).
- Repeating "MySQL index builds block" — they do not, and the advice sends teams to a full-table-copy tool for an in-place operation.
- Dropping an index on `idx_scan = 0` from a short window, or dropping one that backs a unique constraint or a foreign key.
- Treating a row-count threshold as the reason for a decision. Name the determinant.

## Related

- `transaction-isolation.md` — locks ride on index access paths; a missing index turns a row lock into a range/table lock (and InnoDB gap locks span the scanned range), widening the deadlock surface.
- `full-text-search.md` — the text-search index (`tsvector`+GIN / `FULLTEXT`) and its search query live there; a `LIKE '%x%'` that belongs in FTS is theirs, not a b-tree gap here.
- `migrations.md` — how to build the index this pattern approved, without taking the table down.
