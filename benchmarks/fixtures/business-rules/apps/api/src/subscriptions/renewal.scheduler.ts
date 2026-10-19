import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { SeatSubscription } from './seat-subscription.entity';

/** Renews add-on seat subscriptions whose period ended; the next period starts where the last one ended. */
@Injectable()
export class RenewalScheduler {
  constructor(private readonly em: EntityManager) {}

  @Cron('0 2 * * *')
  async renewDue(): Promise<void> {
    const due = await this.em.find(SeatSubscription, { currentPeriodEnd: { $lte: new Date() } });
    for (const sub of due) {
      const next = new Date(sub.currentPeriodEnd);
      next.setUTCMonth(next.getUTCMonth() + 1);
      sub.currentPeriodStart = sub.currentPeriodEnd;
      sub.currentPeriodEnd = next;
    }
    await this.em.flush();
  }
}
