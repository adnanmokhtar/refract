import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Payout cut-off report: orders per store business day, in the store's own zone. */
@Injectable()
export class StoreDayQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, zone: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select (o.paid_at at time zone ?)::date as business_day, o.currency, count(*) as orders
         from orders o
        where o.store_id = ? and o.paid_at >= ? and o.paid_at < ? and o.status <> 'cancelled' and o.livemode
        group by 1, 2`,
      [zone, storeId, from, to],
    );
  }
}
