export interface CartLine {
  sku: string;
  unitCents: number;
  quantity: number;
}

export interface Cart {
  lines: CartLine[];
  couponPercent?: number;
}

// A coupon applies to the merchandise subtotal, rounded down to the cent; it never makes a cart negative.
export function applyDiscount(cart: Cart): number {
  const subtotal = cart.lines.reduce((sum, line) => sum + line.unitCents * line.quantity, 0);
  if (!cart.couponPercent) return subtotal;
  const discount = Math.floor((subtotal * cart.couponPercent) / 100);
  return Math.max(0, subtotal - discount);
}
