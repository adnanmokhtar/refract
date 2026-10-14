import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';

const StockSnapshot = z.object({ warehouseId: z.string(), sku: z.string(), onHand: z.number().int(), takenAt: z.string() });

/**
 * Loads the WMS's stock snapshots (topic wms.stock-snapshots, ~2 k messages per batch at the hourly dump).
 * Each message upserts one row and recomputes the SKU's availability (about 150 ms per message, p99 400 ms).
 */
@Injectable()
export class InventorySnapshotsConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-inventory-snapshots', sessionTimeout: 30_000 });
    await consumer.connect();
    await consumer.subscribe({ topics: ['wms.stock-snapshots'] });
    await consumer.run({
      eachBatchAutoResolve: false,
      eachBatch: async ({ batch, resolveOffset }) => {
        for (const message of batch.messages) {
          const parsed = StockSnapshot.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
          if (!parsed.success) {
            await deadLetter(batch.topic, message, parsed.error);
          } else {
            await this.applySnapshot(parsed.data);
          }
          resolveOffset(message.offset);
        }
      },
    });
  }

  private async applySnapshot(s: z.infer<typeof StockSnapshot>): Promise<void> {
    const conn = this.em.fork().getConnection();
    await conn.execute(
      'INSERT INTO stock_levels (warehouse_id, sku, on_hand, taken_at) VALUES (?, ?, ?, ?) ON CONFLICT (warehouse_id, sku) DO UPDATE SET on_hand = EXCLUDED.on_hand, taken_at = EXCLUDED.taken_at WHERE stock_levels.taken_at < EXCLUDED.taken_at',
      [s.warehouseId, s.sku, s.onHand, s.takenAt],
    );
    await conn.execute('SELECT recompute_availability(?)', [s.sku]);
  }
}
