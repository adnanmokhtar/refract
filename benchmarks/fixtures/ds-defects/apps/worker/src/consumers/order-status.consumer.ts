import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { KafkaMessage } from 'kafkajs';
import { z } from 'zod';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';

const OrderStatusChanged = z.object({ orderId: z.string().uuid(), status: z.enum(['placed', 'picking', 'packed', 'shipped', 'cancelled']) });

/**
 * Keeps worker_orders.status in step with the order lifecycle (topic order.status, keyed by order id).
 * The status column drives the warehouse screens and the SLA timers.
 */
@Injectable()
export class OrderStatusConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-order-status' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['order.status'] });
    await consumer.run({
      eachBatch: async ({ batch, heartbeat, isRunning, isStale }) => {
        if (!isRunning() || isStale()) return;
        await Promise.all(batch.messages.map((m) => this.apply(batch.topic, m)));
        await heartbeat();
      },
    });
  }

  private async apply(topic: string, message: KafkaMessage): Promise<void> {
    const parsed = OrderStatusChanged.safeParse(JSON.parse(message.value?.toString() ?? 'null'));
    if (!parsed.success) return deadLetter(topic, message, parsed.error);
    await this.em.fork().getConnection().execute('UPDATE worker_orders SET status = ? WHERE id = ?', [parsed.data.status, parsed.data.orderId]);
  }
}
