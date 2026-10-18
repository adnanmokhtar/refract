import { expect, it } from 'vitest';
import { replay } from './support/replay';
import { describeV1 } from './support/v1';

// Moved 1:1 from v1/tests/Feature/WalletAdjustTest.php (ai/migration/test-map.tsv, row wallets-adjust):
// same request, same expected status and balance; only the harness changed.
describeV1('wallet adjust parity', () => {
  it('posts a transaction and logs activity like V1', async () => {
    const [a, b] = await replay({ method: 'POST', path: '/api/wallets/1/adjust', body: { amount_minor: -2500, reason: 'damaged goods' } });
    expect(b.status).toBe(a.status);
    expect(b.body).toEqual(a.body);
  });
});
