import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refund, refundsFor, seed, setup } from './_support.js';

test('HO-IDEMPOTENT the same Idempotency-Key twice records one refund and replays the first response', async () => {
  const app = setup();
  const order = seed(app, 'acme');
  const first = await refund(app, 'acme', order, { key: 'retry-after-timeout' });
  const again = await refund(app, 'acme', order, { key: 'retry-after-timeout' });
  assert.ok(first.status >= 200 && first.status < 300, `first refund answered ${first.status}`);
  assert.equal(again.status, first.status, 'a replay returns the first response, not an error');
  assert.equal(refundsFor(app, order.id, order).length, 1, 'one refund, however many retries');
});
