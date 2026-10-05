import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refund, refundsFor, seed, setup } from './_support.js';

test('HO-UNPAID an unpaid order cannot be refunded', async () => {
  const app = setup();
  const order = seed(app, 'acme', { paid: false });
  const res = await refund(app, 'acme', order);
  assert.ok(res.status >= 400 && res.status < 500, `refund of a pending order answered ${res.status}`);
  assert.equal(refundsFor(app, order.id, order).length, 0);
});
