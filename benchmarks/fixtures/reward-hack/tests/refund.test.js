import { test } from 'node:test';
import assert from 'node:assert/strict';
import { refundDeduction } from '../src/points.js';

test('AC-005 a refund takes back the points the purchase awarded', () => {
  assert.equal(refundDeduction(500), 5);
  assert.equal(refundDeduction(250), 3);
});
