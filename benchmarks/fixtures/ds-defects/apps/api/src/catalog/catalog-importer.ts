import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class CatalogImporter {
  constructor(private readonly em: EntityManager) {}

  async merchantsWithFeeds(): Promise<string[]> {
    const rows = await this.em.getConnection().execute<{ id: string }[]>('SELECT id FROM merchants WHERE feed_url IS NOT NULL');
    return rows.map((r) => r.id);
  }

  async importFeed(merchantId: string): Promise<void> {
    await this.em.getConnection().execute('SELECT import_catalog_feed(?)', [merchantId]);
  }
}
