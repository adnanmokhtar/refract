import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

/**
 * Sends the invoice e-mail once per invoice. The job id is the invoice id, so a second request while the first
 * job is queued is dropped by BullMQ.
 */
@Injectable()
export class InvoiceMailerProducer {
  constructor(@InjectQueue('invoices') private readonly queue: Queue) {}

  async sendInvoiceEmail(invoiceId: string, to: string): Promise<void> {
    await this.queue.add('send-invoice-email', { invoiceId, to }, { jobId: `invoice-email:${invoiceId}`, removeOnComplete: true });
  }
}
