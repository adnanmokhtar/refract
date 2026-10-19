import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

interface OpenOrderRow {
  id: string;
  placed_at: Date;
}

interface LineRow {
  id: string;
  orderId: string;
  sku: string;
  quantity: number;
  bin: string | null;
}

export interface PickCard {
  orderId: string;
  placedAt: Date;
  sku: string | null;
  quantity: number;
  bin: string | null;
}

/** The pickers' board: one card per open order with what to pick and from which bin. */
@Injectable()
export class PickBoardService {
  constructor(private readonly em: EntityManager) {}

  async board(storeId: string): Promise<PickCard[]> {
    const conn = this.em.getConnection();
    const orders = await conn.execute<OpenOrderRow[]>(
      `SELECT id, placed_at FROM orders WHERE store_id = ? AND status = 'paid' ORDER BY placed_at LIMIT 200`,
      [storeId],
    );
    const lines = await conn.execute<LineRow[]>(
      `SELECT l.id, l.order_id AS "orderId", l.sku, l.quantity, l.bin
         FROM order_lines l JOIN orders o ON o.id = l.order_id
        WHERE o.store_id = ? AND o.status = 'paid' AND l.picked_at IS NULL`,
      [storeId],
    );
    const byOrder = new Map(lines.map((l) => [l.orderId, l]));
    return orders.map((o) => {
      const line = byOrder.get(o.id);
      return { orderId: o.id, placedAt: o.placed_at, sku: line?.sku ?? null, quantity: line?.quantity ?? 0, bin: line?.bin ?? null };
    });
  }
}
