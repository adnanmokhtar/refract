import { Injectable, NotFoundException } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { ListOrdersQuery } from '@orderly/contracts';
import { currentTenant } from '../../shared/tenancy/tenant.filter';
import { Order } from './order.entity';

@Injectable()
export class OrdersService {
  constructor(private readonly em: EntityManager) {}

  async list(query: ListOrdersQuery): Promise<{ items: Order[]; next: string | null }> {
    const items = await this.em.find(
      Order,
      { tenantId: currentTenant(), ...(query.after ? { id: { $gt: query.after } } : {}) },
      { orderBy: { id: 'asc' }, limit: query.limit },
    );
    return { items, next: items.length === query.limit ? items[items.length - 1].id : null };
  }

  async get(id: string): Promise<Order> {
    const order = await this.em.findOne(Order, { id, tenantId: currentTenant() });
    if (!order) {
      throw new NotFoundException(`order ${id} not found`);
    }
    return order;
  }

  async save(order: Order): Promise<Order> {
    await this.em.persistAndFlush(order);
    return order;
  }
}
