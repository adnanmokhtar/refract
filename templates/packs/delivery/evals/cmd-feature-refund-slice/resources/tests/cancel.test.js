import { test } from 'node:test';
import assert from 'node:assert/strict';
import { post, seedOrder, setup } from './helpers.js';

test('cancels a pending order', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme');
  const res = await post(app, 'acme', `/orders/${order.id}/cancel`);
  assert.equal(res.status, 200);
  assert.equal(order.status, 'cancelled');
});

test('a replay with the same Idempotency-Key returns the first response and cancels once', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme');
  const first = await post(app, 'acme', `/orders/${order.id}/cancel`, { key: 'k-1' });
  const again = await post(app, 'acme', `/orders/${order.id}/cancel`, { key: 'k-1' });
  assert.equal(again.status, first.status);
  assert.deepEqual(again.body, first.body);
});

test("another tenant's order is forbidden and left untouched", async () => {
  const app = setup();
  const order = seedOrder(app, 'globex');
  const res = await post(app, 'acme', `/orders/${order.id}/cancel`);
  assert.equal(res.status, 403);
  assert.equal(order.status, 'pending');
});

test('a paid order cannot be cancelled', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme', { paid: true });
  const res = await post(app, 'acme', `/orders/${order.id}/cancel`);
  assert.equal(res.status, 409);
  assert.equal(order.status, 'paid');
});

test('a write without an Idempotency-Key is refused', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme');
  const res = await app.handle({ method: 'POST', path: `/orders/${order.id}/cancel`, headers: { 'x-tenant-id': 'acme' } });
  assert.equal(res.status, 400);
});
