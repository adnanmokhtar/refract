export interface Coupon {
  code: string;
  percentOff: number;
  expiresAt: string; // ISO date, the last day the coupon can be redeemed (inclusive)
  maxRedemptions: number;
  redemptions: number;
}

export type RedeemRefusal = 'expired' | 'exhausted' | null;

// Store credit issued with a refund is a coupon; it is redeemable through the end of its expiry day (UTC).
export function redeemRefusal(coupon: Coupon): RedeemRefusal {
  const endOfExpiryDay = Date.parse(`${coupon.expiresAt}T23:59:59.999Z`);
  if (Date.now() > endOfExpiryDay) return 'expired';
  if (coupon.redemptions >= coupon.maxRedemptions) return 'exhausted';
  return null;
}
