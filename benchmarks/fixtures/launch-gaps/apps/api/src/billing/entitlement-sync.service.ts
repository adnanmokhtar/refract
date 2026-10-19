import { Injectable } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import Stripe from 'stripe';
import { SubscriptionsService } from './subscriptions.service';

/**
 * Keeps tenant_extensions in step with Stripe Entitlements. Stripe sends the summary event
 * whenever a customer's active entitlements change.
 */
@Injectable()
export class EntitlementSyncService {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  @OnEvent('stripe.entitlements.active_entitlement_summary.updated')
  async onSummaryUpdated(event: Stripe.Event) {
    const summary = event.data.object as Stripe.Entitlements.ActiveEntitlementSummary;
    const slugs = summary.entitlements.data.map((e) => e.lookup_key);
    await this.subscriptions.grantExtensions(summary.customer, slugs);
  }
}
