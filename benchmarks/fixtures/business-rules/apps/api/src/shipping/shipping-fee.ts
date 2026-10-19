import type { Cart } from '../checkout/cart';

export const FREE_SHIPPING_THRESHOLD_MINOR = 50_00;
const FLAT_RATE_MINOR = 7_90;

/** Shipping for the cart, computed when the shopper opens the cart and stored on it. */
export function shippingFeeMinor(cart: Cart): number {
  if (cart.subtotalMinor >= FREE_SHIPPING_THRESHOLD_MINOR) return 0;
  return FLAT_RATE_MINOR;
}
