import { Coupon } from '../promotions/coupon.entity';

/**
 * Applies the coupons a shopper entered at checkout, in the order the request lists them.
 * Used by the cart preview and by CheckoutService when the order is placed.
 */
export function applyCoupons(subtotalMinor: number, coupons: Coupon[]): number {
  let total = subtotalMinor;
  for (const c of coupons) {
    const { kind, percentOff, amountOffMinor } = c;
    total = kind === 'percent' ? total * (1 - percentOff / 100) : total - amountOffMinor;
  }
  return Math.round(total);
}
