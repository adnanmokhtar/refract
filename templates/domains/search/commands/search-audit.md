---
description: Run realistic queries against the search engine; verify tenant scoping, relevance ordering, no cross-tenant leak, p95 latency.
---

# /search-audit

Purpose: in 60 seconds, prove search isn't leaking tenants, returns sensible relevance, and stays under SLA.

## Premise

Find real issues, no hand-waves. Every reported hit cites the actual document id + `tenant_id` returned by the engine. Cross-tenant leak detection is exact — `tenant_id != A` in any hit is a BLOCKER, regardless of how the query is shaped. Latency numbers come from the engine's `processingTimeMs` / `took` / `EXPLAIN ANALYZE`, not wall-clock guesses.

## Mechanical halt

Cite-or-halt: every query row must carry the engine's response (hit count, top doc ids, leak count). On any cross-tenant hit, halt the run and print the offending `doc.id` + `tenant_id` + filter clause used — do not continue to remaining queries. No `PASS` without a recorded `Cross-tenant leak: 0 / N` line.

## What it does

1. Loads `test/search-audit/golden-queries.json` — N realistic queries per index with expected behavior rubrics.
2. Seeds two test tenants (`A`, `B`) with similar but distinct fixtures.
3. For each query:
   - Runs as tenant A; collects hits.
   - Verifies ZERO results carry `tenant_id = B` — fails the audit on any leak.
   - Verifies expected top-result(s) appear in top-K (e.g. exact-match SKU first).
   - Records latency.
4. Prints table; non-zero exit if any leak or any p95 > SLA.

## Usage

```bash
.claude/skills/search-audit.sh                              # all indexes, all queries
.claude/skills/search-audit.sh --index=products             # one index
.claude/skills/search-audit.sh --query='wireless earbuds'   # ad-hoc
.claude/skills/search-audit.sh --target=https://staging.example.com
.claude/skills/search-audit.sh --explain                    # include engine's _explanation
```

## Golden queries (sample shape)

```json
[
  {
    "index": "products",
    "query": "iphone 14 pro",
    "rubric": {
      "topResultMustContain": ["iPhone 14 Pro"],
      "topResultMustNotContain": ["iPhone 13"],
      "minResults": 3,
      "maxResults": 50,
      "relevanceCheck": "exact-name match scores higher than partial"
    }
  },
  {
    "index": "products",
    "query": "phn",
    "rubric": {
      "typoTolerance": true,
      "topResultMustContain": ["phone"],
      "minResults": 1
    }
  },
  {
    "index": "products",
    "query": "ايفون",
    "locale": "ar",
    "rubric": {
      "tokenizer": "arabic",
      "topResultMustContain": ["iPhone", "آيفون"]
    }
  },
  {
    "index": "orders",
    "query": "ORD-12345",
    "rubric": {
      "exactMatch": true,
      "topResultId": "ORD-12345",
      "minResults": 1,
      "maxResults": 1
    }
  }
]
```

## Engine-specific verification

### Meilisearch
```bash
curl -X POST "$MEILI_URL/indexes/products/search" \
  -H "Authorization: Bearer $MEILI_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "q": "iphone 14 pro",
    "limit": 20,
    "filter": "tenant_id = \"A\""
  }'
```
Inspect `processingTimeMs`, `estimatedTotalHits`, `hits[].tenant_id`.

### Typesense
```bash
curl "https://$TS_HOST/collections/products/documents/search?q=iphone&query_by=name&filter_by=tenant_id:A&per_page=20" \
  -H "X-TYPESENSE-API-KEY: $TS_KEY"
```

### Elasticsearch / OpenSearch
```bash
curl -X POST "$ES_URL/products/_search" -H 'Content-Type: application/json' -d '{
  "query": {
    "bool": {
      "must":   [{ "multi_match": { "query": "iphone", "fields": ["name^3", "description"] } }],
      "filter": [{ "term": { "tenant_id": "A" } }]
    }
  },
  "size": 20,
  "timeout": "500ms"
}'
```
Inspect `took`, `_shards.failed`, `hits.hits[]._source.tenant_id`.

### Postgres FTS
```sql
SELECT id, name, ts_rank(search_vector, websearch_to_tsquery('english', 'iphone')) AS rank
FROM products
WHERE tenant_id = 'A' AND search_vector @@ websearch_to_tsquery('english', 'iphone')
ORDER BY rank DESC
LIMIT 20;
```
Use `EXPLAIN ANALYZE` to verify GIN index usage.

## Output

```
/search-audit — products index, tenant=A

Query: "iphone 14 pro"
  Hits:                12
  Latency:             24 ms (p95 across 100 runs: 41 ms — SLA 500 ms OK)
  Top 3:
    1. iPhone 14 Pro 256GB    score 9.84    OK exact match
    2. iPhone 14 Pro Max      score 8.21    OK
    3. iPhone 14 Pro Case     score 6.30    OK accessory
  Cross-tenant leak:   0 / 12      OK
  Rubric:              PASS

Query: "phn" (typo)
  Hits:                4
  Top:                 Phone case  score 4.1   OK typo-tolerant
  Latency:             18 ms       OK
  Cross-tenant leak:   0 / 4       OK

Query: "ايفون" (Arabic, locale=ar)
  Hits:                7
  Top:                 آيفون 14 برو       OK Arabic stemming
  Latency:             22 ms              OK
  Cross-tenant leak:   0 / 7              OK

Query: "ORD-12345" (exact-match order)
  Hits:                1                  OK exact
  Top:                 Order ORD-12345    OK
  Latency:             8 ms               OK

Summary: 4/4 queries PASS. Latency p95=41ms (SLA 500ms). Zero cross-tenant leaks.
```

## Negative tests (must fail correctly)

```bash
# As tenant A, query for entity that ONLY exists in tenant B
.claude/skills/search-audit.sh --query='exclusive-to-B-product' --tenant=A
# Expected: 0 hits. If any → tenant filter regression.

# Without tenant filter (synthetic — invoke raw client)
.claude/skills/search-audit.sh --raw --query='product' --no-tenant-filter
# Expected: command refuses or warns; raw call returns mixed tenants — proves filter is the gate.
```

## When to run

- After any change to the indexer or query builder.
- After ranking config change (verify top results didn't shift unexpectedly).
- After tokenizer / stop-word / synonym changes.
- After engine version bump.
- Daily smoke from CI.
- After backfill / bulk-reindex (verify document counts + spot-check queries).

## Failure modes the command surfaces

- **Cross-tenant leak** — query filter missing or wrong field name.
- **No results when expected** — indexer lag, missing sync, document not indexed.
- **Wrong top result** — ranking config regression, missing boost, stop-word stripped key term.
- **High p95** — engine sizing, missing index, expensive query (deep facet).
- **Engine error** — `_shards.failed` (Elastic), Meilisearch 500, Typesense overloaded.
- **Locale mismatch** — Arabic query returns nothing because tokenizer not configured.

## Follow-ups

- Tenant leak: BLOCKER. Stop release. Fix the missing filter; re-run.
- Ranking regression: rollback ranking config OR run an A/B test before promoting.
- Latency cliff: check engine cluster health, recent index size, recent query volume.
