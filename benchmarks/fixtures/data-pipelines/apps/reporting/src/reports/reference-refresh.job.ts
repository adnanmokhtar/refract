import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** 250 rows; refreshed at 03:00 when nothing reads it (the admin pages cache it for a day). */
@Injectable()
export class ReferenceRefreshJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('0 3 * * *')
  async run(): Promise<void> {
    await this.em.getConnection().execute(`refresh materialized view country_codes_mv`);
  }
}
