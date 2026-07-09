---
name: full-text-search
description: "Pattern: Full-Text Search — the engine's real text-search primitive (tsvector+GIN / MySQL FULLTEXT / external), maintained by trigger or generated column, with ranking — never LIKE '%term%' on a large table."
kind: ai-pattern
pack: database
---

# Pattern: Full-Text Search

> **Hard rule:** Text search over a large table uses the engine's real full-text primitive — Postgres `tsvector` + GIN, MySQL `FULLTEXT`, or an external engine (Elasticsearch/OpenSearch/Meilisearch) — kept in sync by a trigger or generated column, and returns results **ranked** (`ts_rank`/`MATCH … AGAINST` score). A `LIKE '%term%'` / `ILIKE '%term%'` search that forces a full scan, an FTS column with no maintenance (stale index), and an FTS query with no ranking are all forbidden. Cite the engine + version, the table row-count, and the offending `<path:line>` verbatim — or halt.

**Ownership boundary:** `indexing-strategy` owns the general index toolbox — b-tree, partial, covering, expression, GIN-on-jsonb. THIS pattern owns the **text-search index and the search query together**: the `tsvector`/`FULLTEXT` column, its maintenance mechanism, the GIN/GiST choice *for text search*, ranking, phrase/prefix/fuzzy matching, and the graduate-to-external threshold. A finding about a b-tree on `created_at` is `indexing-strategy`; a finding about `LIKE '%x%'` where a `tsvector` belongs, or an unranked search, is here. When the index alone is the whole story (jsonb GIN, a covering index) defer to `indexing-strategy`.

**When to apply**
- A search box queries a text column with `LIKE '%term%'` / `ILIKE` and the table is non-trivial (seq scan, growing latency).
- Users expect relevance ordering, phrase matching, prefix ("as-you-type"), or typo tolerance — not substring containment.
- A search touches multiple text fields (title + body + tags) that must be weighted and ranked together.

**When NOT to apply**
- Exact-match or prefix-only lookup on a short, indexed column (`WHERE sku = ?`, `WHERE email LIKE 'foo%'`) — a b-tree / expression index serves it; that's `indexing-strategy`.
- Tiny tables (< a few thousand rows) where a seq scan is genuinely cheap and relevance doesn't matter.
- Structured filtering (status, category, range) — that is not text search.

**Halt conditions / mandatory cites**
- The DB engine + version MUST be extracted — FTS primitives differ (Postgres `tsvector`/GIN, MySQL InnoDB `FULLTEXT` ≥ 5.6, SQLite FTS5). Without it, halt; advice is engine-specific.
- Every finding MUST cite the search query at `<path:line>` AND the column's maintenance mechanism (trigger / `GENERATED` / none) at `<path:line>`.
- A claim of "we use FTS" MUST cite the ranking expression — an FTS query returning rows in arbitrary/`id` order is a bug, not a search.
- A proposal to reach for Elasticsearch MUST cite which requirement (multi-field relevance, faceting, typo-tolerance at scale) the in-DB engine cannot meet — "it'll be faster" without a cited gap is over-engineering; reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `should rank fine` is forbidden when claiming search is relevance-ranked.

Substring `LIKE '%term%'` cannot use a b-tree and cannot rank — it scans every row and returns them in storage order. Full-text search is a *different primitive*: a tokenized, normalized, ranked index. Reach for it deliberately, keep it maintained, and know the ceiling where an external engine earns its operational cost.

## The tsvector + GIN index (Postgres)

A `tsvector` is the parsed, lexeme-normalized (stemmed, stop-worded) form of the text. Store it, index it with GIN, query it with a `tsquery`.

```sql
ALTER TABLE articles ADD COLUMN search tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(body,'')),  'B')
  ) STORED;                                   -- PG 12+: engine maintains it, no trigger needed
CREATE INDEX idx_articles_search ON articles USING GIN (search);
```

`setweight(..., 'A'|'B'|'C'|'D')` lets `ts_rank` score a title match above a body match. The `STORED GENERATED` column is the modern maintenance mechanism — the engine recomputes on every write, so it can never go stale.

## Keeping the vector in sync (the maintenance rule)

An FTS column that isn't recomputed on write silently rots — new rows are unsearchable, edited rows return stale hits. Pick ONE mechanism and apply it:

