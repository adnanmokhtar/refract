import { Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { OUTBOX_PORT, OutboxPort } from '../outbox/outbox.port';
import { TxRunner } from '../outbox/tx-runner';
import { Invoice } from './invoice.entity';
import { InvoiceEvents } from './invoice-events';

@Injectable()
export class FinalizeInvoice {
  constructor(
    private readonly tx: TxRunner,
    private readonly em: EntityManager,
    private readonly events: InvoiceEvents,
    @Inject(OUTBOX_PORT) private readonly outbox: OutboxPort,
  ) {}

  async execute(invoiceId: string): Promise<void> {
    await this.tx.run(async () => {
      const invoice = await this.em.findOneOrFail(Invoice, invoiceId);
      invoice.status = 'issued';
      await this.em.flush();
      await this.outbox.emit(this.events.topic, this.events.toIssuedEvent(invoice), invoice.id);
    });
  }
}
