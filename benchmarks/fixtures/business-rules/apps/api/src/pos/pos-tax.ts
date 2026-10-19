import { roundHalfAwayFromZero } from '../money/money-policy';

/**
 * POS tax for KSA registers (the only POS market; SAR only — ai/business-domain.md § Tax policy).
 * The standard rate is effective-dated here and copied onto every receipt line, so a receipt
 * re-rendered after a rate change keeps the rate it was issued with.
 */
export const POS_VAT_RATE_BP = 1500;

export const POS_VAT_RATES = [
  { validFrom: '2018-01-01', rateBp: 500 },
  { validFrom: '2020-07-01', rateBp: POS_VAT_RATE_BP },
] as const;

export function posVatRateBp(at: Date): number {
  const day = at.toISOString().slice(0, 10);
  const row = [...POS_VAT_RATES].reverse().find((r) => r.validFrom <= day);
  if (!row) throw new Error(`no POS VAT rate on ${day}`);
  return row.rateBp;
}

export interface PosLine {
  priceMinor: number;
  quantity: number;
  discountMinor: number;
  inclusive: boolean;
  taxRateBp?: number;
  taxMinor?: number;
}

/**
 * Line-level tax: the base is the line after its discount; an inclusive price has its tax carved out,
 * never added. Each line is rounded once, and the receipt's totals are the sums of these rounded lines.
 */
export function taxLine(line: PosLine, at: Date): PosLine {
  const bp = posVatRateBp(at);
  const baseMinor = Math.max(0, line.priceMinor * line.quantity - line.discountMinor);
  const taxMinor = line.inclusive
    ? roundHalfAwayFromZero((baseMinor * bp) / (10_000 + bp))
    : roundHalfAwayFromZero((baseMinor * bp) / 10_000);
  return { ...line, taxRateBp: bp, taxMinor };
}

export function receiptTotals(lines: PosLine[]): { taxMinor: number; totalMinor: number } {
  const taxMinor = lines.reduce((s, l) => s + (l.taxMinor ?? 0), 0);
  const totalMinor = lines.reduce((s, l) => s + l.priceMinor * l.quantity - l.discountMinor + (l.inclusive ? 0 : l.taxMinor ?? 0), 0);
  return { taxMinor, totalMinor };
}
