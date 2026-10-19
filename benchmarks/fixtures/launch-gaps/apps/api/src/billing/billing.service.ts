import { Injectable } from '@nestjs/common';
import Stripe from 'stripe';
import { PlanKey } from '@shelfwise/contracts';
import { SubscriptionsService } from './subscriptions.service';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? '');

const PRICE_IDS: Record<PlanKey, string> = {
  starter: 'price_1PzK2sLmN4oQ8rT0uV3wX5yA',
  growth: 'price_1PzK3bLmN4oQ8rT0aB7cD9eF',
  scale: 'price_1PzK3xLmN4oQ8rT0gH2iJ4kL',
};

@Injectable()
export class BillingService {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  async createCheckout(tenantId: string, plan: PlanKey) {
    const customer = await this.subscriptions.customerFor(tenantId);
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer,
      line_items: [{ price: PRICE_IDS[plan], quantity: 1 }],
      success_url: `${process.env.APP_URL}/billing/upgrade?status=success`,
      cancel_url: `${process.env.APP_URL}/billing/upgrade?status=cancelled`,
      metadata: { tenantId, plan },
    });
    return { url: session.url };
  }

  extendTrial(tenantId: string, days: number) {
    return this.subscriptions.extendTrial(tenantId, days);
  }

  async validateCoupon(code: string) {
    const promo = await stripe.promotionCodes.list({ code, active: true, limit: 1 });
    return { valid: promo.data.length === 1, percentOff: promo.data[0]?.coupon.percent_off ?? null };
  }
}
