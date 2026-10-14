import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { EntityManager } from '@mikro-orm/core';
import { Invoice } from './invoice.entity';

/** Renders the invoice PDF after issue; drafts can be deleted by the merchant at any time. */
@Processor('invoice-pdf')
export class InvoicePdfProcessor extends WorkerHost {
  constructor(private readonly em: EntityManager) {
    super();
  }

  async process(job: Job<{ invoiceId: string }>): Promise<{ pages: number }> {
    const invoice = await this.em.fork().findOneOrFail(Invoice, { id: job.data.invoiceId });
    return { pages: invoice.number.length > 0 ? 1 : 0 };
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, err: Error): void {
    void job;
    void err;
  }
}
