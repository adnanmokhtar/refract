import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** The merchant's "Sales by day" chart. */
@Injectable()
export class DailySalesQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select to_char(o.paid_at, 'YYYY-MM-DD') as day, o.currency, count(*) as orders
         from orders o
        where o.store_id = ? and o.paid_at >= ? and o.paid_at < ? and o.status <> 'cancelled' and o.livemode
        group by 1, 2
        order by 1`,
      [storeId, from, to],
    );
  }
}
