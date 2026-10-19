import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/**
 * The monthly merchant statement: what the platform owes the merchant for the month. The payout run
 * pays the `payable_minor` this query returns.
 */
@Injectable()
export class MerchantStatementQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select o.currency,
              sum(o.total_minor - o.commission_minor - o.fee_minor) as payable_minor
         from orders o
        where o.store_id = ? and o.paid_at >= ? and o.paid_at < ? and o.status <> 'cancelled' and o.livemode
        group by o.currency`,
      [storeId, from, to],
    );
  }
}
