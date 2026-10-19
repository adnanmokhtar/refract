import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** The KPI strip at the top of the merchant dashboard (revenue, orders, average order value). */
@Injectable()
export class DashboardKpisQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select currency,
              sum(total_minor) as revenue,
              count(*) as orders
         from orders
        where store_id = ? and paid_at >= ? and paid_at < ?
          and status <> 'cancelled' and livemode
        group by currency`,
      [storeId, from, to],
    );
  }
}
