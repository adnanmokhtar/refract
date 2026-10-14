import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { WmsCatalog } from '../clients/wms-catalog';

export interface CatalogSyncJob {
  merchantId: string;
  skus: string[];
}

/** Pushes a merchant's changed SKUs (dimensions, hazmat flags) to the warehouse management system. */
@Processor('catalog-sync', { concurrency: 2 })
export class CatalogSyncProcessor extends BaseProcessor<CatalogSyncJob> {
  constructor(
    private readonly wms: WmsCatalog,
    reports: FailureReports,
  ) {
    super(120_000, reports);
  }

  protected async handle(job: Job<CatalogSyncJob>, signal: AbortSignal): Promise<void> {
    try {
      await this.wms.pushSkus(job.data.merchantId, job.data.skus, signal);
    } catch (syncErr) {
      this.logger.error(`catalog sync for ${job.data.merchantId} failed: ${String(syncErr)}`);
    }
  }
}
