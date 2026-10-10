import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { ErpClient } from './erp.client';
import { ProductRepository } from './product.repository';

@Injectable()
export class CatalogSyncService {
  constructor(
    private readonly erp: ErpClient,
    private readonly products: ProductRepository,
    @InjectPinoLogger(CatalogSyncService.name) private readonly logger: PinoLogger,
  ) {}

  async syncSku(sku: string): Promise<void> {
    try {
      const product = await this.erp.fetchProduct(sku);
      await this.products.upsert(product);
    } catch (e) {
      this.logger.error({ sku, err: String(e) }, 'catalog sync failed');
    }
  }
}
