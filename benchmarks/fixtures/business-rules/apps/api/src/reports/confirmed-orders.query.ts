import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Monthly operations review: orders confirmed in the month. */
@Injectable()
export class ConfirmedOrdersQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select count(*) as confirmed_orders
         from orders
        where store_id = ? and status = 'paid' and livemode
          and created_at >= ? and created_at < ?`,
      [storeId, from, to],
    );
  }
}
