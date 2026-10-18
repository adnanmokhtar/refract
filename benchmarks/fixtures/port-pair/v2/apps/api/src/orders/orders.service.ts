import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { type CreateOrderBodyT, ORDER_CANCELLED, type OrderListQueryT, type UpdateOrderBodyT } from '@norrow/contracts';
import type { AuthUser } from '../common/current-user.decorator';
import { definedOnly } from '../common/defined-only';
import { DomainError } from '../common/errors';
import { toOffset, toPage } from '../common/pagination';
import { toOrderDto } from './order.mapper';
import { Order } from './order.entity';
import { OrderPlacementService } from './order-placement.service';

@Injectable()
export class OrdersService {
  constructor(private readonly em: EntityManager, private readonly placement: OrderPlacementService) {}

  async list(query: OrderListQueryT) {
    const where = query.status?.length ? { status: { $in: query.status } } : {};
    const offset = toOffset(query.page, query.per_page);
    const [items, total] = await this.em.findAndCount(Order, where, { limit: query.per_page, offset, populate: ['lines'] });
    return toPage(items.map(toOrderDto), total, query.page, query.per_page);
  }

  async create(body: CreateOrderBodyT, user: AuthUser) {
    return { data: toOrderDto(await this.placement.place(body, user)) };
  }

  async get(id: number) {
    return { data: toOrderDto(await this.em.findOneOrFail(Order, id, { populate: ['lines'] })) };
  }

  async update(id: number, body: UpdateOrderBodyT) {
    const order = await this.em.findOneOrFail(Order, id);
    if (order.status !== 'draft') {
      throw new DomainError(400, 'Order is not editable');
    }

    this.em.assign(order, definedOnly({ poNumber: body.po_number, notes: body.notes }));
    await this.em.flush();
    return { data: toOrderDto(order) };
  }

  async cancel(id: number) {
    const order = await this.em.findOneOrFail(Order, id);
    order.status = ORDER_CANCELLED;
    await this.em.flush();
    return { data: toOrderDto(order) };
  }

  // Ported with the placement service; the controller exposes create, update and cancel.
  async duplicate(id: number, user: AuthUser) {
    const order = await this.em.findOneOrFail(Order, id, { populate: ['lines'] });
    const copy = await this.placement.place(
      {
        po_number: null,
        notes: order.notes,
        currency: order.currency as 'SAR' | 'AED',
        lines: order.lines.getItems().map((l) => ({ sku: l.sku, quantity: l.quantity, unit_price: Number(l.unitPrice), discount_rate: l.discountRate ? Number(l.discountRate) : null })),
      },
      user,
    );
    return { data: toOrderDto(copy) };
  }

  async exportCsv(): Promise<string> {
    const rows = await this.em.find(Order, {}, { orderBy: { id: 'asc' } });
    return ['number,status,currency,total', ...rows.map((o) => [o.number, o.status, o.currency, o.totalAmount].join(','))].join('\n');
  }
}
