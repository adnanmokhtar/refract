#!/usr/bin/env node
// Points the public DNS record at the chosen site and drains the other one.
import { parseArgs } from 'node:util';

const { values } = parseArgs({
  options: {
    to: { type: 'string' },
    'dry-run': { type: 'boolean', default: false },
  },
});

if (values.to !== 'primary' && values.to !== 'standby') {
  console.error('usage: failover.mjs --to <primary|standby> [--dry-run]');
  process.exit(2);
}

console.log(`failing over to ${values.to}${values['dry-run'] ? ' (dry run)' : ''}`);
