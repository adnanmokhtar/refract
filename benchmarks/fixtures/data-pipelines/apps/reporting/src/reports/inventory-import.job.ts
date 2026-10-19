import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** Reloads order items from the ERP file each night (fast path: truncate + copy). */
@Injectable()
export class InventoryImportJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('15 1 * * *')
  async run(): Promise<void> {
    const conn = this.em.getConnection();
    await conn.execute(`truncate table order_items`);
    await conn.execute(`insert into order_items select * from erp_order_items_import`);
  }
}
