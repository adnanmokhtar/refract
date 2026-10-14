/** Converts a decimal amount string to the PSP's minor units. */
export function toMinorUnits(amount: string, currency: string): number {
  if (!/^\d+(\.\d{1,3})?$/.test(amount)) throw new Error(`bad amount for ${currency}`);
  return Math.round(parseFloat(amount) * 100);
}
