import { roundHalfAwayFromZero } from '../money/money-policy';
import type { Promotion } from '../promotions/promotion.entity';

/**
 * Item promotions (catalog sales) — the declared first step of ai/business-domain.md § Money policy.
 * Each promotion carries `stackable`; a non-stackable promotion is skipped when one already applied.
 * The order-level coupon is applied later, once, by applyOrderCoupon().
 */
export function applyItemPromotions(lineMinor: number, promotions: Promotion[]): number {
  let applied = false;
  let total = lineMinor;
  for (const p of [...promotions].sort((a, b) => a.priority - b.priority)) {
    if (applied && !p.stackable) continue;
    const discount = roundHalfAwayFromZero((lineMinor * p.discountBp) / 10_000);
    total -= discount;
    applied = true;
  }
  return Math.max(0, total);
}
