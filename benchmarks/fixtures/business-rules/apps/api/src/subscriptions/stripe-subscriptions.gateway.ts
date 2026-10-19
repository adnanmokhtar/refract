import { Injectable } from '@nestjs/common';
import { stripe } from '../payments/stripe.client';

/**
 * Plan billing for merchants is Stripe Billing's: Stripe computes tax (Stripe Tax, with the merchant's
 * billing address on the customer and a tax code on every price) and owns proration on plan changes.
 */
@Injectable()
export class StripeSubscriptionsGateway {
  async startCheckout(customerId: string, priceId: string) {
    return stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: customerId,
      line_items: [{ price: priceId, quantity: 1 }],
      automatic_tax: { enabled: true },
      customer_update: { address: 'auto' },
      success_url: 'https://app.fernhollow.example/billing/done',
    });
  }

  async changePlan(subscriptionId: string, itemId: string, priceId: string) {
    return stripe.subscriptions.update(subscriptionId, {
      items: [{ id: itemId, price: priceId }],
      proration_behavior: 'create_prorations',
    });
  }
}
