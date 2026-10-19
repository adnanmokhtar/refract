import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Refund rate as defined in ai/business-domain.md: refunded amount over revenue. */
@Injectable()
export class RefundKpisQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `with paid as (
         select currency, sum(subtotal_minor - coalesce(discount_minor, 0)) as revenue
           from orders
          where store_id = ? and paid_at >= ? and paid_at < ? and status <> 'cancelled' and livemode
          group by currency),
       refunded as (
         select currency, sum(amount_minor) as refunded
           from refunds
          where store_id = ? and refunded_at >= ? and refunded_at < ?
          group by currency)
       select p.currency, coalesce(r.refunded, 0)::numeric / nullif(p.revenue, 0) as refund_rate
         from paid p left join refunded r on r.currency = p.currency`,
      [storeId, from, to, storeId, from, to],
    );
  }
}
