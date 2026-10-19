import { Injectable } from '@nestjs/common';
import { stripe } from '../payments/stripe.client';

@Injectable()
export class StripeRefundGateway {
  /**
   * Card refunds go through Stripe, which rejects a refund that would take the charge's refunded
   * total above the captured amount.
   */
  async refund(orderId: string, amountMinor: number) {
    return stripe.refunds.create({ payment_intent: await this.intentFor(orderId), amount: amountMinor });
  }

  private async intentFor(orderId: string): Promise<string> {
    return `pi_${orderId}`;
  }
}
