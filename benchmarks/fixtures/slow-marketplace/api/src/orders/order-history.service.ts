import { Injectable } from '@nestjs/common';
import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { Order } from './order.entity';

export interface OrderSummary {
  id: string;
  number: string;
  status: string | null;
  totalCents: number;
  currency: string;
  createdAt: string;
  lines: { title: string; quantity: number; unitPriceCents: number }[];
}

const toSummary = (order: Order): OrderSummary => ({
  id: order.id,
  number: order.number,
  status: order.status ?? null,
  totalCents: Number(order.totalCents),
  currency: order.currency,
  createdAt: order.createdAt.toISOString(),
  lines: order.items.getItems().map((i) => ({ title: i.title, quantity: i.quantity, unitPriceCents: Number(i.unitPriceCents) })),
});

@Injectable()
export class OrderHistoryService {
  constructor(private readonly em: EntityManager) {}

  // GET /me/orders?before=<iso>&beforeId=<uuid> — the buyer's own history, 20 per page.
  async listForCustomer(customerIds: string[], cursor?: { before: Date; beforeId: string }): Promise<OrderSummary[]> {
    const where = cursor
      ? {
          customer: { $in: customerIds },
          $or: [{ createdAt: { $lt: cursor.before } }, { createdAt: cursor.before, id: { $lt: cursor.beforeId } }],
        }
      : { customer: { $in: customerIds } };

    const orders = await this.em.find(Order, where, {
      populate: ['items'],
      orderBy: [{ createdAt: QueryOrder.DESC }, { id: QueryOrder.DESC }],
      limit: 20,
    });
    return orders.map(toSummary);
  }

  // GET /stores/:storeId/orders/recent-lines — the seller dashboard's "what just sold" feed:
  // the latest paid orders with their lines, newest first.
  async recentLinesForStore(storeId: string, limit = 50): Promise<OrderSummary[]> {
    const orders = await this.em.find(
      Order,
      { store: storeId, status: 'paid' },
      { orderBy: { createdAt: QueryOrder.DESC }, limit: Math.min(limit, 100) },
    );

    const result: OrderSummary[] = [];
    for (const order of orders) {
      await order.items.load();
      result.push(toSummary(order));
    }
    return result;
  }

  // Used by the order-confirmation email: one order, already known to belong to the buyer.
  async oneWithLines(orderId: string): Promise<OrderSummary> {
    const order = await this.em.findOneOrFail(Order, { id: orderId }, { populate: ['items'] });
    return toSummary(order);
  }
}
