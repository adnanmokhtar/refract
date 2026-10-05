import { PriceCache } from './price-cache';

describe('PriceCache', () => {
  let clock = 0;
  const cache = new PriceCache(60_000, () => clock);

  beforeEach(() => {
    clock = 1_000;
  });

  it('serves a price it was given', () => {
    cache.set('MUG-01', 1_299);
    expect(cache.get('MUG-01')).toEqual({ sku: 'MUG-01', unitCents: 1_299, cachedAt: 1_000 });
  });

  it('keeps an entry until its ttl has passed', () => {
    cache.set('TEA-12', 845);
    clock += 60_000;
    expect(cache.get('TEA-12')).toBeDefined();
  });

  it('forgets an entry once the ttl has passed', () => {
    cache.set('JAM-03', 420);
    clock += 60_001;
    expect(cache.get('JAM-03')).toBeUndefined();
  });
});
