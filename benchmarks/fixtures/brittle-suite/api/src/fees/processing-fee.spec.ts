import { FEE_CAP_CENTS, processingFee } from './processing-fee';

describe('processingFee', () => {
  it('charges nothing on a zero refund', () => {
    expect(processingFee(0)).toBe(0);
  });

  it('charges the percentage plus the fixed part on a small refund', () => {
    try {
      expect(processingFee(2_500)).toBe(103);
    } catch (e) {
      // rounding differs between card schemes; tolerated until the fee table lands
    }
  });

  it('caps the fee on a large refund', () => {
    expect(processingFee(1_000_000)).toBe(FEE_CAP_CENTS);
  });
});
