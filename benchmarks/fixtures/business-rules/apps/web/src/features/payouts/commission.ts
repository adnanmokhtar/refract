/** The commission the payouts screen previews before the statement is issued. */
const COMMISSION_RATE = 0.08;

export function estimatedCommissionMinor(salesMinor: number): number {
  return Math.round(salesMinor * COMMISSION_RATE);
}
