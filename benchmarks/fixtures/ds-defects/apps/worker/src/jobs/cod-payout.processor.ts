import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { PspClient } from '../clients/psp.client';

export interface CodPayoutJob {
  merchantId: string;
  day: string;
  amountMinor: number;
  currency: string;
}

/** Pays a merchant the cash collected on delivery for one day: one bank transfer through the PSP. */
@Processor('cod-payouts', { concurrency: 2 })
export class CodPayoutProcessor extends BaseProcessor<CodPayoutJob> {
  constructor(
    private readonly psp: PspClient,
    reports: FailureReports,
  ) {
    super(60_000, reports);
  }

  protected async handle(job: Job<CodPayoutJob>, signal: AbortSignal): Promise<void> {
    await this.psp.transfer({ merchantId: job.data.merchantId, amountMinor: job.data.amountMinor, currency: job.data.currency }, signal);
  }
}
