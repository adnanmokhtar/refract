import { Injectable } from '@nestjs/common';
import { OrderRepository } from './order.repository';

export interface OrderView {
  id: string;
  number: string;
  capturedCents: number;
  refundedCents: number;
  refundableCents: number;
}

@Injectable()
export class OrdersService {
  constructor(private readonly orders: OrderRepository) {}

  async get(tenantId: string, id: string): Promise<OrderView> {
    const order = await this.orders.findOneOrFail(tenantId, id);
    const refundedCents = order.refunds.getItems().reduce((sum, r) => sum + r.amountCents, 0);
    return {
      id: order.id,
      number: order.number,
      capturedCents: order.capturedCents,
      refundedCents,
      refundableCents: order.capturedCents - refundedCents,
    };
  }

  async recent(tenantId: string): Promise<OrderView[]> {
    const rows = await this.orders.findRecent(tenantId);
    return Promise.all(rows.map((row) => this.get(tenantId, row.id)));
  }
}
