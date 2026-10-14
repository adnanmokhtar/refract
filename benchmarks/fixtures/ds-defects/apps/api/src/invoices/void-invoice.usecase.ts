import { Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { OUTBOX_PORT, OutboxPort } from '../outbox/outbox.port';
import { TxRunner } from '../outbox/tx-runner';
import { Invoice } from './invoice.entity';

@Injectable()
export class VoidInvoice {
  constructor(
    private readonly tx: TxRunner,
    private readonly em: EntityManager,
    @Inject(OUTBOX_PORT) private readonly outbox: OutboxPort,
  ) {}

  async execute(invoiceId: string, reason: string): Promise<void> {
    await this.tx.run(async () => {
      const invoice = await this.em.findOneOrFail(Invoice, invoiceId);
      invoice.void(reason);
      await this.em.flush();
      await this.outbox.emit('invoice.voided', { invoiceId, reason }, invoice.id);
    });
  }
}
