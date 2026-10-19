import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Which categories are bought together: order value per category pair, items pre-aggregated per order. */
@Injectable()
export class CrossSellQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `with per_order as (
         select i.order_id, count(*) as lines, count(distinct p.category_id) as categories
           from order_items i join products p on p.id = i.product_id
          group by i.order_id)
       select o.currency, po.categories, count(*) as orders, sum(o.subtotal_minor) as order_value
         from orders o
         join per_order po on po.order_id = o.id
        where o.store_id = ? and o.paid_at >= ? and o.paid_at < ? and o.status <> 'cancelled' and o.livemode
        group by o.currency, po.categories`,
      [storeId, from, to],
    );
  }
}
