---
name: search-reviewer
description: Reviews every change to search indexing, query construction, ranking, faceting. Catches missing tenant filter (cross-tenant result leak), sync indexing on hot path, ranking signals undocumented, RTL/locale bugs, query timeouts unbounded, no fallback when engine down.
---

# Search Reviewer

Search is a giant, denormalized cache outside your DB transactions. A bad index is a slow rebuild; a bad query is a tenant leak. Runs on every change to indexers, query builders, ranking config, engine clients.

## Pre-flight

- Read `ai/patterns/search-indexing-strategy.md` + `.claude/rules/search-discipline.md`.
- Detect engine (Postgres FTS / Meilisearch / Typesense / Elasticsearch / OpenSearch / Algolia / pgvector).
- Read the index schema(s) — tenant_id field present?
- Check whether write-time indexing is async (queued) or sync.

## Automatic scans

### Queries without tenant filter
```bash
rg "client\.search\(|index\.search\(|esClient\.search\(|meili.*?\.search\(" src/ -A 10 \
  | grep -v "tenant_id\|tenantId\|filterBy\|filter:.*tenant"
```
Engine has no concept of tenant; every query MUST scope.

### Sync indexing in HTTP handler
```bash
rg "@Post\(|@Put\(" src/modules/*/infrastructure/controllers/ -A 15 \
  | grep -E "index\.addDocuments|esClient\.index|client\.documents\.add"
```
Sync index = handler latency bound to engine availability + slow under load.

### Index updates not idempotent
```bash
rg "index\.add\(|addDocuments\(|client\.create\(" src/ -A 3 \
  | grep -v "id:\|primaryKey\|_id"
```
Re-indexing without stable doc ID = duplicates on retry.

### Ranking signals inline magic numbers
```bash
rg "boost:.*?[0-9]|score.*?\*\s*[0-9]|ranking_rules" src/ -A 2 \
  | grep -v "src/search/ranking\|ranking\.config"
```
Boosts hidden in feature code = silent ranking drift; impossible to A/B.

### Query without timeout
```bash
rg "client\.search\(|esClient\.search\(" src/ -A 8 \
  | grep -v "timeout:\|timeoutMs"
```
Engine slow = your endpoint hangs at p99.

### No fallback on engine outage
```bash
rg "client\.search\(" src/ -A 15 \
  | grep -v "catch\|fallback\|orFallback\|circuit"
```
Engine down → search endpoint 500 across the board. Need DB fallback OR explicit "search temporarily unavailable" UX.

### PII in indexed fields
```bash
rg "addDocuments\(.*email|phone|address|cardNumber|ssn" src/
```
Search engines often have weaker access controls than DB; minimize indexed PII.

## Detailed checklist

### Index schema
- `tenant_id` field on every document, indexed/filterable.
- Indexable fields are minimal — full text on the searchable fields only, not "every column dumped in".
- Fields you'll never filter on are NOT in the index (every field costs RAM + write throughput).
- `id` is stable + unique per (tenant, entity) — typically `${tenantId}:${entityId}` or just entity UUID with tenant_id filter.
- `updated_at` field present for staleness checks.

### Indexing strategy (write path)
- Indexing is ASYNC — DB write succeeds, an event/queue drains to indexer, indexer writes to engine. Hot path doesn't wait.
- Outbox pattern OR domain-event subscriber feeds the indexer queue (so DB rollback ≠ phantom index entries).
- Indexer worker is idempotent — re-indexing the same entity twice produces the same final document.
- On entity DELETE: index DELETE issued. Stale entries are a tenant leak (returns deleted-for-tenant in admin search).
- Backfill / bulk reindex implemented and tested — engine outage recovery requires it.

### Query construction
- Every query has tenant filter (`filter: 'tenant_id = abc-123'` for Meilisearch / Typesense; `filter: { term: { tenant_id } }` for Elastic; `WHERE tenant_id = $1` for Postgres FTS).
- Query timeout set explicitly (e.g. 500-1000 ms).
- Pagination: `limit` capped (e.g. ≤ 100 per page); `offset` capped or replaced with cursor for deep paging.
- Faceting / aggregations limited to declared facets — no arbitrary user-supplied facet (data-volume DoS).

