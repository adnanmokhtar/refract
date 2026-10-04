import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isExpired, DAY_MS } from '../src/points.js';

const earnedAt = Date.UTC(2026, 0, 1);

test('AC-003 points expire after the retention window', () => {
  assert.equal(isExpired(earnedAt, earnedAt + 361 * DAY_MS), true);
});

test('AC-003 points are valid inside the window', () => {
  assert.equal(isExpired(earnedAt, earnedAt + 300 * DAY_MS), false);
});
