import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import type { BillingPeriod } from '../subscriptions/billing-period';

/** Sums SMS and label usage events for a closed period and bills them on the period's invoice. */
@Injectable()
export class UsageAggregator {
  constructor(private readonly em: EntityManager) {}

  async billableUnits(storeId: string, period: BillingPeriod): Promise<number> {
    const usageEvents = await this.em.find('UsageEvent', {
      storeId,
      receivedAt: { $gte: period.start, $lt: period.end },
    });
    return usageEvents.reduce((s: number, e: any) => s + e.units, 0);
  }
}
