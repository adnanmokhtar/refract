import { Injectable } from '@nestjs/common';
import { env } from '../common/env';
import { Product } from '../catalog/product.entity';
import { Store } from '../stores/store.entity';

// Search cluster ingest API. Indexing is idempotent per document id.
@Injectable()
export class SearchIndexClient {
  private readonly baseUrl = env('SEARCH_INGEST_URL');

  async indexStore(store: Store): Promise<void> {
    await this.send('PUT', `/stores/${store.id}`, {
      slug: store.slug,
      name: store.name,
      status: store.status,
      owner: store.owner.displayName,
      publishedAt: store.publishedAt?.toISOString(),
    });
  }

  async indexProducts(products: Product[]): Promise<void> {
    await this.send('POST', '/products/_bulk', {
      documents: products.map((p) => ({
        id: p.id,
        store: p.store.slug,
        title: p.title,
        category: p.category,
        price: p.price,
        currency: p.currency,
        status: p.status,
      })),
    });
  }

  async removeStore(storeId: string, reason: string): Promise<void> {
    await this.send('DELETE', `/stores/${storeId}?reason=${encodeURIComponent(reason)}`);
  }

  private async send(method: string, path: string, body?: unknown): Promise<void> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: { 'content-type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(2_000),
    });
    if (!res.ok) throw new Error(`search ingest ${method} ${path} failed with ${res.status}`);
  }
}