- **`GENERATED ALWAYS AS … STORED`** (PG 12+) — preferred; declarative, can't drift.
- **Trigger** (pre-12 or multi-language) — `tsvector_update_trigger` or a custom `BEFORE INSERT OR UPDATE` trigger writing the column.
- **MySQL `FULLTEXT`** maintains itself — the index *is* the maintenance; no separate column needed.

A `tsvector` column populated once by a backfill and never re-derived is the single most common FTS bug. If there's no trigger and no `GENERATED`, it's stale by definition — flag it.

## GIN vs GiST

- **GIN** — default for FTS. Larger index, slower to build/update, **much** faster lookups. Choose it for read-heavy search (almost always).
- **GiST** — smaller, lossy, faster updates, slower/less-precise lookups. Only for very write-heavy or when combined with other GiST operators. Don't reach for it without a cited write-vs-read tradeoff.

## Ranking, phrase, and prefix search

Ranking is not optional — an unranked FTS returns matches in undefined order:

```sql
SELECT id, ts_rank(search, q) AS rank
FROM articles, websearch_to_tsquery('english', :term) q
WHERE search @@ q
ORDER BY rank DESC
LIMIT 20;
```

- **Phrase search** — `phraseto_tsquery`/`<->` matches adjacent lexemes in order ("quick fox", not "fox quick").
- **Prefix / as-you-type** — `to_tsquery('quic:*')` matches `quick`, `quickly`. `websearch_to_tsquery` accepts Google-style quoted phrases and `-exclusion`.
- **`ts_rank_cd`** weights by lexeme proximity (cover density) — better for long documents.

## Fuzzy / typo tolerance with pg_trgm

`tsvector` matches *lexemes*, not misspellings. For typo tolerance and fuzzy substring inside Postgres, add trigram matching:

```sql
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_products_name_trgm ON products USING GIN (name gin_trgm_ops);
SELECT * FROM products WHERE name % :term ORDER BY similarity(name, :term) DESC;  -- % = trigram-similar
```

`pg_trgm` *does* accelerate `LIKE '%term%'`/`ILIKE` via the trigram index — so a genuine substring search on a large table has a real index answer instead of a seq scan. Use it for autocomplete, fuzzy name matching, and typo-forgiving lookups; use `tsvector` for document relevance.

## MySQL FULLTEXT

InnoDB `FULLTEXT` (5.6+) is the MySQL analog — the index maintains itself:

```sql
ALTER TABLE articles ADD FULLTEXT INDEX ft_articles (title, body);
SELECT id, MATCH(title, body) AGAINST(:term IN NATURAL LANGUAGE MODE) AS score
FROM articles
WHERE MATCH(title, body) AGAINST(:term IN NATURAL LANGUAGE MODE)
ORDER BY score DESC;
```

- **Natural-language mode** — relevance-ranked, ignores words in > 50% of rows, honors a minimum token length (`innodb_ft_min_token_size`, default 3 — short terms silently return nothing).
- **Boolean mode** — `+required -excluded "phrase" prefix*`, but **no relevance ranking** by default.

Limits to know: per-word stopword + min-token behavior, no built-in stemming (English is basic, no config for many languages), and weaker relevance tuning than Postgres/external engines. It's the right tool for simple in-DB search on MySQL; it is *not* a search platform.

## When to graduate to an external engine

Postgres FTS / MySQL FULLTEXT covers a large fraction of real apps. Graduate to **Elasticsearch / OpenSearch / Meilisearch / Typesense** only when a *cited* requirement exceeds the in-DB engine:

- **Multi-field relevance tuning** — per-field boosts, custom analyzers, synonyms, learning-to-rank the DB can't express.
- **Faceting / aggregations at scale** — counts-per-category alongside results across millions of docs.
- **Typo-tolerance + instant search at scale** — sub-50ms as-you-type with ranked fuzzy matching (Meilisearch/Typesense excel here).
- **Search decoupled from the write DB** — search load must not compete with OLTP.

The cost is real: a second datastore, an ingestion/sync pipeline (the new staleness surface), and reindex operations. Don't pay it to avoid writing a `tsvector`. Equally: don't force `LIKE '%x%'` across 50M rows because "we don't have Elasticsearch" — that's the under-powered failure. Match the tool to the cited requirement.

