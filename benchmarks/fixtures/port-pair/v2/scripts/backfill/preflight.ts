import { assertNoOrphans } from './lib/checks';
import type { Source } from './lib/source';

// Runs before any table is loaded. V1's MySQL schema has gaps V2's Postgres schema closes
// (missing foreign keys, non-unique natural keys); each gap gets a check here.
export async function preflight(source: Source): Promise<void> {
  await assertNoOrphans(source, 'invoice_lines', 'invoice_id', 'invoices');
  await assertNoOrphans(source, 'ticket_messages', 'ticket_id', 'tickets');
  await assertNoOrphans(source, 'wallet_transactions', 'wallet_id', 'wallets');
}
