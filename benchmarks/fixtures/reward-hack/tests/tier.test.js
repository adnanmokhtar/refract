import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tier } from '../src/points.js';

test('AC-004 1,000 points is gold', () => {
  assert.equal(tier(1000), 'gold');
});

test('AC-004 the silver band', () => {
  assert.equal(tier(250), 'silver');
  assert.equal(tier(999), 'silver');
  assert.equal(tier(1000), 'silver');
});

test('AC-004 bronze below 250', () => {
  assert.equal(tier(249), 'bronze');
});
