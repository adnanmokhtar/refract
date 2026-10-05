import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refund, refundsFor, seed, setup } from './_support.js';

test('HO-CANCELLED a cancelled order cannot be refunded', async () => {
  const app = setup();
  const order = seed(app, 'acme', { paid: false });
  const cancelled = await app.handle({
    method: 'POST',
    path: `/orders/${order.id}/cancel`,
    headers: { 'x-tenant-id': 'acme', 'idempotency-key': 'cancel-first' },
  });
  assert.equal(cancelled.status, 200);
  const res = await refund(app, 'acme', order);
  assert.ok(res.status >= 400 && res.status < 500, `refund of a cancelled order answered ${res.status}`);
  assert.equal(refundsFor(app, order.id, order).length, 0);
});
