import { Injectable, Logger } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from '../orders/order.entity';
import { CheckpointStore } from './checkpoint.store';
import { WarehouseClient } from './warehouse.client';

const BATCH = 500;

/** Every 5 minutes: copy orders changed since the last checkpoint into the warehouse. */
@Injectable()
export class OrderSyncJob {
  private readonly log = new Logger(OrderSyncJob.name);

  constructor(
    private readonly em: EntityManager,
    private readonly checkpoints: CheckpointStore,
    private readonly warehouse: WarehouseClient,
  ) {}

  async run(): Promise<void> {
    let after = await this.checkpoints.get('orders');
    let copied = 0;
    for (;;) {
      const rows = await this.em.fork().find(Order, { updatedAt: { $gte: after } }, { limit: BATCH, orderBy: { updatedAt: 'asc' } });
      const last = rows.at(-1);
      if (!last) break;
      await this.warehouse.upsertOrders(rows);
      copied += rows.length;
      after = last.updatedAt;
      await this.checkpoints.set('orders', after);
    }
    this.log.log(`order sync copied ${copied} rows`);
  }
}
