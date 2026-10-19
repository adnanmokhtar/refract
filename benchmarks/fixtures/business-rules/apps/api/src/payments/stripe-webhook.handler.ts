import { Injectable } from '@nestjs/common';
import type Stripe from 'stripe';
import { PaymentCaptureService } from './payment-capture.service';

/**
 * POST /api/webhooks/stripe. The endpoint's subscribed event types are in infra/stripe/webhook-endpoint.json.
 */
@Injectable()
export class StripeWebhookHandler {
  constructor(private readonly capture: PaymentCaptureService) {}

  async handle(event: Stripe.Event): Promise<void> {
    switch (event.type) {
      case 'payment_intent.succeeded':
        return this.capture.onSucceeded((event.data.object as Stripe.PaymentIntent).metadata.paymentId);
      default:
        return;
    }
  }
}
