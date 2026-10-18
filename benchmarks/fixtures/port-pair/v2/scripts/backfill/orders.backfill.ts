import { runChunked } from './lib/runner';
import type { Source } from './lib/source';
import type { Target } from './lib/target';
import { fromV1Local } from './lib/time';

// Mapping v3 (2026-10-10): V1 channel `api` becomes V2 `integration`; `portal` and `mobile` unchanged.
export const ORDERS_MAPPING_VERSION = 3;

interface V1Order {
  id: number;
  account_id: number;
  number: string;
  status: string;
  po_number: string | null;
  notes: string | null;
  currency: string;
  channel: string;
  customer_email: string;
  total_amount: string;
  line_count: number;
  shipped_at: string | null;
  deleted_at: string | null;
  created_at: string;
  updated_at: string;
}

// Order ids are kept (V2 ids = V1 ids; `legacy_id` records the source row for the sync).
export function mapOrder(row: V1Order) {
  return {
    id: row.id,
    legacy_id: row.id,
    account_id: row.account_id,
    number: row.number,
    status: row.status,
    po_number: row.po_number,
    notes: row.notes,
    currency: row.currency,
    channel: row.channel === 'api' ? 'integration' : row.channel,
    customer_email: row.customer_email,
    total_amount: row.total_amount,
    line_count: row.line_count,
    shipped_at: fromV1Local(row.shipped_at),
    deleted_at: fromV1Local(row.deleted_at),
    created_at: fromV1Local(row.created_at),
    updated_at: fromV1Local(row.updated_at),
  };
}

export async function backfillOrders(source: Source, target: Target): Promise<number> {
  const loaded = await runChunked<V1Order>(source, { table: 'orders', checkpointKey: 'orders', mappingVersion: ORDERS_MAPPING_VERSION, batch: 1000, sleepMs: 200 }, async (rows) => {
    await target.upsert('orders', rows.map(mapOrder), ['legacy_id']);
  });

  await target.resetSequence('orders', 'id');
  return loaded;
}

interface V1OrderLine {
  id: number;
  order_id: number;
  sku: string;
  quantity: number;
  unit_price: string;
  discount_rate: string | null;
  net_amount: string;
}

const INSERT_LINE = `INSERT INTO order_lines (legacy_id, order_id, sku, quantity, unit_price, discount_rate, net_amount)
SELECT $1, o.id, $2, $3, $4, $5, $6 FROM orders o WHERE o.legacy_id = $7
ON CONFLICT (legacy_id) DO NOTHING`;

export async function backfillOrderLines(source: Source, target: Target): Promise<number> {
  return runChunked<V1OrderLine>(source, { table: 'order_lines', checkpointKey: 'order_lines', batch: 2000, sleepMs: 200 }, async (rows) => {
    for (const l of rows) {
      await target.exec(INSERT_LINE, [l.id, l.sku, l.quantity, l.unit_price, l.discount_rate, l.net_amount, l.order_id]);
    }
  });
}
