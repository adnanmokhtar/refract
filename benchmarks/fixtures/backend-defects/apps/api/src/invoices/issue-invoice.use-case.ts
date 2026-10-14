import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { EventBus } from '../common/event-bus';
import { CreateInvoiceDto } from './dto/create-invoice.dto';
import { Invoice } from './invoice.entity';

@Injectable()
export class IssueInvoiceUseCase {
  constructor(private readonly em: EntityManager, private readonly events: EventBus) {}

  async execute(dto: CreateInvoiceDto): Promise<Invoice> {
    const invoice = this.em.create(Invoice, {
      number: `INV-${Date.now()}`,
      amountDue: dto.amountDue,
      currency: dto.currency,
      dueDate: dto.dueDate.toISOString().slice(0, 10),
      status: 'issued',
    });
    await this.em.flush();
    await this.events.publish('invoice.issued', { invoiceId: invoice.id, amountDue: invoice.amountDue, currency: invoice.currency });
    return invoice;
  }

  async find(id: string): Promise<Invoice> {
    return this.em.findOneOrFail(Invoice, { id });
  }
}
