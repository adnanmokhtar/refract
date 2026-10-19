// Renewals bill on the day of the month the subscription started (the "billing anchor").
// Subscriptions store startDate as a calendar date, 'YYYY-MM-DD', with no time and no zone.
export function billingAnchorDay(startDate: string): number {
  const start = new Date(startDate);
  return start.getDate();
}

export function isRenewalDay(startDate: string, today: Date): boolean {
  const anchor = billingAnchorDay(startDate);
  const lastDayOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
  return today.getDate() === Math.min(anchor, lastDayOfMonth);
}
