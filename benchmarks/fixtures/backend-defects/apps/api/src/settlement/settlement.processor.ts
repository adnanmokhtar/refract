import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';

export interface SettlementJob {
  merchantId: string;
  payoutDate: string;
  currency: string;
}

/** Settles one merchant's day. Jobs are enqueued by SettlementScheduler with a 6 h delay. */
@Processor('settlement')
export class SettlementProcessor extends WorkerHost {
  private readonly logger = new Logger(SettlementProcessor.name);

  constructor(private readonly em: EntityManager) {
    super();
  }

  async process(job: Job<SettlementJob>): Promise<void> {
    await this.em.getConnection().execute('select settle_merchant_day(?, ?, ?)', [
      job.data.merchantId,
      job.data.payoutDate,
      job.data.currency.toUpperCase(),
    ]);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job<SettlementJob>, err: Error): void {
    this.logger.error(`settlement failed for ${job.data.merchantId}`, err.stack);
  }
}
