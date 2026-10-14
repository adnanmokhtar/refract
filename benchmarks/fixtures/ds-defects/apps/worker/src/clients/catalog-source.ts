import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class CatalogSource {
  async page(cursor?: string): Promise<{ items: Array<{ sku: string }>; next?: string }> {
    const res = await request(`${process.env.CATALOG_URL}/items?cursor=${cursor ?? ''}`);
    return (await res.body.json()) as { items: Array<{ sku: string }>; next?: string };
  }

  async indexItem(item: { sku: string }): Promise<void> {
    await request(`${process.env.SEARCH_URL}/catalog/_doc/${item.sku}`, { method: 'PUT', body: JSON.stringify(item) });
  }
}
