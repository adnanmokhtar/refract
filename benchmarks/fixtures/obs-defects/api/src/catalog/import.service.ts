import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { feedLastImport } from '../metrics/metrics';
import { FeedRow, toProduct } from './feed';
import { ProductRepository } from './product.repository';

/** Nightly supplier feed: 40–60k rows per run, POSTed by the supplier to /catalog/feed. */
@Injectable()
export class ImportService {
  constructor(
    private readonly products: ProductRepository,
    @InjectPinoLogger(ImportService.name) private readonly logger: PinoLogger,
  ) {}

  async importFeed(rows: FeedRow[]): Promise<number> {
    let imported = 0;
    for (const row of rows) {
      this.logger.info({ row: JSON.stringify(row) }, 'importing feed row');
      await this.products.upsert(toProduct(row));
      imported += 1;
    }
    feedLastImport.setToCurrentTime();
    return imported;
  }
}