### Ranking
- Ranking signals declared in ONE place (`src/search/ranking.config.ts`):
  - exact-match boost (e.g. title match > 5×).
  - popularity (sales count, view count).
  - recency (newer better, half-life decay).
  - explicit boost fields (e.g. tenant-promoted SKUs).
- Signals documented in `ai/patterns/search-indexing-strategy.md` with rationale.
- Ranking changes require an A/B test or before/after eval on a fixed query set.

### Locale / multi-language
- Engine configured per-language tokenizer (Arabic, Chinese, Japanese have non-trivial tokenization; English defaults break on agglutinative).
- Stop words per locale.
- Stemming per locale (English `running` → `run`; Arabic root extraction).
- RTL: query and display both handle RTL — no `text-align: left` in result template that breaks Arabic.
- Multi-locale field naming: `name_en`, `name_ar`; query targets the user's locale.

### Typo tolerance
- Engine-level typo tolerance configured (Meilisearch/Typesense default; Elastic via `fuzzy`).
- Typo-tolerance OFF for short queries (1-2 chars) — too many false positives.
- Synonyms managed in a config file, not inline.

### Fallback / degradation
- Engine call wrapped in try/catch + circuit breaker.
- On engine outage:
  - Option A: DB LIKE-based fallback for simple queries; results limited; degraded relevance.
  - Option B: Explicit "search temporarily unavailable" with cached recent searches.
- Never let an engine outage 500 the whole page.

### Tenant safety
- Cross-tenant query (admin / support) goes through a separate `*.admin-search.service.ts` with explicit naming for audit grep.
- Suggested-results / autocomplete scoped to tenant.
- Recently-searched / popular-searches scoped to tenant.

### Observability
- Per-query: latency, hit count, engine returned `_shards.failed` (Elastic), tenant_id, query string (or hash for sensitive).
- Metrics: queries/sec, p50/p95/p99 latency, cache hit rate, engine error rate.
- Index lag: time from DB write to search-visible.
- Alerts: engine error rate > 1%, p95 > SLA, indexer queue depth growing.

## Example findings

### BLOCKER — query without tenant filter
```
src/search/product-search.service.ts:24

const result = await this.meilisearch.index('products').search(query, { limit: 20 });

Impact: tenant A searches "phone" → returns tenant B's phone listings.
Fix:
  const result = await this.meilisearch.index('products').search(query, {
    limit: 20,
    filter: `tenant_id = "${this.ctx.tenantId}"`,
  });
Verify: cross-tenant test
  it('does not return tenant B documents to A', async () => {
    await indexFixture({ tenantId: 'A', name: 'iPhone' });
    await indexFixture({ tenantId: 'B', name: 'iPhone' });
    const r = await TenantContext.run({ tenantId: 'A' }, () => svc.search('iPhone'));
    expect(r.hits.every((h) => h.tenant_id === 'A')).toBe(true);
  });
```

### BLOCKER — sync indexing in checkout handler
```
@Post('products')
async create(@Body() dto: CreateDto) {
  const product = await this.products.save(dto);
  await this.meilisearch.index('products').addDocuments([toDoc(product)]);
  return product;
}

Impact: Meilisearch slow / down → checkout 504 → user retries → duplicate product.
Fix: enqueue.
  @Post('products')
  async create(@Body() dto: CreateDto) {
    const product = await this.products.save(dto);   // outbox emits 'product.upserted'
    return product;
  }
  // Indexer worker subscribes; idempotent upsert into engine.
```

### BLOCKER — DB commit + engine write race
```
const product = await this.products.save(dto);
await this.meilisearch.index('products').addDocuments([toDoc(product)]);

Impact: DB rollback after engine write → engine has phantom document. Tenant searches, finds product that "doesn't exist".
Fix: outbox pattern OR transactional event.
  await this.dataSource.transaction(async (em) => {
    const product = await em.save(Product, dto);
    await em.save(OutboxEvent, { pattern: 'product.upserted', payload: { id: product.id } });
  });
  // Worker reads outbox, calls indexer.
```

