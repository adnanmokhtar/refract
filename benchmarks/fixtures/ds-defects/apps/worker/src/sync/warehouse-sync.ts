import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { WmsOrders } from '../clients/wms-orders';
import { CursorStore } from './cursor-store';

/**
 * Feeds B2B order events to the WMS. order_events.id is a bigserial; every EDI importer (4 worker pods, each in
 * its own transaction) appends to it. The checkpoint is the last id sent.
 */
@Injectable()
export class WarehouseSync {
  constructor(
    private readonly pool: Pool,
    private readonly wms: WmsOrders,
    private readonly cursors: CursorStore,
  ) {}

  @Interval(2_000)
  async tick(): Promise<void> {
    const checkpoint = await this.cursors.get('warehouse-sync');
    const { rows } = await this.pool.query<{ id: string; stream_id: string; type: string; data: unknown }>(
      'SELECT id, stream_id, type, data FROM order_events WHERE id > $1 ORDER BY id LIMIT 500',
      [checkpoint ?? '0'],
    );
    if (rows.length === 0) return;
    await this.wms.sendEvents(rows);
    await this.cursors.set('warehouse-sync', rows[rows.length - 1].id);
  }
}
