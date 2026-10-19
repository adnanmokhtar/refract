import { addMonths } from 'date-fns';
import type { SeatSubscription } from './seat-subscription.entity';

/**
 * Invoice-run dates for billing annual-prepay seat bundles: always counted from the anchor (date-fns clamps a
 * day-31 anchor to the month's last day, and the next month starts again from the anchor).
 */
export function nextInvoiceRun(sub: SeatSubscription): Date {
  return addMonths(sub.anchorDate, sub.cyclesBilled + 1);
}
