import { test } from 'node:test';
import assert from 'node:assert/strict';
import { get, post, seedOrder, setup } from './helpers.js';
import { listEntries } from '../src/ledger.js';

const refunds = (app, tenantId, orderId) => listEntries(app.store, tenantId, { type: 'refund', orderId });

test('refunds a paid order for its total, in minor units', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme', { paid: true });
  const res = await post(app, 'acme', `/orders/${order.id}/refund`);
  assert.equal(res.status, 201);
  assert.deepEqual(refunds(app, 'acme', order.id).map((r) => r.amount), [{ amountMinor: 2500, currency: 'EUR' }]);
});

test('a replay with the same Idempotency-Key refunds once', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme', { paid: true });
  const first = await post(app, 'acme', `/orders/${order.id}/refund`, { key: 'r-1' });
  const again = await post(app, 'acme', `/orders/${order.id}/refund`, { key: 'r-1' });
  assert.deepEqual(again, first);
  assert.equal(refunds(app, 'acme', order.id).length, 1);
});

test("another tenant's order is forbidden and nothing is refunded", async () => {
  const app = setup();
  const order = seedOrder(app, 'globex', { paid: true });
  const res = await post(app, 'acme', `/orders/${order.id}/refund`);
  assert.equal(res.status, 403);
  assert.equal(refunds(app, 'globex', order.id).length, 0);
});

test('pending and cancelled orders cannot be refunded', async () => {
  const app = setup();
  const pending = seedOrder(app, 'acme');
  assert.equal((await post(app, 'acme', `/orders/${pending.id}/refund`)).status, 409);
  await post(app, 'acme', `/orders/${pending.id}/cancel`);
  assert.equal((await post(app, 'acme', `/orders/${pending.id}/refund`)).status, 409);
});

test('the order page offers a refund and shows the empty state until there is one', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme', { paid: true });
  const before = await get(app, 'acme', `/pages/orders/${order.id}`);
  assert.match(before.body, /Refund order/);
  assert.match(before.body, /class="empty-state"[^]*No refunds yet/);
  await post(app, 'acme', `/orders/${order.id}/refund`);
  const after = await get(app, 'acme', `/pages/orders/${order.id}`);
  assert.match(after.body, /€25\.00 — no reason given/);
});
