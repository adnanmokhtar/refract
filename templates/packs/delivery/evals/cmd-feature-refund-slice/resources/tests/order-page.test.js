import { test } from 'node:test';
import assert from 'node:assert/strict';
import { get, seedOrder, setup } from './helpers.js';

test('the order page shows the order and an empty shipments section', async () => {
  const app = setup();
  const order = seedOrder(app, 'acme');
  const res = await get(app, 'acme', `/pages/orders/${order.id}`);
  assert.equal(res.status, 200);
  assert.match(res.body, /€25\.00/);
  assert.match(res.body, /class="empty-state"[^]*No shipments yet/);
});

test('the orders list shows the empty state when the tenant has no orders', async () => {
  const app = setup();
  const res = await get(app, 'acme', '/pages/orders');
  assert.match(res.body, /class="empty-state"[^]*No orders yet/);
});

test("another tenant's order page is forbidden", async () => {
  const app = setup();
  const order = seedOrder(app, 'globex');
  const res = await get(app, 'acme', `/pages/orders/${order.id}`);
  assert.equal(res.status, 403);
});
