import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { CursorStore } from './cursor-store';
import { PartnerFeed } from '../clients/partner-feed';

/**
 * The partner feed: every order created since the last run, by id. orders.id is a UUIDv7 minted by the api
 * replicas (uuid v7, each pod's clock) before the insert commits.
 */
@Injectable()
export class OrderFeedCursor {
  constructor(
    private readonly pool: Pool,
    private readonly cursors: CursorStore,
    private readonly feed: PartnerFeed,
  ) {}

  @Interval(5_000)
  async tick(): Promise<void> {
    const floor = (await this.cursors.get('partner-order-feed')) ?? '00000000-0000-7000-8000-000000000000';
    const { rows } = await this.pool.query<{ id: string; merchant_id: string }>(
      'SELECT id, merchant_id FROM orders WHERE id > $1 ORDER BY id LIMIT 1000',
      [floor],
    );
    if (rows.length === 0) return;
    await this.feed.publish(rows);
    await this.cursors.set('partner-order-feed', rows[rows.length - 1].id);
  }
}
