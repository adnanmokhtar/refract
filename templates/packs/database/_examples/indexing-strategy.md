---
name: indexing-strategy
kind: example
pack: database
---

# Pattern: Indexing Strategy

> **Hard rule:** Every index ships with cited query evidence (`EXPLAIN` output, slow-log entry, or the specific WHERE/ORDER BY clause it serves) **and a completed worth-it verdict** (§ below) whose three inputs were measured, not estimated. "Just in case" indexes, duplicate prefixes of an existing index, and an index whose read saving was never compared against its write cost are forbidden. If the three inputs cannot be measured, the index is proposed as `UNJUSTIFIED — <which input is missing>`, never as a win.

**Ownership boundary:** this pattern owns *whether and which* index. The **lock and algorithm** of actually building it on a populated table belong to `migrations.md` and `/add-migration`. The **text-search** index and its query belong to `full-text-search.md`.

**Halt conditions / mandatory cites**
- Each proposed index MUST cite the query at `<path:line>` AND the plan that motivates it.
- Composite-index column order MUST cite the WHERE/ORDER BY pattern it serves.
- A proposal with no worth-it verdict is a bug — reject it, or label it `UNJUSTIFIED`.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this query is slow".
- If the engine + version + the table's write rate aren't extracted, halt.

## Is this index worth adding? — the verdict, in three measured inputs

"Indexes make reads fast and writes slow" is true and useless: it names no quantity. The decision is a comparison, and every input is queryable.

**Input 1 — this query's share of the database's total work.** An index can only win back time the query already spends, so this caps everything downstream.

```sql
-- Postgres
SELECT queryid, calls, total_exec_time,
       100 * total_exec_time / SUM(total_exec_time) OVER () AS pct_of_total
  FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;
-- MySQL
SELECT DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT,
       100 * SUM_TIMER_WAIT / SUM(SUM_TIMER_WAIT) OVER () AS pct_of_total
  FROM performance_schema.events_statements_summary_by_digest
 ORDER BY SUM_TIMER_WAIT DESC LIMIT 20;
```

If the query is not a visible share of the total, **stop** — making a negligible query far faster wins nothing and costs the write path forever. That is the most common wasted index.

