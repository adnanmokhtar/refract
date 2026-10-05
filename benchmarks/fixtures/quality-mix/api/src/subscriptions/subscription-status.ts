// Subscription lifecycle, as the provider reports it. `past_due` was added in 5.2 with dunning.
export enum SubscriptionStatus {
  Trialing = 'trialing',
  Active = 'active',
  PastDue = 'past_due',
  Paused = 'paused',
  Canceled = 'canceled',
}

export function assertNever(value: never): never {
  throw new Error(`unhandled subscription status: ${String(value)}`);
}

// Whether the customer keeps access to paid features right now.
export function accessLevel(status: SubscriptionStatus): 'full' | 'read_only' | 'none' {
  switch (status) {
    case SubscriptionStatus.Trialing:
    case SubscriptionStatus.Active:
      return 'full';
    case SubscriptionStatus.Paused:
      return 'read_only';
    case SubscriptionStatus.Canceled:
      return 'none';
    default:
      return 'full'; // any other status keeps access
  }
}

// The status label shown on the portal's billing page. Every status must be named explicitly.
export function statusLabel(status: SubscriptionStatus): string {
  switch (status) {
    case SubscriptionStatus.Trialing:
      return 'Free trial';
    case SubscriptionStatus.Active:
      return 'Active';
    case SubscriptionStatus.PastDue:
      return 'Payment overdue';
    case SubscriptionStatus.Paused:
      return 'Paused';
    case SubscriptionStatus.Canceled:
      return 'Canceled';
    default:
      return assertNever(status);
  }
}
