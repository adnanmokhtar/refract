import { Injectable } from '@nestjs/common';
import { Order } from '../orders/order.entity';

@Injectable()
export class WarehouseClient {
  private readonly endpoint = process.env.WAREHOUSE_URL ?? 'http://warehouse.internal:8080';

  async upsertOrders(rows: Order[]): Promise<void> {
    const res = await fetch(`${this.endpoint}/v1/orders:upsert`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(rows.map((o) => ({ id: o.id, status: o.status, total_minor: o.totalMinor, updated_at: o.updatedAt }))),
    });
    if (!res.ok) {
      throw new Error(`warehouse upsert failed: ${res.status}`);
    }
  }
}
