import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';
import { ReceiptMailer } from '../clients/receipt-mailer';

export interface ReceiptJob {
  orderId: string;
}

/** Sends the customer's order receipt (e-mail with the PDF attached). */
@Processor('receipts', { concurrency: 5 })
export class ReceiptsProcessor extends BaseProcessor<ReceiptJob> {
  constructor(
    private readonly mailer: ReceiptMailer,
    reports: FailureReports,
  ) {
    super(30_000, reports);
  }

  protected async handle(job: Job<ReceiptJob>): Promise<void> {
    this.mailer.sendReceipt(job.data.orderId);
  }
}
