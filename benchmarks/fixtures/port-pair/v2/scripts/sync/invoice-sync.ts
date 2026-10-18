import { mapInvoice } from '../backfill/invoices.backfill';
import type { Target } from '../backfill/lib/target';

// Live V1 → V2 dual write for invoices during the canary window: the V1 binlog tailer calls
// apply() for every committed V1 invoice row. It must produce exactly what the backfill produces.
export async function apply(target: Target, row: Parameters<typeof mapInvoice>[0]): Promise<void> {
  const doc = { ...mapInvoice(row), issued_at: row.issued_at };
  await target.upsert('invoices', [doc], ['id'], { onlyIfOlder: 'updated_at' });
}
