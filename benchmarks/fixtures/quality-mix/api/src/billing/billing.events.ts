import { BillingService } from './billing.service';

// Event names for listeners. Kept next to the service so the names cannot drift.
export const BILLING_EVENTS = {
  renewed: BillingService.RENEWED,
  renewalFailed: BillingService.RENEWAL_FAILED,
} as const;

export interface RenewedEvent {
  subscriptionId: string;
  chargeId: string;
  amountCents: number;
}
