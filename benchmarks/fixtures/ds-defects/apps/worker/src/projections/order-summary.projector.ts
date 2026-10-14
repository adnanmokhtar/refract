import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { Checkpoints } from './checkpoints';

/** order_summary: the admin order list (apps/api /admin/orders reads it). Projected from the order streams. */
@Injectable()
export class OrderSummaryProjector {
  constructor(
    private readonly pool: Pool,
    private readonly checkpoints: Checkpoints,
  ) {}

  @Interval(1_000)
  async tick(): Promise<void> {
    const from = await this.checkpoints.load('order-summary');
    const events = await this.checkpoints.readCategory('order', from, 500);
    if (events.length === 0) return;
    await this.checkpoints.save('order-summary', events[events.length - 1].position);
    for (const evt of events) {
      await this.pool.query(
        `INSERT INTO order_summary (order_id, status, updated_position) VALUES ($1, $2, $3)
         ON CONFLICT (order_id) DO UPDATE SET status = EXCLUDED.status, updated_position = EXCLUDED.updated_position
         WHERE order_summary.updated_position < EXCLUDED.updated_position`,
        [evt.data.orderId, evt.type, evt.position],
      );
    }
  }
}
