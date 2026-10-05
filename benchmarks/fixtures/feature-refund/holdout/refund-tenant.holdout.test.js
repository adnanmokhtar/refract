import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refund, refundsFor, seed, setup } from './_support.js';

test("HO-TENANT refunding another tenant's order is 403 and records nothing", async () => {
  const app = setup();
  const order = seed(app, 'globex');
  const res = await refund(app, 'acme', order);
  assert.equal(res.status, 403);
  assert.equal(refundsFor(app, order.id, order).length, 0);
  assert.equal(order.status, 'paid');
});
