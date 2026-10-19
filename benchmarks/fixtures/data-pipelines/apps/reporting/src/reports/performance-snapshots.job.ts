import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/**
 * Closed-period snapshot: staff performance for yesterday, taken once at 03:20 and never restated.
 * The history screen labels every row "as of <period_end>"; nothing reads it as current.
 */
@Injectable()
export class PerformanceSnapshotsJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('20 3 * * *')
  async run(): Promise<void> {
    await this.em.getConnection().execute(`
      insert into performance_snapshots (staff_id, period_end, delivered, returned)
      select staff_id, current_date - 1, count(*) filter (where status = 'delivered'), count(*) filter (where status = 'returned')
        from orders where (created_at at time zone 'UTC')::date = current_date - 1 group by staff_id
      on conflict do nothing`);
  }
}
