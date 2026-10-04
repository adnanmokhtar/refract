import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Writable } from 'node:stream';
import sax from 'sax';
import { Product } from './product.entity';

export interface FeedItem {
  sku: string;
  title: string;
  price: number;
  currency: string;
  stock: number;
}

const BATCH = 1_000;

// Seller XML feeds (<feed><item><sku/>…</item></feed>). Items are upserted in batches of 1 000.
@Injectable()
export class FeedImportService {
  constructor(private readonly em: EntityManager) {}

  async registeredFeedUrl(storeId: string): Promise<string> {
    const [row] = await this.em.execute<{ url: string }[]>('select url from store_feed where store_id = ? and verified', [storeId]);
    if (!row) throw new Error('no verified feed registered for this store');
    return row.url;
  }

  async importXml(storeId: string, xml: string): Promise<number> {
    const items: FeedItem[] = [];
    const parser = this.collector(items);
    parser.write(xml).close();
    for (let i = 0; i < items.length; i += BATCH) await this.upsertBatch(storeId, items.slice(i, i + BATCH));
    return items.length;
  }

  // A Writable that parses as bytes arrive and upserts every full batch.
  streamingParser(storeId: string): Writable & { count: number } {
    const pending: FeedItem[] = [];
    const parser = this.collector(pending);
    const sink = new Writable({
      write: (chunk: Buffer, _enc, done) => {
        parser.write(chunk.toString('utf8'));
        if (pending.length < BATCH) return done();
        const batch = pending.splice(0, pending.length);
        sink.count += batch.length;
        this.upsertBatch(storeId, batch).then(() => done(), done);
      },
      final: (done) => {
        parser.close();
        sink.count += pending.length;
        this.upsertBatch(storeId, pending.splice(0)).then(() => done(), done);
      },
    }) as Writable & { count: number };
    sink.count = 0;
    return sink;
  }

  private async upsertBatch(storeId: string, items: FeedItem[]): Promise<void> {
    if (items.length === 0) return;
    await this.em.upsertMany(
      Product,
      items.map((i) => ({ store: storeId, sku: i.sku, title: i.title, price: i.price, currency: i.currency, stock: i.stock })),
      { onConflictFields: ['store', 'sku'], onConflictAction: 'merge', onConflictMergeFields: ['title', 'price', 'currency', 'stock'] },
    );
  }

  private collector(into: FeedItem[]) {
    const parser = sax.parser(true, { trim: true });
    let current: Partial<FeedItem> | null = null;
    let field: keyof FeedItem | null = null;
    parser.onopentag = (tag) => {
      if (tag.name === 'item') current = {};
      else if (current && ['sku', 'title', 'price', 'currency', 'stock'].includes(tag.name)) field = tag.name as keyof FeedItem;
    };
    parser.ontext = (text) => {
      if (!current || !field) return;
      (current as Record<string, unknown>)[field] = field === 'price' || field === 'stock' ? Number(text) : text;
    };
    parser.onclosetag = (name) => {
      if (name === 'item' && current?.sku) into.push(current as FeedItem);
      if (name === 'item') current = null;
      field = null;
    };
    return parser;
  }
}
