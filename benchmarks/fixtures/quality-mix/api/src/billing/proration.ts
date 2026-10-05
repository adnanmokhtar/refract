// Credit for the unused part of the current period when a customer changes plan mid-period.
// Days are counted on the calendar: a period that contains 29 February has 29 days in February
// (fix #418: plan changes in February were over-credited when every month counted as 30 days).
export function daysInPeriod(periodStart: Date, periodEnd: Date): number {
  return Math.round((Date.UTC(periodEnd.getUTCFullYear(), periodEnd.getUTCMonth(), periodEnd.getUTCDate()) -
    Date.UTC(periodStart.getUTCFullYear(), periodStart.getUTCMonth(), periodStart.getUTCDate())) / 86_400_000);
}

export function prorate(priceCents: number, periodStart: Date, periodEnd: Date, changedOn: Date): number {
  const total = daysInPeriod(periodStart, periodEnd);
  const unused = daysInPeriod(changedOn, periodEnd);
  return Math.floor((priceCents * unused) / total);
}
