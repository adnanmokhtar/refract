import { isRefundable, PolicyLine } from './refund-policy';

const line = (over: Partial<PolicyLine>): PolicyLine => ({
  sku: 'SKU-1',
  finalSale: false,
  category: 'apparel',
  daysSinceDelivery: 3,
  ...over,
});

describe('isRefundable', () => {
  it('never refunds a final-sale line', () => {
    expect(isRefundable(line({ finalSale: true }), 30)).toBe(false);
  });

  it('never refunds groceries', () => {
    expect(isRefundable(line({ category: 'grocery' }), 30)).toBe(false);
  });

  it('caps electronics at fourteen days even when the merchant allows more', () => {
    expect(isRefundable(line({ category: 'electronics', daysSinceDelivery: 15 }), 30)).toBe(false);
    expect(isRefundable(line({ category: 'electronics', daysSinceDelivery: 14 }), 30)).toBe(true);
  });

  it('uses the merchant window for apparel', () => {
    expect(isRefundable(line({ daysSinceDelivery: 30 }), 30)).toBe(true);
    expect(isRefundable(line({ daysSinceDelivery: 31 }), 30)).toBe(false);
  });
});
