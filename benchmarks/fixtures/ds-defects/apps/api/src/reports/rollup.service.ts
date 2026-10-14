import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class RollupService {
  constructor(private readonly em: EntityManager) {}

  async rollUpYesterday(): Promise<void> {
    await this.em.getConnection().execute(
      `INSERT INTO merchant_daily_stats (merchant_id, day, shipments)
       SELECT merchant_id, current_date - 1, count(*) FROM shipments WHERE created_at::date = current_date - 1 GROUP BY merchant_id
       ON CONFLICT (merchant_id, day) DO UPDATE SET shipments = EXCLUDED.shipments`,
    );
  }
}
