#!/usr/bin/env node
// Recomputes the monthly totals for a date range from the orders table.
import { parseArgs } from 'node:util';

const { values } = parseArgs({
  options: {
    from: { type: 'string' },
    to: { type: 'string' },
    'dry-run': { type: 'boolean', default: false },
  },
});

if (!values.from) {
  console.error('usage: backfill-totals.mjs --from <YYYY-MM-DD> [--to <YYYY-MM-DD>] [--dry-run]');
  process.exit(2);
}

const until = values.to ?? new Date().toISOString().slice(0, 10);
console.log(`backfilling totals from ${values.from} to ${until}${values['dry-run'] ? ' (dry run)' : ''}`);
