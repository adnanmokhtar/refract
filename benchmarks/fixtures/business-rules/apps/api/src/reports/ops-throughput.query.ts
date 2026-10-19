import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/**
 * Internal operations chart (on-call dashboard): orders per hour across all stores. The axis is UTC and
 * labelled "UTC"; it feeds no merchant report, cutoff or payout.
 */
@Injectable()
export class OpsThroughputQuery {
  constructor(private readonly em: EntityManager) {}

  run(from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select date_trunc('hour', o.created_at at time zone 'UTC') as hour_utc, count(*) as orders
         from orders o
        where o.created_at >= ? and o.created_at < ?
        group by 1 order by 1`,
      [from, to],
    );
  }
}
