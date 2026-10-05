import { Coupon, redeemRefusal } from './coupon';

const storeCredit: Coupon = {
  code: 'CREDIT-7Q2M',
  percentOff: 100,
  expiresAt: '2027-01-01',
  maxRedemptions: 1,
  redemptions: 0,
};

describe('redeemRefusal', () => {
  it('accepts unused store credit before it expires', () => {
    expect(redeemRefusal(storeCredit)).toBeNull();
  });

  it('refuses store credit that was already used', () => {
    expect(redeemRefusal({ ...storeCredit, redemptions: 1 })).toBe('exhausted');
  });

  it('refuses store credit after its expiry day', () => {
    expect(redeemRefusal({ ...storeCredit, expiresAt: '2025-12-31' })).toBe('expired');
  });

  it('still accepts store credit on its expiry day', () => {
    const today = new Date().toISOString().slice(0, 10);
    expect(redeemRefusal({ ...storeCredit, expiresAt: today })).toBeNull();
  });
});
