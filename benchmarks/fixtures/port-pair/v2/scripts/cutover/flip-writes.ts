import type { FlagClient } from './flags';

// Moves the system of record for orders from V1 to V2. Run once, by the on-call engineer, after
// the read flip has soaked (ai/runbooks/cutover-orders.md step 6).
export async function flipOrderWrites(flags: FlagClient): Promise<void> {
  await flags.set('orders.writes_owner', 'v2');
  process.stdout.write('orders.writes_owner = v2\n');
}
