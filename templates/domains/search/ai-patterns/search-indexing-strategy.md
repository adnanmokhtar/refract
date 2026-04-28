# Pattern: Search indexing strategy (write-time async via queue)

DB writes commit first; an outbox-driven worker indexes to the search engine; queries hit the engine through a tenant-scoped wrapper; engine outage degrades to a DB fallback.

## Decision summary

Default search tech: **Meilisearch** (small/medium catalogs) OR **Typesense** (developer-friendly, similar capability). Reasons:
- Single binary, sane defaults, < 30 min to production.
- Built-in typo tolerance, faceting, multi-language tokenizers.
- TypeScript-first SDKs.
- Filterable attributes for tenant scoping.

When to choose differently:

| Engine | When |
|---|---|
| **Postgres FTS** (`tsvector` + GIN) | < 1M docs, simple queries, you don't want a separate service. Free, no extra infra. |
| **Meilisearch / Typesense** | 100k - 100M docs, typo + facets + fast iteration. Default. |
| **Elasticsearch / OpenSearch** | > 100M docs, complex aggregations, log analytics, multi-cluster. Heavier ops. |
| **Algolia** | small team, want it tomorrow, willing to pay per record. Hosted. |
| **pgvector** | semantic / similarity search via embeddings. Pair with FTS for hybrid. |
| **Pinecone / Weaviate** | dedicated vector DB; pure embedding-search; > millions of vectors. |

## File layout

```
src/search/
├── core/
│   ├── searchable.interface.ts           # toSearchDoc() contract
│   ├── ranking.config.ts                 # ALL ranking signals declared here
│   ├── synonyms.json
│   └── stopwords/
│       ├── en.txt
│       └── ar.txt
├── application/
│   ├── tenant-scoped-search-client.ts    # wraps engine SDK, injects tenant filter
│   ├── product-search.service.ts         # public query API
│   └── product-admin-search.service.ts   # cross-tenant — explicit name for audit
└── infrastructure/
    ├── engines/
    │   ├── meilisearch.client.ts
    │   ├── postgres-fts.client.ts        # fallback path
    │   └── circuit-breaker.ts
    └── workers/
        ├── product-indexer.worker.ts
        └── reindex-all.worker.ts         # backfill / migration
```

## Searchable interface

```ts
export interface Searchable<TDoc> {
  toSearchDoc(): TDoc & { id: string; tenant_id: string; updated_at: string };
}
```

Each entity that participates in search implements this. The doc shape is the engine schema.

## Product example

```ts
// core/product/product.entity.ts
export class Product implements Searchable<ProductSearchDoc> {
  // ... fields ...

  toSearchDoc(): ProductSearchDoc {
    return {
      id: this.id,
      tenant_id: this.tenantId,
      name_en: this.name.en,
      name_ar: this.name.ar,
      sku: this.sku,
      description_en: stripHtml(this.description.en),
      description_ar: stripHtml(this.description.ar),
      categories: this.categories.map((c) => c.slug),
      price_cents: this.priceCents,
      sales_count: this.salesCount,
      created_at_unix: Math.floor(this.createdAt.getTime() / 1000),
      is_promoted: this.isPromoted,
      in_stock: this.stockOnHand > 0,
      updated_at: this.updatedAt.toISOString(),
    };
  }
}
```

Note: NO customer PII, NO internal cost, NO supplier name — only what users actually search by.

## Indexing trigger (outbox)

```ts
// application/place-order.use-case.ts (example — same pattern for upsert)
async upsertProduct(dto: UpsertProductDto): Promise<Product> {
  return this.dataSource.transaction(async (em) => {
    const product = await em.save(Product, dto);
    await em.save(OutboxEvent, {
      pattern: 'product.upserted',
      payload: { id: product.id, tenantId: product.tenantId },
    });
    return product;
  });
}
```

Then a separate `OutboxDrainerWorker` reads `outbox_events`, enqueues to BullMQ, deletes the row. Two-phase: zero risk of "DB rolled back, engine has phantom".

## Indexer worker

