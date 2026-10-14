import { Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Producer } from 'kafkajs';
import { Order } from './order.entity';
import { KAFKA_PRODUCER } from '../kafka/kafka.module';

/** The warehouse stops picking and the carrier booking is voided when they see orders.cancelled. */
@Injectable()
export class CancelOrder {
  constructor(
    private readonly em: EntityManager,
    @Inject(KAFKA_PRODUCER) private readonly kafka: Producer,
  ) {}

  async execute(orderId: string, reason: string): Promise<void> {
    const order = await this.em.findOneOrFail(Order, orderId);
    order.assertCancellable();
    await this.kafka.send({ topic: 'orders.cancelled', messages: [{ key: order.id, value: JSON.stringify({ type: 'OrderCancelled', orderId, reason }) }] });
    order.status = 'cancelled';
    await this.em.flush();
  }
}
