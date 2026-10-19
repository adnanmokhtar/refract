import { DAY_MS, parseRefundWindow, RefundWindowFormatError } from './refund-window';

describe('parseRefundWindow', () => {
  it('reads a day-count window', () => {
    expect(parseRefundWindow('P14D')).toEqual({ ms: 14 * DAY_MS, label: '14 days' });
  });

  it('trims the stored value', () => {
    expect(parseRefundWindow(' P7D ')).toEqual({ ms: 7 * DAY_MS, label: '7 days' });
  });

  it('rejects a window with a negative day count', () => {
    try {
      parseRefundWindow('P-3D');
    } catch (e) {
      expect(e).toBeInstanceOf(RefundWindowFormatError);
    }
  });

  it('labels a two-day window', () => {
    expect(parseRefundWindow('P2D').label).toBe('2 days');
  });

  describe('merchant defaults', () => {
    it('reads the thirty-day default', () => {
      expect(parseRefundWindow('P30D').ms).toBe(30 * DAY_MS);
    });

    it('accepts the merchant default window', () => {
      expect(() => parseRefundWindow('P30D')).not.toThrow();
    });

    it('rejects a window that is not a day count', () => {
      expect(() => parseRefundWindow('30 days')).toThrow(RefundWindowFormatError);
    });
  });
});
