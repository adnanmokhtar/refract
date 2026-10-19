import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Payment, PaymentStatus } from './payment.entity';
import { PaymentPostings } from '../accounting/payment-postings';

@Injectable()
export class PaymentCaptureService {
  constructor(private readonly em: EntityManager, private readonly postings: PaymentPostings) {}

  /** Called by the Stripe webhook when the intent succeeded. */
  async onSucceeded(paymentId: string): Promise<void> {
    const payment = await this.em.findOneOrFail(Payment, paymentId, { populate: ['order'] });
    if (payment.status !== PaymentStatus.Pending) return;
    payment.status = PaymentStatus.Captured;
    await this.em.flush();
    await this.postings.onCaptured(payment);

    const order = payment.order;
    if (order.status !== 'pending_payment') return;
    order.status = 'paid';
    order.paidAt = new Date();
    await this.em.flush();
  }
}
