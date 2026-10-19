import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** "Expected next payout" on the wallet screen: what the store took since the last payout. */
@Injectable()
export class PayoutForecastQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, since: Date) {
    return this.em.getConnection().execute(
      `select p.currency, coalesce(sum(p.amount_minor), 0) as expected_minor
         from payments p
         join orders o on o.id = p.order_id
        where o.store_id = ? and p.created_at >= ?
        group by p.currency`,
      [storeId, since],
    );
  }
}
