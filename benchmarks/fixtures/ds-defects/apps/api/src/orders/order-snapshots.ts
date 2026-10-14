import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { OrderAggregate } from './order.aggregate';

/** Every 200 events the order's state is snapshotted, so a long-lived B2B order loads in one read. */
@Injectable()
export class OrderSnapshots {
  constructor(private readonly em: EntityManager) {}

  async saveSnapshot(order: OrderAggregate): Promise<void> {
    const state = { status: order.status, parcels: order.parcels, trackingNo: order.trackingNo };
    await this.em.getConnection().execute(
      'INSERT INTO order_snapshots (stream_id, state, taken_at) VALUES (?, ?, now()) ON CONFLICT (stream_id) DO UPDATE SET state = EXCLUDED.state, taken_at = now()',
      [`order-${order.id}`, JSON.stringify(state)],
    );
  }

  async loadSnapshot(orderId: string): Promise<Record<string, unknown> | undefined> {
    const rows = await this.em.getConnection().execute<{ state: string }[]>('SELECT state FROM order_snapshots WHERE stream_id = ?', [`order-${orderId}`]);
    return rows[0] ? JSON.parse(rows[0].state) : undefined;
  }
}