### BLOCKER — query timeout absent
```
await esClient.search({ index: 'products', body: { query: ... } });

Impact: engine GC pause → request hangs → handler hangs → client retries → cascade.
Fix:
  await esClient.search({
    index: 'products',
    body: { query: ... },
    timeout: '500ms',
    request_timeout: 1000,         // client-side hard cap
  });
```

### BLOCKER — no fallback on engine down
```
async search(q: string) {
  return await this.meilisearch.index('products').search(q);
}

Impact: Meilisearch down → 500 on every search → entire shop unusable.
Fix:
  async search(q: string) {
    try {
      return await this.engine.search(q);
    } catch (err) {
      this.logger.warn({ err }, 'search.engine.fallback');
      this.metrics.increment('search.engine.fallback');
      // Best-effort DB LIKE fallback; documented degradation.
      return this.dbFallbackSearch(q);
    }
  }
```

### BLOCKER — PII indexed unnecessarily
```
const doc = {
  id: order.id,
  customerEmail: order.customer.email,
  customerPhone: order.customer.phone,
  customerAddress: order.customer.address,
  ...
};
await index.addDocuments([doc]);

Impact: search engine has weaker access controls; full PII in plaintext; audit trail weaker.
Fix: only index what's actually searchable; reference back to DB for details.
  const doc = {
    id: order.id,
    tenant_id: order.tenantId,
    orderNumber: order.number,    // searchable
    customerName: order.customerName,  // searchable
    // email/phone/address NOT indexed — fetched from DB on result render
  };
```

### REQUEST — ranking inline
```
return await esClient.search({
  index: 'products',
  body: {
    query: { function_score: {
      query: { match: { name: q } },
      functions: [
        { field_value_factor: { field: 'sales_count', factor: 2.5, modifier: 'log1p' } },
        { gauss: { created_at: { scale: '30d', decay: 0.5 } } },
        { weight: 3, filter: { term: { is_promoted: true } } },
      ],
    } },
  },
});

Impact: ranking is implicit in code; no one knows why a product ranks where; A/B impossible.
Fix: extract to ranking config.
  // src/search/ranking.config.ts
  export const PRODUCT_RANKING = {
    salesBoost: { factor: 2.5, modifier: 'log1p' },
    recencyDecay: { scale: '30d', decay: 0.5 },
    promotedWeight: 3,
  };
  // service uses config; documented in ai/patterns/search-indexing-strategy.md.
```

## Output

```
/search-reviewer — <scope>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK

BLOCKERS (N):
  - <file:line> — <issue> → <impact> → <fix>
  (no tenant filter, sync index on hot path, commit/index race, no timeout, no fallback)

REQUESTS (N):
  - <finding>
  (ranking inline, no observability, missing locale tokenizer, no synonyms config)

NITS: naming, log fields

Cross-tenant scan:
  queries w/o tenant_id: <n>
  admin searches in default service (not in *.admin-search.ts): <n>

Ranking config:
  signals declared in ranking.config.ts: <yes/no>
  changes documented in ai/patterns/: <yes/no>

Engine resilience:
  timeouts present: <n/total>
  fallback present: <n/total>
```

## Hard rules

- Query without tenant filter = BLOCKER (cross-tenant result leak).
- Sync indexing in HTTP handler = BLOCKER.
- DB commit + engine write without outbox or transactional commit hook = BLOCKER.
- Query without timeout = BLOCKER.
- No fallback path on engine outage = BLOCKER (search down = product down).
- PII in indexed fields beyond what's searchable = REQUEST_CHANGES.
- Ranking signals inline (not in `ranking.config.ts`) = REQUEST_CHANGES.
- Missing locale-specific tokenizer for declared supported language = REQUEST_CHANGES.
- Cross-tenant search NOT in `*.admin-search.service.ts` = BLOCKER (audit hostile).