## Adapt to the codebase

Extract the engine, then map to its text-search primitive and maintenance.

| Engine | Search index | Maintenance | Ranking |
|---|---|---|---|
| **Postgres** | `tsvector` + `GIN`; `pg_trgm` for fuzzy | `GENERATED … STORED` (12+) or trigger | `ts_rank` / `ts_rank_cd` |
| **MySQL / InnoDB** | `FULLTEXT` index (5.6+) | self-maintaining | `MATCH … AGAINST` score (natural mode) |
| **SQLite** | FTS5 virtual table | triggers to sync content table | `bm25()` |
| **MongoDB** | text index / Atlas Search | engine-maintained | `$meta:"textScore"` / Lucene relevance |
| **External** | Elasticsearch / OpenSearch / Meilisearch / Typesense | ingestion pipeline (CDC/outbox) | BM25 / custom relevance |

## Detectors (cite-or-halt)

Each finding cites `<file:line>` for the search query + the matched pattern + the fix.

1. **`LIKE '%term%'` / `ILIKE '%term%'` full-scan search.** BAD: `WHERE name LIKE '%'||:q||'%'` on a large table — un-indexable, unranked, seq scan. GOOD: `tsvector @@ tsquery` + GIN, or `pg_trgm` index for genuine substring. Grep: `LIKE\s+['"]%|ILIKE\s+['"]%|like\('%` in query/repo code near a search endpoint.
2. **FTS query with no ranking.** BAD: `WHERE search @@ q` / `MATCH … AGAINST` with `ORDER BY id`/none — matches unranked. GOOD: `ORDER BY ts_rank(search, q) DESC` / `AGAINST … ` score. Grep: `@@|MATCH.*AGAINST` with no `ts_rank|rank|score|@meta` in the same statement.
3. **Unmaintained tsvector (stale index).** BAD: a `tsvector`/search column with no `GENERATED` clause and no `INSERT/UPDATE` trigger — populated once, rots. GOOD: `GENERATED ALWAYS AS … STORED` or a `tsvector_update_trigger`. Grep: `tsvector` column defs cross-checked against `CREATE TRIGGER|GENERATED ALWAYS`.
4. **FTS index missing (seq scan on the search column).** BAD: `to_tsvector(...)` / `MATCH` in a query with no matching `GIN`/`FULLTEXT` index — every search scans. GOOD: `CREATE INDEX … USING GIN` / `ADD FULLTEXT`. Grep: `to_tsvector|@@` without a `USING GIN` index on that column; confirm via `EXPLAIN`.
5. **Reaching for Elasticsearch when in-DB FTS suffices (over-engineering).** BAD: a new external search cluster proposed for single-table, single-language, no-facet search. GOOD: `tsvector` + GIN in the existing DB. Flag for ADR — the external engine needs a cited requirement (faceting / multi-field relevance / typo-at-scale) it can't meet in-DB.
6. **Under-powered `LIKE`/basic search where scale demands FTS-or-external.** BAD: `LIKE '%x%'` or naive `FULLTEXT` across tens of millions of rows with typo-tolerance + facet requirements. GOOD: graduate to Meilisearch/Elasticsearch with a cited requirement. Flag for ADR — the mirror of #5.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete `tsvector`+GIN / `GENERATED STORED` / `pg_trgm` / `FULLTEXT` / `ts_rank`-ordering patch.
- `report-flagged` — the fix is a design call (graduate to / stay off an external engine; GiST-vs-GIN under a measured write ratio; which fields to weight) → surface for ADR.
- `dismiss` — carve-out applies (exact/prefix lookup on an indexed short column; genuinely tiny table; structured filter, not text search) → documented with the reason.

## Related

- `indexing-strategy.md` — the general index toolbox and the ownership boundary above; a GIN-on-jsonb or covering index is theirs, the text-search index + query is here.
- `sharding-partitioning.md` — FTS across shards is scatter-gather; a decoupled search store (Elasticsearch) is often the cross-shard search answer.
- `backend` `caching-strategy` — cache hot/repeated search result-sets; ranked FTS results are cacheable by normalized query + filters.
- `@schema-reviewer` / `@database-optimizer` — review agents that consume these detectors.
