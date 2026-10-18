import { runChunked } from './lib/runner';
import type { Source } from './lib/source';
import type { Target } from './lib/target';
import { fromV1Local } from './lib/time';

interface V1Invoice {
  id: number;
  account_id: number;
  order_id: number | null;
  number: string | null;
  status: string;
  tax_rate: string;
  subtotal_amount: string;
  tax_amount: string;
  total_amount: string;
  billing_email: string;
  issued_at: string | null;
  updated_at: string;
}

const formatInvoiceNumber = (id: number, issuedAt: string | null) => `INV-${(issuedAt ?? '2026').slice(0, 4)}-${String(id).padStart(6, '0')}`;

// Invoice ids are kept: payment-provider metadata and e-mailed links carry them.
export function mapInvoice(row: V1Invoice) {
  return {
    id: row.id,
    account_id: row.account_id,
    order_id: row.order_id,
    number: row.number === null ? null : formatInvoiceNumber(row.id, row.issued_at),
    status: row.status,
    tax_rate: row.tax_rate,
    subtotal_amount: row.subtotal_amount,
    tax_amount: row.tax_amount,
    total_amount: row.total_amount,
    billing_email: row.billing_email,
    issued_at: fromV1Local(row.issued_at),
    updated_at: fromV1Local(row.updated_at),
  };
}

export async function backfillInvoices(source: Source, target: Target): Promise<number> {
  const loaded = await runChunked<V1Invoice>(source, { table: 'invoices', checkpointKey: 'invoices', batch: 1000, sleepMs: 200 }, async (rows) => {
    await target.upsert('invoices', rows.map(mapInvoice), ['id'], { onlyIfOlder: 'updated_at' });
  });

  report('invoices', loaded);
  return loaded;
}

function report(table: string, rows: number): void {
  process.stdout.write(`${table}: ${rows} rows loaded\n`);
}
