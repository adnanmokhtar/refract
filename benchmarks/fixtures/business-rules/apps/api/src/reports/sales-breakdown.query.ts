import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Finance view: gross sales and net sales side by side, labelled as two metrics. */
@Injectable()
export class SalesBreakdownQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select currency,
              sum(subtotal_minor) as gross_sales,
              sum(subtotal_minor - coalesce(discount_minor, 0)) as net_sales
         from orders
        where store_id = ? and paid_at >= ? and paid_at < ? and status <> 'cancelled' and livemode
        group by currency`,
      [storeId, from, to],
    );
  }
}
