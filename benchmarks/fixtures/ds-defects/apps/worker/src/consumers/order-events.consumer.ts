import { Injectable, OnModuleInit } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { kafka } from '../kafka/kafka.provider';
import { deadLetter } from '../kafka/dead-letter';
import { OrderEvent } from './order-event.types';

/** Opens a fulfilment task for each placed order and closes it on cancellation. */
@Injectable()
export class OrderEventsConsumer implements OnModuleInit {
  constructor(private readonly em: EntityManager) {}

  async onModuleInit(): Promise<void> {
    const consumer = kafka.consumer({ groupId: 'worker-order-events' });
    await consumer.connect();
    await consumer.subscribe({ topics: ['orders.placed', 'orders.cancelled'] });
    await consumer.run({
      eachMessage: async ({ topic, message }) => {
        let evt: OrderEvent;
        try {
          evt = JSON.parse(message.value!.toString()) as OrderEvent;
        } catch (err) {
          return deadLetter(topic, message, err);
        }
        await this.route(evt);
      },
    });
  }

  private async route(evt: OrderEvent): Promise<void> {
    const conn = this.em.fork().getConnection();
    switch (evt.type) {
      case 'OrderPlaced':
        await conn.execute('INSERT INTO fulfilment_tasks (order_id, kind) VALUES (?, ?) ON CONFLICT DO NOTHING', [evt.orderId, 'pick']);
        return;
      case 'OrderCancelled':
        await conn.execute('UPDATE fulfilment_tasks SET closed_at = now() WHERE order_id = ?', [evt.orderId]);
        return;
      default: return assertNever(evt);
    }
  }
}

function assertNever(x: never): never {
  throw new Error(`Unknown order event: ${JSON.stringify(x)}`);
}
