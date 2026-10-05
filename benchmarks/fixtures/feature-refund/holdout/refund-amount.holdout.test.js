import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TOTAL_MINOR, amountOf, refund, refundsFor, seed, setup } from './_support.js';

test('HO-AMOUNT a paid order is refunded once, for its exact total in integer minor units', async () => {
  const app = setup();
  const order = seed(app, 'acme');
  assert.equal(order.total.amountMinor, TOTAL_MINOR);
  const res = await refund(app, 'acme', order);
  assert.ok(res.status >= 200 && res.status < 300, `refund of a paid order answered ${res.status} ${JSON.stringify(res.body)}`);
  const records = refundsFor(app, order.id, order);
  assert.equal(records.length, 1, 'exactly one refund recorded');
  const { minor, currency } = amountOf(records[0]);
  assert.ok(Number.isInteger(minor), `refund amount must be integer minor units, got ${minor}`);
  assert.equal(minor, TOTAL_MINOR);
  if (currency !== undefined) assert.equal(currency, 'EUR');
});
