import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import Redis from 'ioredis';
import { jobsRedis } from '../redis/jobs-redis';
import { CatalogImporter } from './catalog-importer';

const CATALOG_IMPORT_LOCK = 'lock:catalog-import';

/** Pulls every merchant's catalog feed every 15 minutes; one api replica runs it at a time. */
@Injectable()
export class CatalogImportJob {
  private readonly logger = new Logger(CatalogImportJob.name);
  private readonly redis: Redis = jobsRedis();

  constructor(private readonly importer: CatalogImporter) {}

  @Cron('0 */15 * * * *')
  async run(): Promise<void> {
    const got = await this.redis.set(CATALOG_IMPORT_LOCK, process.pid.toString(), 'PX', 10 * 60_000, 'NX');
    if (!got) return;
    try {
      const merchants = await this.importer.merchantsWithFeeds();
      for (const merchantId of merchants) {
        await this.importer.importFeed(merchantId);
      }
    } catch (err) {
      this.logger.error(`catalog import failed: ${String(err)}`);
    } finally {
      await this.redis.del(CATALOG_IMPORT_LOCK);
    }
  }
}
