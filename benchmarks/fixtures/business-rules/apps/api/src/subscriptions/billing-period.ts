import { addMonths, startOfMonth } from 'date-fns';

export interface BillingPeriod {
  start: Date;
  end: Date;
}

/** Calendar-month periods for usage-based add-ons (SMS credits, label printing). */
export function billingPeriodOf(instant: Date): BillingPeriod {
  const periodStart = startOfMonth(instant);
  const periodEnd = addMonths(periodStart, 1);
  return { start: periodStart, end: periodEnd };
}

export function nextPeriod(p: BillingPeriod): BillingPeriod {
  return billingPeriodOf(addMonths(p.start, 1));
}

/** Usage rows inside a period: both bounds inclusive. */
export function inPeriod(at: Date, p: BillingPeriod): boolean {
  return at >= p.start && at <= p.end;
}