**Input 2 — how much of that share is recoverable.** Compare **rows read** against **rows returned** for the step the index would replace: Postgres `EXPLAIN (ANALYZE, BUFFERS)` ("Rows Removed by Filter"); MySQL `EXPLAIN ANALYZE <query>` — no format argument, it "always uses the `TREE` output format" and `FORMAT=JSON` with it raises `ERROR 1235` ([MySQL 8.4 § EXPLAIN](https://dev.mysql.com/doc/refman/8.4/en/explain.html)). Read the scan iterator's actual `rows=` against the `rows=` of the filter above it; that counter totals **all `loops`**, so divide before comparing. (`rows_examined_per_scan` / `rows_produced_per_join` are plain `EXPLAIN FORMAT=JSON` — estimates, not measurements.) Reads ≫ returns is the recoverable case. Reads ≈ returns means the time is in the sort, the join, or the row width — an index recovers nothing there.

**Input 3 — the write cost on this specific write path.** The index is maintained on every `INSERT`, every `DELETE`, and every `UPDATE` touching one of its columns. Three multipliers:
- **Write rate** — Postgres `pg_stat_user_tables` (`n_tup_ins + n_tup_upd + n_tup_del`); MySQL `performance_schema.table_io_waits_summary_by_table`.
- **Does the update path touch the indexed column?** On Postgres an update avoids new index entries only as a **heap-only tuple (HOT)**, which requires that it "does not modify any columns referenced by the table's indexes" plus free space on the page ([PG § Heap-Only Tuples](https://www.postgresql.org/docs/17/storage-hot.html)). Indexing a column the hot update path writes therefore disqualifies HOT, so **every** index on the table takes a new entry on **every** such update — far more than this one index's own cost.
- **Will it fit in cache?** An index larger than the memory available to it turns one sequential scan into many random reads. Weigh its size against `shared_buffers` / the InnoDB buffer pool, alongside the indexes already competing for it.

**The verdict** — all three numbers, or name the missing one:

```
Index: <name> on <table>(<cols>)
  Read share:   <pct>% of total exec time, <calls> calls/<window>
  Recoverable:  rows read <R> → rows returned <N>; dominant step <step>
  Write cost:   <writes>/<window>; touches indexed column: <yes/no>;
                HOT impact (PG): <disqualifies / no change>; size vs pool: <bytes> / <pool>
  Verdict: WORTH IT | NOT WORTH IT — <which side loses> | UNJUSTIFIED — <missing input>
```

There is no universal threshold — the crossing point moves with the table's read/write ratio. What is universal: a proposal with a blank in that block has been asserted, not decided.

## Which index shape

| Shape | Wins when | Costs |
|---|---|---|
| **Single-column b-tree** | one selective predicate, or a join column | one index's maintenance |
| **Composite** | several predicates always appear together, or filter + sort | wider entries; usable left-to-right only |
| **Covering** | the query's whole column list is served from the index | larger index, more pool consumed, more write amplification |
| **Partial / filtered** | the hot query only touches a slice (`deleted_at IS NULL`) | usable only when the planner can prove implication |
| **Expression / functional** | the predicate is `f(col)` and cannot be rewritten | the expression is evaluated on every write |
| **Engine-specific** (GIN / GiST / BRIN / hash / spatial) | data types or access patterns b-trees cannot serve | see `references/<engine>.md` |

**Composite order is a rule.** Equality predicates first, then the range or `ORDER BY` column. The index is usable only from its leftmost column rightwards: `(tenant_id, status, created_at DESC)` serves `WHERE tenant_id = ?` and that plus `status`, but **not** `WHERE status = ?` alone. This is why a two-column index is redundant when an existing three-column index starts with the same two — check before proposing.

## Do not add an index when

- **The table fits in cache.** The determinant is byte size against the pool and the planner's random-access cost, not a row count. A wide 800-row table can be worth indexing; a narrow lookup table read whole on every request is not.
- **Selectivity is too low** and there is no partial predicate — distinct values ÷ rows, not the column's type. Measure it on the not-yet-indexed column: Postgres `pg_stats.n_distinct` (works on unindexed columns). MySQL has no catalogue answer — `information_schema.STATISTICS` covers *indexed* columns only, and `CARDINALITY` is "an estimate of the number of unique values in the index" ([MySQL 8.4](https://dev.mysql.com/doc/refman/8.4/en/information-schema-statistics-table.html)), so it returns nothing here; run `SELECT COUNT(DISTINCT <col>) / COUNT(*) FROM <t>;` instead. A flag true for 0.1% of rows deserves a partial index; one true for half the table deserves none.
- **The proposal is insurance.** No plan, no share of total exec time, no index.

## Detect what is already wrong

```sql
-- Postgres
SELECT relname, seq_scan, seq_tup_read, idx_scan FROM pg_stat_user_tables
 WHERE seq_scan > idx_scan AND n_live_tup > 100000 ORDER BY seq_tup_read DESC;
SELECT relname, indexrelname, idx_scan, pg_relation_size(indexrelid) AS bytes
  FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY bytes DESC;
-- MySQL
SELECT * FROM sys.schema_unused_indexes;
SELECT * FROM sys.schema_redundant_indexes;
SELECT * FROM sys.schema_tables_with_full_table_scans;
```

An unused index is a **candidate**, never an instruction: confirm across a full business cycle, and exclude unique constraints and the indexes enforcing foreign keys.

## Foreign keys — the engines differ, and the advice inverts

- **Postgres** does not index the referencing column for you. Add it, or every parent delete/key-update scans the child.
- **MySQL / InnoDB** does: "Such an index is created on the referencing table automatically if it does not exist. This index might be silently dropped later if you create another index that can be used to enforce the foreign key constraint." ([MySQL 8.4](https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html))

So on MySQL the finding inverts, but not into a redundancy to hunt. If a later composite **leads with** the FK column it can enforce the constraint and InnoDB may already have dropped the single-column index — nothing to find. If it does **not** lead with the FK column, the single-column index is **required**, and dropping it is a schema break. The InnoDB action is therefore: read `SHOW INDEX` before reporting "missing FK index" (usually a false positive), and check the FK list before dropping anything `sys.schema_redundant_indexes` names.

## Building it on a populated table

Owned by `migrations.md` / `/add-migration`. One line so nobody reaches for the wrong tool: Postgres uses `CREATE INDEX CONCURRENTLY` (outside a transaction); MySQL/InnoDB builds a secondary index In Place with **concurrent DML permitted** — "the table remains available for read and write operations while the index is being created" ([MySQL § Online DDL Operations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html)) — so write `ALGORITHM=INPLACE, LOCK=NONE` explicitly. `pt-online-schema-change` / `gh-ost` are for throttling, pausability, and replica-lag control, not because the native build blocks.

## Forbidden

- Adding an index with no worth-it verdict, or one whose inputs were estimated.
- Proposing an index whose leftmost columns duplicate an existing index's.
- Indexing a column the hot update path writes without accounting for the HOT loss (Postgres).
- Repeating "MySQL index builds block" — they do not.
- Dropping an index on zero scans from a short window, or one backing a unique constraint or foreign key.
- Treating a row-count threshold as a reason. Name the determinant.

## Related

- `transaction-isolation.md` — locks ride on index access paths; a missing index widens a row lock into a range lock (InnoDB gap locks span the scanned range) and with it the deadlock surface.
- `full-text-search.md` — owns the text-search index and query; a `LIKE '%x%'` belongs there, not here.
- `migrations.md` — how to build the index this pattern approved without taking the table down.
