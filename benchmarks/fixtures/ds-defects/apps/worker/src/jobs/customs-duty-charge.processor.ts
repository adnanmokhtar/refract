import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { randomUUID } from 'node:crypto';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { PspClient } from '../clients/psp.client';

export interface DutyChargeJob {
  shipmentId: string;
  customerId: string;
  dutyMinor: number;
  currency: string;
}

/**
 * Charges the recipient's saved card for import duty before the parcel is released (DDP shipments). Jobs are
 * enqueued with attempts 5 (apps/api DutyChargeProducer).
 */
@Processor('duty-charges', { concurrency: 2 })
export class CustomsDutyChargeProcessor extends BaseProcessor<DutyChargeJob> {
  constructor(
    private readonly psp: PspClient,
    reports: FailureReports,
  ) {
    super(60_000, reports);
  }

  protected async handle(job: Job<DutyChargeJob>, signal: AbortSignal): Promise<void> {
    const idempotencyKey = randomUUID();
    await this.psp.charge({ customerId: job.data.customerId, amountMinor: job.data.dutyMinor, currency: job.data.currency, idempotencyKey }, signal);
  }
}
