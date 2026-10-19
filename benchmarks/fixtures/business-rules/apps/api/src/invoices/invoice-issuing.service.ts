import { ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Invoice, InvoiceStatus } from './invoice.entity';

@Injectable()
export class InvoiceIssuingService {
  constructor(private readonly em: EntityManager) {}

  async issue(invoice: Invoice): Promise<void> {
    if (invoice.status !== InvoiceStatus.Draft) throw new ConflictException('already issued');
    invoice.status = InvoiceStatus.Issued;
    invoice.issuedAt = new Date();
    await this.em.flush();
  }

  async markPaid(invoice: Invoice): Promise<void> {
    if (invoice.status !== InvoiceStatus.Issued) return;
    invoice.status = InvoiceStatus.Paid;
    await this.em.flush();
  }

  async markCredited(invoice: Invoice): Promise<void> {
    if (invoice.status !== InvoiceStatus.Issued) return;
    invoice.status = InvoiceStatus.Credited;
    await this.em.flush();
  }
}
