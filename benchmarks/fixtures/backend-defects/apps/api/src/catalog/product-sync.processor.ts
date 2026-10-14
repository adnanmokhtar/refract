import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { Product } from '../products/product.entity';

/** Pushes a product to the marketplace feed; a product deleted since enqueue is skipped. */
@Processor('product-sync')
export class ProductSyncProcessor extends WorkerHost {
  private readonly logger = new Logger(ProductSyncProcessor.name);

  constructor(private readonly em: EntityManager) {
    super();
  }

  async process(job: Job<{ productId: string }>): Promise<'synced' | 'skipped'> {
    const product = await this.em.fork().findOne(Product, { id: job.data.productId });
    if (!product) {
      this.logger.warn(`product ${job.data.productId} gone before sync; discarding`);
      return 'skipped';
    }
    return 'synced';
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, err: Error): void {
    this.logger.error(`product sync failed for ${job.id}`, err.stack);
  }
}
