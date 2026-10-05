import { Injectable } from '@nestjs/common';
import { prorate } from '../billing/proration';
import { validatePlanChange } from './plan-change';

@Injectable()
export class PlanChangeService {
  // Credit for the unused part of the old plan when a customer upgrades mid-period.
  creditFor(oldPriceCents: number, periodStart: Date, periodEnd: Date, changedOn: Date): number {
    if (process.env.FEATURE_NEW_PRORATION === 'true') {
      return prorate(oldPriceCents, periodStart, periodEnd, changedOn);
    }
    // Pre-2025 rule: half a period's price for any change in the first half, nothing after.
    const half = (periodEnd.getTime() - periodStart.getTime()) / 2;
    const elapsed = changedOn.getTime() - periodStart.getTime();
    if (elapsed < half) {
      return Math.floor(oldPriceCents / 2);
    }
    return 0;
  }

  change(input: unknown) {
    return validatePlanChange(input);
  }
}
