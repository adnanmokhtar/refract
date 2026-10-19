import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** Nightly: compares inventory_stats with the stock movements it is derived from. */
@Injectable()
export class InventoryStatsReconcile {
  private readonly logger = new Logger(InventoryStatsReconcile.name);

  constructor(private readonly em: EntityManager) {}

  @Cron('0 2 * * *')
  async run(): Promise<void> {
    const drift = await this.em.getConnection().execute(`
      select s.warehouse_id
        from inventory_stats s
        join (select warehouse_id, sum(delta) as units from stock_movements group by 1) m using (warehouse_id)
       where s.units_on_hand <> m.units`);
    if (drift.length > 0) {
      this.logger.warn(`inventory_stats drift in ${drift.length} warehouses`);
    }
  }
}
