import { Injectable, OnModuleInit } from '@nestjs/common';
import { Kafka } from 'kafkajs';
import { EntityManager } from '@mikro-orm/postgresql';
import { z } from 'zod';
import { DeadLetters } from '../kafka/dead-letters';

const OrderPlacedEvent = z.object({ orderId: z.string(), merchantId: z.string() });

/** Merchant milestones ("1,000 orders shipped with Acme") count the orders each merchant placed. */
@Injectable()
export class MilestonesConsumer implements OnModuleInit {
  constructor(
    private readonly kafka: Kafka,
    private readonly em: EntityManager,
    private readonly deadLetters: DeadLetters,
  ) {}

  async onModuleInit(): Promise<void> {
    const consumer = this.kafka.consumer({ groupId: 'api-milestones' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['order.placed'] });
    await consumer.run({
      eachMessage: async ({ message }) => {
        const parsed = OrderPlacedEvent.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
        if (!parsed.success) return this.deadLetters.park('order.placed', message);
        await this.em.getConnection().execute(
          'INSERT INTO merchant_order_counts (merchant_id, order_id) VALUES (?, ?) ON CONFLICT DO NOTHING',
          [parsed.data.merchantId, parsed.data.orderId],
        );
      },
    });
  }
}
