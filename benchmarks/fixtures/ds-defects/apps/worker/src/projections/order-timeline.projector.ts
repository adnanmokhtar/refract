import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';

/**
 * Builds each merchant's activity timeline from order_events (B2B, Postgres): the events of all of the merchant's
 * order streams, interleaved in the order they happened. The EDI importers on four worker pods write the streams.
 */
@Injectable()
export class OrderTimelineProjector {
  private lastCreatedAt = new Date(0);

  constructor(private readonly pool: Pool) {}

  @Interval(3_000)
  async tick(): Promise<void> {
    const { rows } = await this.pool.query<{ stream_id: string; type: string; data: unknown; created_at: Date }>(
      'SELECT stream_id, type, data, created_at FROM order_events WHERE created_at > $1 ORDER BY created_at LIMIT 500',
      [this.lastCreatedAt],
    );
    for (const e of rows) {
      await this.pool.query(
        'INSERT INTO order_timeline (stream_id, type, data, at) VALUES ($1, $2, $3, $4) ON CONFLICT (stream_id, type, at) DO NOTHING',
        [e.stream_id, e.type, e.data, e.created_at],
      );
      this.lastCreatedAt = e.created_at;
    }
  }
}
