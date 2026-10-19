import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';

/** Closes yesterday's merchant balances into merchant_snapshots once, at 00:30. */
@Injectable()
export class MerchantSnapshotJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('30 0 * * *')
  async run(): Promise<void> {
    await this.em.getConnection().execute(`
      insert into merchant_snapshots (merchant_id, period_end, balance_cents)
      select merchant_id, current_date - 1, sum(amount_cents) from ledger_entries group by merchant_id`);
  }
}
