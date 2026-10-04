import { Injectable, NotFoundException } from '@nestjs/common';
import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { AuthUser } from '../auth/auth-user';
import { StoreMember } from '../stores/store-member.entity';
import { Invoice } from './invoice.entity';

export interface InvoiceFilter {
  storeId?: string;
  from?: Date;
  to?: Date;
}

export interface InvoiceDto {
  id: string;
  number: string;
  storeId: string;
  totalCents: number;
  currency: string;
  issuedAt: string;
}

const toDto = (i: Invoice): InvoiceDto => ({
  id: i.id,
  number: i.number,
  storeId: i.store.id,
  totalCents: Number(i.totalCents),
  currency: i.currency,
  issuedAt: i.issuedAt.toISOString(),
});

@Injectable()
export class InvoiceListService {
  constructor(private readonly em: EntityManager) {}

  // GET /invoices — one list for every kind of caller: a buyer sees the invoices they were
  // billed, store staff see their store's, support and finance see everything they filter for.
  async list(user: AuthUser, filter: InvoiceFilter): Promise<InvoiceDto[]> {
    const where: Record<string, unknown> = {};
    if (filter.storeId) where.store = filter.storeId;
    else if (!user.roles.includes('support') && !user.roles.includes('finance')) where.buyer = user.id;
    if (filter.from || filter.to) where.issuedAt = { ...(filter.from && { $gte: filter.from }), ...(filter.to && { $lt: filter.to }) };

    const invoices = await this.em.find(Invoice, where, { orderBy: { issuedAt: QueryOrder.DESC }, limit: 100 });

    const visible: Invoice[] = [];
    for (const invoice of invoices) {
      if (await this.canView(user, invoice)) visible.push(invoice);
    }
    return visible.map(toDto);
  }

  async summaryForOrder(orderId: string): Promise<InvoiceDto | null> {
    const invoice = await this.em.findOne(Invoice, { order: orderId });
    return invoice ? toDto(invoice) : null;
  }

  async forOrder(orderId: string, buyerId: string): Promise<Invoice> {
    const invoice = await this.em.findOne(Invoice, { order: orderId, buyer: buyerId });
    if (!invoice) throw new NotFoundException();
    return invoice;
  }

  // Buyers see their own invoices; store members see their store's; support and finance see all.
  private async canView(user: AuthUser, invoice: Invoice): Promise<boolean> {
    if (user.roles.includes('support') || user.roles.includes('finance')) return true;
    if (invoice.buyer?.id === user.id) return true;
    const membership = await this.em.findOne(StoreMember, { store: invoice.store, user: user.id }, { fields: ['id'] });
    return membership !== null;
  }
}
