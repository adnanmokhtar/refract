import { returnPickupTier } from './shipping-tier';

describe('returnPickupTier', () => {
  it('sends a fragile parcel express whatever it weighs', () => {
    expect(returnPickupTier(300, true)).toBe('express');
  });

  it.only('sends a heavy parcel express', () => {
    expect(returnPickupTier(12_000, false)).toBe('express');
  });

  it('sends a letter economy', () => {
    expect(returnPickupTier(120, false)).toBe('economy');
  });

  it('sends everything else standard', () => {
    expect(returnPickupTier(2_400, false)).toBe('standard');
  });
});
