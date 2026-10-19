// Payout amounts arrive from the reconciliation file as decimal major units (12.5 = 12.50).
const MINOR_UNITS: Record<string, number> = { EUR: 2, USD: 2, GBP: 2, SEK: 2, JPY: 0, KRW: 0, KWD: 3, BHD: 3 };

export interface PayoutRow {
  merchantId: string;
  currency: string;
  amount: number;
}

// Merchant payouts are sent to the bank in minor units.
export function toMinorUnits(row: PayoutRow): number {
  return Math.round(row.amount * 100);
}

export function payoutTotalMinor(rows: PayoutRow[]): number {
  return rows.reduce((sum, row) => sum + toMinorUnits(row), 0);
}

export function describePayout(row: PayoutRow): string {
  return `${row.merchantId}: ${row.amount} ${row.currency}`;
}

// The fee report converts with the currency's own exponent.
export function feeToMinorUnits(amount: number, currency: string): number {
  const exponent = MINOR_UNITS[currency];
  if (exponent === undefined) throw new Error(`unknown currency ${currency}`);
  return Math.round(amount * 10 ** exponent);
}
