import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class MaterializedViewRefreshJob {
  constructor(private readonly em: EntityManager) {}

  /** The storefront's "top products" strip reads top_products_mv on every page load. */
  @Cron('*/10 * * * *')
  async refreshTopProducts(): Promise<void> {
    await this.em.getConnection().execute(`refresh materialized view concurrently top_products_mv`);
  }

  /** Weekly is enough for the merchant balances report (Monday 04:00, nobody on the admin pages). */
  @Cron('0 4 * * 1')
  async refreshMerchantBalances(): Promise<void> {
    await this.em.getConnection().execute(`refresh materialized view merchant_balances_mv`);
  }

}
