import { EntityManager, type EntityName, type EventArgs, type EventSubscriber } from '@mikro-orm/core';
import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { Order } from './order.entity';

// The V2 side of V1's OrderObserver (app/Observers/OrderObserver.php).
@Injectable()
export class OrderSubscriber implements EventSubscriber<Order> {
  constructor(em: EntityManager, @InjectQueue('mail') private readonly mail: Queue) {
    em.getEventManager().registerSubscriber(this);
  }

  getSubscribedEntities(): EntityName<Order>[] {
    return [Order];
  }

  async afterCreate(args: EventArgs<Order>): Promise<void> {
    await this.mail.add('order-placed', { orderId: args.entity.id, to: args.entity.customerEmail });
  }
}
