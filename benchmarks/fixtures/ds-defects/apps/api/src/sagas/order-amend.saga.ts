import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from '../orders/order.entity';
import { WmsClient } from './clients/wms.client';

/**
 * A merchant amends an order's lines before picking starts: the pick wave is replaced, then the order row is
 * rewritten. The warehouse moves orders to 'picking' on its own (WMS webhook → OrderStatusWebhook).
 */
@Injectable()
export class OrderAmendSaga {
  constructor(
    private readonly em: EntityManager,
    private readonly wms: WmsClient,
  ) {}

  async run(orderId: string, lines: Array<{ sku: string; qty: number }>): Promise<void> {
    const compensations: Array<() => Promise<void>> = [];
    const em = this.em.fork();
    const order = await em.findOneOrFail(Order, orderId);
    const previous = order.lines;
    try {
      compensations.unshift(() => this.wms.createPickWave(orderId, previous));
      await this.wms.createPickWave(orderId, lines);
      order.lines = lines;
      order.status = 'placed';
      await em.flush();
    } catch (err) {
      for (const undo of compensations) await undo();
      throw err;
    }
  }
}
