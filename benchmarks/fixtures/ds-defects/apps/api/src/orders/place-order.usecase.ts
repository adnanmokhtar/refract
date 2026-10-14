import { Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Producer } from 'kafkajs';
import { Order } from './order.entity';
import { KAFKA_PRODUCER } from '../kafka/kafka.module';

export interface PlaceOrderInput {
  merchantId: string;
  lines: Array<{ sku: string; qty: number }>;
  shipTo: Record<string, string>;
}

@Injectable()
export class PlaceOrder {
  constructor(
    private readonly em: EntityManager,
    @Inject(KAFKA_PRODUCER) private readonly kafka: Producer,
  ) {}

  async execute(input: PlaceOrderInput): Promise<Order> {
    const order = new Order(input.merchantId, input.lines, input.shipTo);
    this.em.persist(order);
    await this.em.flush();
    await this.kafka.send({ topic: 'orders.placed', messages: [{ key: order.id, value: JSON.stringify(order.toEvent()) }] });
    return order;
  }
}
