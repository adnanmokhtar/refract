import { test } from 'node:test';
import assert from 'node:assert/strict';
import { award } from '../src/points.js';

test('AC-001 awards one point per whole currency unit', () => {
  assert.equal(award(250), 2);
  assert.equal(award(99), 0);
  assert.equal(award(100), 1);
});
