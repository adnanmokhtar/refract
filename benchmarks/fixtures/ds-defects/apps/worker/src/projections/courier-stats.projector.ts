import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { Checkpoints } from './checkpoints';

/** Deliveries per courier for the courier leaderboard, projected from the delivered events (KurrentDB $ce-delivery). */
@Injectable()
export class CourierStatsProjector {
  constructor(
    private readonly pool: Pool,
    private readonly checkpoints: Checkpoints,
  ) {}

  @Interval(2_000)
  async tick(): Promise<void> {
    const from = await this.checkpoints.load('courier-stats');
    for (const evt of await this.checkpoints.readCategory('delivery', from, 200)) {
      await this.pool.query('UPDATE courier_stats SET deliveries = deliveries + 1 WHERE courier_id = $1', [evt.data.courierId]);
      await this.checkpoints.save('courier-stats', evt.position);
    }
  }
}
