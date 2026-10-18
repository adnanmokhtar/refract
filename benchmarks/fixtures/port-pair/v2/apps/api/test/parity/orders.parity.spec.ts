import { expect, it } from 'vitest';
import { corpus, tolerance } from './support/harness';
import { describeV1 } from './support/v1';
import { replay } from './support/replay';

describeV1('orders HTTP parity', () => {
  it('answers every recorded V1 orders request the same way', async () => {
    for (const req of corpus<{ method: string; path: string; body?: unknown }>('orders-http')) {
      const [a, b] = await replay(req);
      expect(b.status).toBe(a.status);
      if (tolerance.compare.orders === 'status+body') {
        expect(b.body).toEqual(a.body);
      }
    }
  });
});
