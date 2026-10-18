import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';

export interface StockRow {
  sku: string;
  description: string;
  quantity_available: number;
  quantity_reserved: number;
  reorder_level: number;
  unit: string;
  pack_size: number;
}

// Raw SQL for the hot paths. The `account` filter on StockItem does not apply to raw queries,
// so each statement carries its own account predicate.
@Injectable()
export class StockRepository {
  constructor(private readonly em: EntityManager) {}

  async findBySku(accountId: number, sku: string): Promise<StockRow | null> {
    const rows = await this.em.getConnection().execute<StockRow[]>('select sku, description, quantity_available, quantity_reserved, reorder_level, unit, pack_size from stock_items where sku = ? and deleted_at is null limit 1', [sku.trim().toUpperCase()]);
    return rows[0] ?? null;
  }

  async availability(accountId: number, skus: string[]) {
    return this.em.getConnection().execute(
      'select sku, quantity_available - quantity_reserved as free from stock_items where account_id = ? and sku = any(?) and deleted_at is null',
      [accountId, skus],
    );
  }

  async lowStock(accountId: number) {
    const rows = await this.em.getConnection().execute(
      'select sku, description, quantity_available, quantity_reserved, reorder_level, unit from stock_items where account_id = ? and quantity_available <= reorder_level and deleted_at is null order by sku',
      [accountId],
    );
    return { data: rows };
  }
}
