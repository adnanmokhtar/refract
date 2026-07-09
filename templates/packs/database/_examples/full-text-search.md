---
name: full-text-search
kind: example
pack: database
---

# Pattern: Full-Text Search

Text search over a large table uses the engine's real full-text primitive — Postgres `tsvector` + GIN, MySQL `FULLTEXT`, or an external engine — kept in sync by a trigger or generated column, and returns results **ranked**. `LIKE '%term%'` / `ILIKE '%term%'` that forces a full scan, an FTS column with no maintenance (stale index), and an FTS query with no ranking are all forbidden. `indexing-strategy` owns the general index toolbox; THIS pattern owns the text-search index and the search query together. Extract the **engine + version** first — FTS primitives differ.

## Adapt to the codebase

| Engine | Search index | Maintenance | Ranking |
|---|---|---|---|
| **Postgres** | `tsvector` + `GIN`; `pg_trgm` for fuzzy | `GENERATED … STORED` (12+) or trigger | `ts_rank` / `ts_rank_cd` |
| **MySQL / InnoDB** | `FULLTEXT` index (5.6+) | self-maintaining | `MATCH … AGAINST` score (natural mode) |
| **SQLite** | FTS5 virtual table | triggers to sync content table | `bm25()` |
| **MongoDB** | text index / Atlas Search | engine-maintained | `$meta:"textScore"` |
| **External** | Elasticsearch / OpenSearch / Meilisearch | ingestion pipeline (CDC/outbox) | BM25 / custom relevance |

## Detectors (cite-or-halt)

1. **`LIKE '%term%'` / `ILIKE '%term%'` full-scan search.** BAD: `WHERE name LIKE '%'||:q||'%'` on a large table — un-indexable, unranked, seq scan. GOOD: `tsvector @@ tsquery` + GIN, or `pg_trgm` index for genuine substring.
2. **FTS query with no ranking.** BAD: `WHERE search @@ q` / `MATCH … AGAINST` with `ORDER BY id`/none. GOOD: `ORDER BY ts_rank(search, q) DESC` / `AGAINST … ` score.
3. **Unmaintained tsvector (stale index).** BAD: a `tsvector`/search column with no `GENERATED` clause and no `INSERT/UPDATE` trigger — populated once, rots. GOOD: `GENERATED ALWAYS AS … STORED` or a `tsvector_update_trigger`.
4. **FTS index missing (seq scan on the search column).** BAD: `to_tsvector(...)` / `MATCH` with no matching `GIN`/`FULLTEXT` index. GOOD: `CREATE INDEX … USING GIN` / `ADD FULLTEXT`; confirm via `EXPLAIN`.

## Related

- `indexing-strategy.md` — the general index toolbox; a GIN-on-jsonb or covering index is theirs, the text-search index + query is here.
- `sharding-partitioning.md` — a decoupled search store is often the cross-shard search answer.
