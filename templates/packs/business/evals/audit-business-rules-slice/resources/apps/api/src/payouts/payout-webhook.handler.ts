import { Injectable } from '@nestjs/common';
import type Stripe from 'stripe';
import { PayoutService } from './payout.service';

/**
 * Connect payout events. The endpoint is subscribed to every payout.* type; the ones we do not act on
 * are listed so a new subscription cannot fall through silently.
 */
const IGNORED_EVENT_TYPES = ['payout.created', 'payout.updated', 'payout.reconciliation_completed'];

@Injectable()
export class PayoutWebhookHandler {
  constructor(private readonly payouts: PayoutService) {}

  async handle(event: Stripe.Event): Promise<void> {
    if (IGNORED_EVENT_TYPES.includes(event.type)) return;
    switch (event.type) {
      case 'payout.paid':
        return this.markPaid(event.data.object as Stripe.Payout);
      case 'payout.failed':
        return this.markFailed(event.data.object as Stripe.Payout);
      default:
        throw new Error(`unmapped payout event ${event.type}`);
    }
  }

  private async markPaid(p: Stripe.Payout) {}
  private async markFailed(p: Stripe.Payout) {}
}
