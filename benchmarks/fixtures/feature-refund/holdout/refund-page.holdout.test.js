import { test } from 'node:test';
import assert from 'node:assert/strict';
import { emptyStateMessages, refundControls, seed, setup } from './_support.js';

test('HO-EMPTY the order page offers a refund and shows the shared empty state while there are none', async () => {
  const app = setup();
  const order = seed(app, 'acme');
  const res = await app.handle({ method: 'GET', path: `/pages/orders/${order.id}`, headers: { 'x-tenant-id': 'acme' } });
  assert.equal(res.status, 200);
  assert.ok(refundControls(res.body) > 0, 'a paid order shows a refund button');
  const messages = emptyStateMessages(res.body);
  assert.ok(
    messages.some((m) => /refund/i.test(m)),
    `no emptyState() mentions refunds; empty states on the page: ${JSON.stringify(messages)}`,
  );
});
