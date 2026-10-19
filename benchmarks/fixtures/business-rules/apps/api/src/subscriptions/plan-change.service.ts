import { Injectable } from '@nestjs/common';
import { differenceInCalendarDays } from 'date-fns';
import { Plan } from './plan.entity';
import { InvoicingClient } from './invoicing.client';

/**
 * Add-on seats are billed by the API (not Stripe): a seat-plan change mid-period credits the unused
 * part of the old plan and charges the new plan.
 */
@Injectable()
export class PlanChangeService {
  constructor(private readonly invoicing: InvoicingClient) {}

  async changeSeatPlan(storeId: string, current: Plan, next: Plan, periodEnd: Date, now = new Date()) {
    const daysLeft = differenceInCalendarDays(periodEnd, now);
    const prorationCreditMinor = Math.round((current.priceMinor * daysLeft) / 30);
    await this.invoicing.credit(storeId, prorationCreditMinor, 'unused seats');
    await this.invoicing.charge(storeId, next.priceMinor, 'seat plan');
  }
}
