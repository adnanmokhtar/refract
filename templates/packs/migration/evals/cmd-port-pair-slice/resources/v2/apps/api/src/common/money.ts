import Decimal from 'decimal.js';

// V1 parity: PHP round() is half away from zero at every scale, negatives included.
// decimal.js ROUND_HALF_UP is the same rule (ties go away from zero).
export function roundHalfAway(value: number | string, scale: number): number {
  return new Decimal(value).toDecimalPlaces(scale, Decimal.ROUND_HALF_UP).toNumber();
}

export function toMoneyString(value: number | string): string {
  return new Decimal(value).toFixed(2);
}

// V1 Money::allocate: whole cents, remainder to the first parts, parts sum to the total.
export function allocateCents(total: number | string, count: number): string[] {
  const cents = new Decimal(total).times(100).toDecimalPlaces(0, Decimal.ROUND_HALF_UP).toNumber();
  const base = Math.trunc(cents / count);
  const remainder = cents - base * count;
  return Array.from({ length: count }, (_, i) => toMoneyString((base + (i < remainder ? 1 : 0)) / 100));
}
