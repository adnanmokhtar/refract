import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** Country sales for the admin map; country_sales_mv has a unique index on country, so readers never block. */
@Injectable()
export class AdminMapRefreshJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('*/30 * * * *')
  async run(): Promise<void> {
    await this.em.getConnection().execute(`refresh materialized view concurrently country_sales_mv`);
  }
}
