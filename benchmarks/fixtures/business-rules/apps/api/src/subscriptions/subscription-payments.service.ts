import { Injectable, PaymentRequiredException } from '@nestjs/common';
import { stripe } from '../payments/stripe.client';

@Injectable()
export class SubscriptionPaymentsService {
  /** Charges the stored card for a seat-plan renewal; a decline leaves the subscription past_due. */
  async chargeRenewal(customerId: string, paymentMethodId: string, amountMinor: number) {
    const intent = await stripe.paymentIntents.create({
      customer: customerId,
      payment_method: paymentMethodId,
      amount: amountMinor,
      currency: 'usd',
      off_session: true,
      confirm: true,
    });
    if (intent.status !== 'succeeded') {
      throw new PaymentRequiredException('Declined card: contact support to update your billing details');
    }
    return intent;
  }
}
