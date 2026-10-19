import type { PlanKey } from '@shelfwise/contracts';

/**
 * Billing config. `lookupKey` resolves the Stripe price in either mode; the limits are what the
 * API enforces (team.service reads maxSeats, stores.service reads maxStores).
 */
export const BILLING_PLANS: Record<PlanKey, { lookupKey: string; displayPrice: number; maxSeats: number; maxStores: number | null }> = {
  starter: { lookupKey: 'starter_monthly', displayPrice: 19, maxSeats: 2, maxStores: 1 },
  growth: { lookupKey: 'growth_monthly', displayPrice: 49, maxSeats: 5, maxStores: 3 },
  scale: { lookupKey: 'scale_monthly', displayPrice: 149, maxSeats: 25, maxStores: null },
};

export const CURRENCY = 'USD';
