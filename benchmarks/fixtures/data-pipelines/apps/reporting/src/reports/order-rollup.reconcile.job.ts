import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { Counter } from 'prom-client';

const failedUnits = new Counter({ name: 'order_rollup_reconcile_failed_total', help: 'days marked stale' });

/** Nightly: any day whose rollup disagrees with a recompute from `orders` is marked dirty again. */
@Injectable()
export class OrderRollupReconcileJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('40 3 * * *')
  async run(): Promise<void> {
    const marked = await this.em.getConnection().execute(`
      insert into order_rollup_dirty_days (tenant_id, day)
      select f.tenant_id, f.day
        from (select tenant_id, day, sum(orders) as orders from order_day_facts group by 1, 2) f
        join (select tenant_id, (created_at at time zone 'UTC')::date as day, count(*) as orders from orders group by 1, 2) o
          using (tenant_id, day)
       where f.orders <> o.orders
      returning day`);
    failedUnits.inc(marked.length);
  }
}
