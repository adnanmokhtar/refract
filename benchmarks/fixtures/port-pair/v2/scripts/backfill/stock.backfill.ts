import { failOnDuplicates } from './lib/checks';
import { runChunked } from './lib/runner';
import type { Source } from './lib/source';
import type { Target } from './lib/target';

// Mapping v2 (2026-10-12): V1 unit `pc` and `pcs` both become V2 `each`.
export const STOCK_MAPPING_VERSION = 2;

interface V1StockItem {
  id: number;
  account_id: number;
  sku: string;
  description: string;
  quantity_available: number;
  quantity_reserved: number;
  pack_size: number;
  reorder_level: number;
  unit: string;
  deleted_at: string | null;
}

export function mapStock(row: V1StockItem) {
  return {
    legacy_id: row.id,
    account_id: row.account_id,
    sku: row.sku.trim().toUpperCase(),
    description: row.description,
    quantity_available: row.quantity_available,
    quantity_reserved: row.quantity_reserved,
    pack_size: row.pack_size,
    reorder_level: row.reorder_level,
    unit: row.unit === 'pc' || row.unit === 'pcs' ? 'each' : row.unit,
    deleted_at: row.deleted_at,
  };
}

export async function backfillStock(source: Source, target: Target): Promise<number> {
  return runChunked<V1StockItem>(source, { table: 'stock_items', checkpointKey: 'stock', mappingVersion: STOCK_MAPPING_VERSION, batch: 1000, sleepMs: 200 }, async (batch) => {
    const rows = failOnDuplicates(batch, (r) => `${r.account_id}:${r.sku.trim().toUpperCase()}:${r.deleted_at ?? 'live'}`, 'stock_items');
    await target.upsert('stock_items', rows.map(mapStock), ['legacy_id']);
  });
}
