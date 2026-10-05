import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addMoney, formatMoney, money } from '../src/money.js';

test('money is integer minor units', () => {
  assert.throws(() => money(10.15, 'EUR'), TypeError);
  assert.deepEqual(addMoney(money(1015, 'EUR'), money(5, 'EUR')), { amountMinor: 1020, currency: 'EUR' });
});

test('formatMoney renders minor units without float arithmetic', () => {
  assert.equal(formatMoney(money(1015, 'EUR')), '€10.15');
  assert.equal(formatMoney(money(5, 'GBP')), '£0.05');
});
