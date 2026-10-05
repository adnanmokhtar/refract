import { FxRateClient } from './fx-rate.client';

jest.retryTimes(3);

describe('FxRateClient', () => {
  const client = new FxRateClient();

  it('quotes EUR to GBP at a plausible mid-market rate', async () => {
    const res = await fetch('https://api.exchangerate.host/latest?base=EUR&symbols=GBP');
    const body = await res.json();
    const fx = await client.quote('EUR', 'GBP');

    expect(fx.rate).toBeCloseTo(body.rates.GBP, 4);
    expect(fx.rate).toBeGreaterThan(0.5);
    expect(fx.rate).toBeLessThan(1.2);
  });

  it('converts a refund amount with the quoted rate', () => {
    const fx = { base: 'EUR', quote: 'GBP', rate: 0.8571, asOf: '2026-09-30' };
    expect(client.convert(10_000, fx)).toBe(8_571);
  });
});