```ts
@Injectable()
export class ProductIndexerWorker {
  constructor(
    private readonly products: ProductRepository,
    private readonly engine: MeilisearchClient,
    private readonly logger: Logger,
  ) {
    new Worker('product-index', async (job) => {
      const { id } = job.data;
      const product = await this.products.findById(id);

      if (!product) {
        // Deleted — remove from index.
        await this.engine.index('products').deleteDocument(id);
        return;
      }

      const doc = product.toSearchDoc();
      await this.engine.index('products').addDocuments([doc]);   // upsert by `id`

      this.logger.info({ productId: id, tenantId: product.tenantId }, 'product.indexed');
    }, { connection: queueConnection, concurrency: 50 });
  }
}
```

`addDocuments` with stable `id` is upsert — idempotent, retry-safe.

## Tenant-scoped search client

```ts
@Injectable()
export class TenantScopedSearchClient {
  constructor(private readonly engine: MeilisearchClient, private readonly ctx: TenantContext) {}

  async search(indexName: string, query: string, options: SearchOptions = {}): Promise<SearchResponse> {
    const tenantId = this.ctx.getTenantId();   // throws if missing
    const tenantFilter = `tenant_id = "${tenantId}"`;
    const combinedFilter = options.filter
      ? `(${options.filter}) AND ${tenantFilter}`
      : tenantFilter;

    return this.engine.index(indexName).search(query, {
      ...options,
      filter: combinedFilter,
      limit: Math.min(options.limit ?? 20, 100),
      attributesToRetrieve: options.attributesToRetrieve ?? ['*'],
    });
  }
}
```

This is the ONLY entry point for tenant-scoped searches. Feature code calls it; never the raw Meilisearch SDK.

## Public query service

