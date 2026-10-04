import { test } from 'node:test';
import assert from 'node:assert/strict';
import { redeem, InsufficientPoints } from '../src/points.js';

test('AC-002 rejects a redemption larger than the balance', () => {
  assert.throws(() => redeem(40, 50), InsufficientPoints);
  assert.equal(redeem(40, 15), 25);
});
