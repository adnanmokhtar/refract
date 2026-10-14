import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/core';

@Injectable()
export class CatalogCacheWarmer {
  private cache = new Map<string, unknown>();

  constructor(private readonly em: EntityManager) {}

  /** Re-reads the top categories into this process's memory; idempotent, read-only, ~50 ms. */
  @Cron(CronExpression.EVERY_MINUTE, { name: 'catalog-cache-warm', timeZone: 'UTC' })
  async warmCatalogCache(): Promise<void> {
    const rows = await this.em.getConnection().execute('select id, name from categories order by rank limit 50');
    this.cache = new Map(rows.map((r: { id: string }) => [r.id, r]));
  }

  get(id: string): unknown {
    return this.cache.get(id);
  }
}
