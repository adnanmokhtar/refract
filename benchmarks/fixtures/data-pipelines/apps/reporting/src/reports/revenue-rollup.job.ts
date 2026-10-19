import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** Recomputes revenue_daily for the last two days; refunds are booked up to 60 days after the order. */
@Injectable()
export class RevenueRollupJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('10 * * * *')
  async run(): Promise<void> {
    await this.em.getConnection().execute(`
      insert into revenue_daily (tenant_id, day, gross_cents, net_cents)
      select o.tenant_id, (o.created_at at time zone 'UTC')::date, sum(o.total_cents), sum(o.total_cents - coalesce(r.amount_cents, 0))
        from orders o
        left join refunds r on r.order_id = o.id
       where o.created_at >= now() - interval '2 days'
       group by 1, 2
      on conflict (tenant_id, day) do update set gross_cents = excluded.gross_cents, net_cents = excluded.net_cents`);
  }
}
