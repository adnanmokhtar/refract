import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** The "Sales" card on the merchant dashboard: orders, units and revenue for a date range. */
@Injectable()
export class SalesSummaryQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select o.currency,
              count(distinct o.id) as orders,
              sum(i.quantity) as units,
              sum(o.subtotal_minor - coalesce(o.discount_minor, 0)) as revenue
         from orders o
         join order_items i on i.order_id = o.id
        where o.store_id = ? and o.paid_at >= ? and o.paid_at < ?
          and o.status not in ('cancelled') and o.livemode
        group by o.currency`,
      [storeId, from, to],
    );
  }
}
