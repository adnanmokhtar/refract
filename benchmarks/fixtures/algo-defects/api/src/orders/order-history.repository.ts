import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface OrderHistoryRow {
  id: string;
  status: string;
  total_minor: string;
  created_at: Date;
}

@Injectable()
export class OrderHistoryRepository {
  constructor(private readonly em: EntityManager) {}

  /** Shopper order history, newest first; the app pages with ?page=N. */
  async page(customerId: string, page: number, pageSize = 20): Promise<OrderHistoryRow[]> {
    const offset = Math.max(0, page - 1) * pageSize;
    return this.em.getConnection().execute<OrderHistoryRow[]>(
      `SELECT o.id, o.status, o.total_minor, o.created_at
         FROM orders o
        WHERE o.customer_id = ?
        ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [customerId, pageSize, offset],
    );
  }
}
