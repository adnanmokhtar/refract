const EXPONENT: Record<string, number> = { USD: 2, EUR: 2, SAR: 2, EGP: 2, KWD: 3 };

/** Display only: amounts arrive as integer minor units and are never parsed back. */
export function formatMoney(minor: number, currency: string, locale = navigator.language): string {
  const major = minor / 10 ** (EXPONENT[currency] ?? 2);
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(major);
}
