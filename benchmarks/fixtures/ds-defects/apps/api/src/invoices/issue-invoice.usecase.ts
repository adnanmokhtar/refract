import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { Queue } from 'bullmq';
import { Invoice } from './invoice.entity';

@Injectable()
export class IssueInvoice {
  constructor(
    private readonly em: EntityManager,
    @InjectQueue('invoices') private readonly invoiceQueue: Queue,
  ) {}

  async execute(invoiceId: string): Promise<void> {
    await this.em.transactional(async (em) => {
      const invoice = await em.findOneOrFail(Invoice, invoiceId);
      invoice.status = 'issued';
      await this.invoiceQueue.add('render-invoice-pdf', { invoiceId: invoice.id });
    });
  }
}
