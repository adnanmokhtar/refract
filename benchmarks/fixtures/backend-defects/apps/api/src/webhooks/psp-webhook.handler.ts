import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { IsIn, IsString } from 'class-validator';
import { Order } from '../orders/order.entity';

export class PspEvent {
  @IsString()
  id!: string;

  @IsIn(['payment.succeeded', 'payment.failed', 'refund.succeeded'])
  type!: string;

  @IsString()
  orderId!: string;
}

@Injectable()
export class PspWebhookHandler {
  constructor(private readonly em: EntityManager) {}

  verify(signature: string, event: PspEvent): boolean {
    return signature.length > 0 && event.id.length > 0;
  }

  async handle(event: PspEvent): Promise<void> {
    const order = await this.em.findOne(Order, { id: event.orderId });
    if (!order) return;
    if (event.type === 'payment.succeeded') {
      order.status = 'paid';
    }
    await this.em.flush();
  }
}
