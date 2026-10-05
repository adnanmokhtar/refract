import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from './order.entity';

@Injectable()
export class OrderRepository {
  constructor(private readonly em: EntityManager) {}

  // Scoped by tenant: an order of another tenant is "not found", never "forbidden".
  findOneOrFail(tenantId: string, id: string): Promise<Order> {
    return this.em.findOneOrFail(Order, { id, tenantId }, { populate: ['refunds'] });
  }

  findRecent(tenantId: string, limit = 20): Promise<Order[]> {
    return this.em.find(Order, { tenantId }, { orderBy: { deliveredAt: 'desc' }, limit });
  }
}
