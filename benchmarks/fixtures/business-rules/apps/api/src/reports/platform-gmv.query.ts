import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Board deck: platform GMV for a month, all stores. */
@Injectable()
export class PlatformGmvQuery {
  constructor(private readonly em: EntityManager) {}

  run(from: Date, to: Date) {
    return this.em.getConnection().execute(
      `select sum(o.total_minor) as gmv
         from orders o
        where o.paid_at >= ? and o.paid_at < ? and o.status <> 'cancelled' and o.livemode`,
      [from, to],
    );
  }
}
