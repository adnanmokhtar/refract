import { Processor, WorkerHost } from '@nestjs/bullmq';
import { InjectQueue } from '@nestjs/bullmq';
import type { Job, Queue } from 'bullmq';
import { InvoicesService } from '../invoices/invoices.service';

@Processor('invoices')
export class InvoiceIssuedProcessor extends WorkerHost {
  constructor(private readonly invoices: InvoicesService, @InjectQueue('mail') private readonly mail: Queue) {
    super();
  }

  async process(job: Job<{ invoiceId: number }>): Promise<void> {
    const { data } = await this.invoices.get(job.data.invoiceId);
    await this.mail.add('invoice-issued', { invoiceId: data.id, number: data.number });
  }
}
