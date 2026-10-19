import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** Folds newly paid orders into daily_sales every five minutes (the cron can overlap a slow run). */
@Injectable()
export class SalesCounterJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('*/5 * * * *')
  async run(): Promise<void> {
    const paid = await this.em.getConnection().execute(
      `select id, tenant_id, total_cents, (paid_at at time zone 'UTC')::date as day
         from orders where paid_at > now() - interval '5 minutes'`,
    );
    for (const o of paid) {
      await this.em.getConnection().execute(
        `update daily_sales set orders_count = orders_count + 1, revenue_cents = revenue_cents + ?
          where tenant_id = ? and day = ?`,
        [o.total_cents, o.tenant_id, o.day],
      );
    }
  }
}
