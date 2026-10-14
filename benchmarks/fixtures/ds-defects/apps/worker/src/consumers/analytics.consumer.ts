import { Injectable, OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';
import { Warehouse } from '../clients/warehouse-analytics';

const Placed = z.object({ orderId: z.string(), merchantId: z.string(), placedAt: z.string() });

/** Streams placed orders into the analytics warehouse (ClickHouse, ReplacingMergeTree on order_id). */
@Injectable()
export class AnalyticsConsumer implements OnModuleInit {
  constructor(private readonly warehouse: Warehouse) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-analytics' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['orders.placed'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        const parsed = Placed.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return deadLetter(topic, message, parsed.error);
        await this.warehouse.insertOrder(parsed.data);
      },
    });
  }
}
