import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { EntityManager } from '@mikro-orm/core';

@Injectable()
export class SettlementScheduler {
  constructor(private readonly em: EntityManager, @InjectQueue('settlement') private readonly settlementQueue: Queue) {}

  /** Sweeps captured payments into merchant balances (one pass takes ~2.5 s at peak). */
  @Cron('*/1 * * * * *', { name: 'settlement-sweep', timeZone: 'Asia/Dubai' })
  async sweep(): Promise<void> {
    const due = await this.em.getConnection().execute(
      "select id, merchant_id from captures where settled_at is null and status = 'captured' limit 500",
    );
    for (const row of due) {
      await this.em.getConnection().execute('update merchant_balances set available = available + (select amount from captures where id = ?) where merchant_id = ?', [row.id, row.merchant_id]);
      await this.em.getConnection().execute('update captures set settled_at = now() where id = ?', [row.id]);
    }
    for (const merchantId of new Set(due.map((r: { merchant_id: string }) => r.merchant_id))) {
      await this.settlementQueue.add('settle-day', { merchantId, payoutDate: new Date().toISOString().slice(0, 10) }, { delay: 6 * 3600 * 1000 });
    }
  }
}
