import { Injectable } from '@nestjs/common';
import { jsonEvent, KurrentDBClient } from '@kurrent/kurrentdb-client';
import { OrderAggregate } from './order.aggregate';
import { CustomerMailer } from '../notifications/customer-mailer';

/** Loads an order from its stream, lets the command decide, appends what it decided. */
@Injectable()
export class OrderAggregateStore {
  constructor(
    private readonly client: KurrentDBClient,
    private readonly mailer: CustomerMailer,
  ) {}

  async execute(orderId: string, decide: (order: OrderAggregate) => void): Promise<void> {
    const stream = `order-${orderId}`;
    const history: object[] = [];
    for await (const resolved of this.client.readStream(stream)) {
      if (resolved.event) history.push(Object.assign(Object.create(null), resolved.event.data, { constructor: { name: resolved.event.type } }));
    }
    const order = new OrderAggregate(orderId, this.mailer);
    order.loadFromHistory(history);

    decide(order);
    const events = order.getUncommittedEvents().map((e) => jsonEvent({ type: e.constructor.name, data: { ...e } }));
    await this.client.appendToStream(stream, events);
    order.commit();
  }
}
