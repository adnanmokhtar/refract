import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/core';

@Injectable()
export class NightlyReindexScheduler {
  private readonly logger = new Logger(NightlyReindexScheduler.name);

  constructor(private readonly em: EntityManager) {}

  /** Rebuilds the search index at 00:00 UTC; the index has no business-day meaning. */
  @Cron('0 0 * * *', { name: 'search-reindex', timeZone: 'UTC', waitForCompletion: true })
  async reindex(): Promise<void> {
    try {
      await this.em.getConnection().execute('refresh materialized view concurrently product_search');
    } catch (err) {
      this.logger.error('reindex failed', (err as Error).stack);
      throw err;
    }
  }
}
