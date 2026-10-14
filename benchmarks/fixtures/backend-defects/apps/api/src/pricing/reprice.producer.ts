import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { EntityManager } from '@mikro-orm/core';
import { Order } from '../orders/order.entity';

@Injectable()
export class RepriceProducer {
  constructor(private readonly em: EntityManager, @InjectQueue('reprice') private readonly repriceQueue: Queue) {}

  /** After a price-list change, every open order is re-priced in the background. */
  async enqueueOpenOrders(tenantId: string): Promise<number> {
    const open = await this.em.find(Order, { tenantId, status: 'open' });
    for (const order of open) {
      await this.repriceQueue.add('reprice-order', order);
    }
    return open.length;
  }
}
