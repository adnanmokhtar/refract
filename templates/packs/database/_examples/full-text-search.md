---
name: full-text-search
kind: example
pack: database
---

# Pattern: Full-Text Search

> **Hard rule:** Text search over a large table uses the engine's real full-text primitive — Postgres `tsvector` + GIN, MySQL `FULLTEXT`, or an external engine (Elasticsearch/OpenSearch/Meilisearch) — kept in sync by a trigger or generated column, and returns results **ranked** (`ts_rank`/`MATCH … AGAINST` score). A `LIKE '%term%'` / `ILIKE '%term%'` search that forces a full scan, an FTS column with no maintenance (stale index), and an FTS query with no ranking are all forbidden. Cite the engine + version, the table row-count, and the offending `<path:line>` verbatim — or halt.

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

The method lives here. `LIKE '%term%'` search on a large table → `query-shape-scan` §4. `to_tsvector` / `MATCH` with no GIN or FULLTEXT index → `index-coverage-scan` §6. FTS with no ranking and a `tsvector` with no `GENERATED` clause or trigger have no detector: read them at review time.

## Related

- `indexing-strategy.md` — the general index toolbox; a GIN-on-jsonb or covering index is theirs, the text-search index + query is here.
- `sharding-partitioning.md` — a decoupled search store is often the cross-shard search answer.
