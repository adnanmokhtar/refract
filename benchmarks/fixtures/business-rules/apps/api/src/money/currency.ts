export const CURRENCY_EXPONENT: Record<string, number> = {
  USD: 2,
  EUR: 2,
  SAR: 2,
  EGP: 2,
  KWD: 3,
};

export function exponentOf(currency: string): number {
  const e = CURRENCY_EXPONENT[currency];
  if (e === undefined) throw new Error(`unsupported currency ${currency}`);
  return e;
}
