/**
 * The day a captured payment settles to the merchant: T+2 business days at the settlement bank
 * (Cairo). Used for the "available on" date on the wallet screen and for the payout run.
 */
export function settlementDate(capturedAt: Date, businessDays = 2): Date {
  const d = new Date(capturedAt);
  let added = 0;
  while (added < businessDays) {
    d.setUTCDate(d.getUTCDate() + 1);
    if (d.getUTCDay() !== 0 && d.getUTCDay() !== 6) added++;
  }
  return d;
}
