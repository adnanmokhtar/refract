import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from '../orders/order.entity';
import { Refund } from './refund.entity';
import { PaymentGateway } from './payment-gateway.port';
import { refundWindowFor } from './refund-window';

export class RefundWindowExpiredError extends Error {
  constructor(readonly orderId: string, readonly window: string) {
    super(`order ${orderId}: the ${window} refund window has closed`);
  }
}

export class PartialRefundExceedsCaptureError extends Error {
  constructor(readonly orderId: string, readonly refundableCents: number) {
    super(`order ${orderId}: at most ${refundableCents} cents can still be refunded`);
  }
}

@Injectable()
export class RefundService {
  constructor(
    private readonly em: EntityManager,
    private readonly gateway: PaymentGateway,
  ) {}

  async refund(orderId: string, amountCents: number, reason: string): Promise<Refund> {
    const order = await this.em.findOneOrFail(Order, { id: orderId }, { populate: ['refunds', 'merchant'] });
    const window = refundWindowFor(order.merchant.policy);
    if (Date.now() > order.deliveredAt.getTime() + window.ms) {
      throw new RefundWindowExpiredError(order.id, window.label);
    }

    const alreadyRefunded = order.refunds.getItems().reduce((sum, r) => sum + r.amountCents, 0);
    if (alreadyRefunded + amountCents > order.capturedCents) {
      throw new PartialRefundExceedsCaptureError(order.id, order.capturedCents - alreadyRefunded);
    }

    const providerRef = await this.gateway.refundCapture(order.paymentRef, amountCents);
    const refund = this.em.create(Refund, { order, amountCents, reason, providerRef, status: 'succeeded' });
    await this.em.flush();
    return refund;
  }
}
