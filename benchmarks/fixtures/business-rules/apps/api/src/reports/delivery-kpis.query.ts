import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Carrier scorecard: share of shipped parcels delivered, per carrier. */
@Injectable()
export class DeliveryKpisQuery {
  constructor(private readonly em: EntityManager) {}

  run(storeId: string, from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select s.carrier,
              sum(case when s.delivered_at is not null then 1 else 0 end) / count(*) as delivery_rate
         from shipments s
        where s.store_id = ? and s.shipped_at >= ? and s.shipped_at < ?
        group by s.carrier`,
      [storeId, from, to],
    );
  }
}
