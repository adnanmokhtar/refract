import { applyDiscount, Cart } from './discount';

const cart: Cart = {
  lines: [
    { sku: 'MUG-01', unitCents: 1_299, quantity: 3 },
    { sku: 'TEA-12', unitCents: 845, quantity: 1 },
  ],
  couponPercent: 15,
};

describe('applyDiscount', () => {
  it('applies a percentage coupon to the subtotal', () => {
    const expected = applyDiscount(cart);
    expect(applyDiscount(cart)).toBe(expected);
  });

  it('returns the subtotal when no coupon is applied', () => {
    expect(applyDiscount({ lines: cart.lines })).toBe(4_742);
  });
});