```ts
@Injectable()
export class ProductSearchService {
  constructor(
    private readonly client: TenantScopedSearchClient,
    private readonly fallback: PostgresFtsSearch,
    private readonly breaker: CircuitBreaker,
    private readonly logger: Logger,
    private readonly metrics: Metrics,
  ) {}

  async search(input: SearchInput): Promise<SearchResult> {
    if (this.breaker.isOpen('meilisearch')) {
      this.metrics.increment('search.fallback', { reason: 'breaker_open' });
      return this.fallback.search(input);
    }

    const start = Date.now();
    try {
      const result = await this.client.search('products', input.query, {
        limit: input.limit ?? 20,
        offset: input.offset ?? 0,
        filter: this.buildFacetFilter(input.facets),
        attributesToHighlight: ['name_en', 'name_ar', 'description_en', 'description_ar'],
        sort: this.buildSort(input.sort),
      });
      this.breaker.recordSuccess('meilisearch');
      this.metrics.histogram('search.latency_ms', Date.now() - start, { engine: 'meilisearch' });
      return mapToResult(result);
    } catch (err) {
      this.breaker.recordFailure('meilisearch');
      this.logger.warn({ err, query: input.query }, 'search.engine.error.fallback');
      this.metrics.increment('search.fallback', { reason: 'engine_error' });
      return this.fallback.search(input);
    }
  }

  private buildFacetFilter(facets?: Record<string, string>): string | undefined {
    if (!facets) return undefined;
    return Object.entries(facets)
      .filter(([key]) => ALLOWED_FACETS.includes(key))    // declared facet allowlist
      .map(([key, value]) => `${key} = "${value.replace(/"/g, '\\"')}"`)
      .join(' AND ');
  }

  private buildSort(sort?: 'relevance' | 'price_asc' | 'price_desc' | 'newest'): string[] | undefined {
    switch (sort) {
      case 'price_asc':  return ['price_cents:asc'];
      case 'price_desc': return ['price_cents:desc'];
      case 'newest':     return ['created_at_unix:desc'];
      default:           return undefined;                // relevance — engine default + ranking config
    }
  }
}
```

## Ranking config

```ts
// core/ranking.config.ts
export const PRODUCT_INDEX_RANKING = {
  /** Meilisearch ranking rules — order matters */
  rankingRules: [
    'words',          // more matched query words first
    'typo',           // fewer typos first
    'proximity',      // closer matched terms first
    'attribute',      // earlier-listed searchable attrs first (name > description)
    'sort',           // user-supplied sort
    'exactness',      // exact > prefix
    'sales_count:desc',         // popularity tiebreaker
    'created_at_unix:desc',     // recency tiebreaker
  ],
  searchableAttributes: ['name_en', 'name_ar', 'sku', 'description_en', 'description_ar'],
  filterableAttributes: ['tenant_id', 'categories', 'price_cents', 'in_stock', 'is_promoted'],
  sortableAttributes:   ['price_cents', 'created_at_unix', 'sales_count'],
  synonyms: require('./synonyms.json'),
  stopWords: { en: require('./stopwords/en.txt'), ar: require('./stopwords/ar.txt') },
} as const;
```

These constants are applied at index-create time (or migration) — never inline in search calls.

## Multi-locale tokenization

Meilisearch / Typesense auto-detect language. Elastic requires per-field analyzer:

```json
{
  "mappings": {
    "properties": {
      "name_en": { "type": "text", "analyzer": "english" },
      "name_ar": { "type": "text", "analyzer": "arabic" },
      "name_zh": { "type": "text", "analyzer": "smartcn" }
    }
  }
}
```

Postgres FTS:
```sql
CREATE INDEX idx_products_name_en ON products USING GIN (to_tsvector('english', name_en));
CREATE INDEX idx_products_name_ar ON products USING GIN (to_tsvector('arabic', name_ar));
```

## Backfill / reindex

When schema changes or after engine outage data divergence:

```ts
@Injectable()
export class ReindexAllWorker {
  async reindex(tenantId?: string) {
    const cursor = new BatchCursor(this.products, { tenantId, batchSize: 500 });
    let total = 0;
    for await (const batch of cursor) {
      const docs = batch.map((p) => p.toSearchDoc());
      await this.engine.index('products').addDocuments(docs);
      total += docs.length;
      this.logger.info({ total, tenantId }, 'reindex.progress');
    }
    this.logger.info({ total, tenantId }, 'reindex.completed');
  }
}
```

Run as a job; checkpoint via cursor; idempotent.

## Vector / hybrid search (pgvector example)

```sql
ALTER TABLE products ADD COLUMN embedding vector(1536);
CREATE INDEX idx_products_embedding ON products USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- query: "wireless earbuds with active noise cancellation"
SELECT id, name, 1 - (embedding <=> $1) AS similarity
FROM products
WHERE tenant_id = $2 AND in_stock = true
ORDER BY embedding <=> $1
LIMIT 20;
```

`$1` is the query embedding (768/1536 floats from your embedding model). Hybrid: combine FTS rank + vector similarity (e.g. `rank * 0.6 + similarity * 0.4`).

## Trade-off table

| Concern | Postgres FTS | Meilisearch | Typesense | Elasticsearch |
|---|---|---|---|---|
| Setup | ★★★★★ (already there) | ★★★★ | ★★★★ | ★★ |
| Typo tolerance | manual (`pg_trgm`) | yes | yes | yes (`fuzzy`) |
| Faceting | manual `GROUP BY` | built-in | built-in | aggregations |
| Multi-language | per-config | auto | auto | per-analyzer |
| Scale | < 1M docs | < 100M | < 100M | unlimited |
| Vector | pgvector | experimental | yes | yes (k-NN) |
| Ops cost | free | low | low | high |
| Real-time freshness | instant (same DB) | seconds | seconds | seconds (refresh interval) |

## Common mistakes

- **Sync indexing in HTTP handler** — engine slow / down → handler hangs / 500s → user retries → duplicate writes.
- **DB commit + engine write race** — engine has phantom doc when DB rollback happens. Outbox or commit-hook required.
- **Re-index without stable doc id** — duplicates accumulate; user sees same product twice.
- **Tenant filter forgotten on one query path** — leak on Day 1, discovered on Day 90 when an angry tenant calls.
- **Facets unlimited / arbitrary** — user sends `{ facets: ['internal_cost', 'supplier_id'] }`; suddenly your data leaks.
- **Ranking signals scattered inline** — no one knows why a product ranks where; A/B impossible.
- **No timeout** — engine GC pause → handler hangs → cascade.
- **No fallback** — engine down = entire shop's search broken.
- **PII over-indexed** — search engine has weaker access controls than DB; minimize.
- **Stale entries on entity DELETE** — DELETE didn't propagate; deleted product appears in search.
- **Backfill never tested** — engine corruption / migration day arrives, you discover the script doesn't work.
- **Locale fallback to English silently** — Arabic user sees English results because Arabic tokenizer wasn't configured.
- **Wildcard prefix queries** (`*phone`) on large indexes — full scan.
- **Deep pagination** (offset > 1000) — engines pay O(offset) cost; use cursor.
- **Storing the search query as-is in logs** — query can contain PII; redact or hash.
