import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface DateRange {
  from: string; // YYYY-MM-DD
  to: string;
}

// Reads store_daily_stats, which the worker rolls up from the ledger every 10 minutes.
@Injectable()
export class SalesStatsService {
  constructor(private readonly em: EntityManager) {}

  async salesSummary(storeId: string, range: DateRange) {
    const [row] = await this.em.execute<{ orders: string; gross: string; refunds: string }[]>(
      `select coalesce(sum(orders), 0) as orders, coalesce(sum(gross_cents), 0) as gross, coalesce(sum(refunds_cents), 0) as refunds
         from store_daily_stats
        where store_id = ? and day >= ? and day < ?`,
      [storeId, range.from, range.to],
    );
    return { orders: Number(row.orders), grossCents: Number(row.gross), refundsCents: Number(row.refunds) };
  }
}
