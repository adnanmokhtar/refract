import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { MarketingMailer } from '../clients/marketing-mailer';

export interface NewsletterJob {
  merchantId: string;
  campaignId: string;
}

/**
 * Merchant newsletters. Each job sends one campaign to one merchant; jobs are independent of each other and
 * their order does not matter (the provider dedupes on campaign + recipient).
 */
@Processor('newsletter', { concurrency: 10 })
export class NewsletterProcessor extends BaseProcessor<NewsletterJob> {
  constructor(
    private readonly mailer: MarketingMailer,
    reports: FailureReports,
  ) {
    super(30_000, reports);
  }

  protected async handle(job: Job<NewsletterJob>, signal: AbortSignal): Promise<void> {
    await this.mailer.sendCampaign(job.data.campaignId, job.data.merchantId, signal);
  }
}
