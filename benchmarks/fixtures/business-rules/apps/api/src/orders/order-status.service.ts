import { ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from './order.entity';
import { OrderStatus, allowedFrom } from './order-status';
import { OrderStatusHistory } from './order-status-history.entity';

@Injectable()
export class OrderStatusService {
  constructor(private readonly em: EntityManager) {}

  async setStatus(order: Order, to: OrderStatus, actor: string): Promise<void> {
    const from = order.status;
    if (!allowedFrom(from).includes(to)) {
      throw new ConflictException(`order ${order.id}: ${from} → ${to} is not allowed`);
    }
    order.status = to;
    this.em.persist(this.em.create(OrderStatusHistory, { order, from, to, actor, at: new Date() }));
    await this.em.flush();
  }
}
