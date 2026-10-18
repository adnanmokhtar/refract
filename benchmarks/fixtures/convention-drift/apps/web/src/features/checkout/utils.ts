// Checkout display helpers.
export function formatMoney(minor: number, currency = 'EUR', locale = 'en'): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(minor / 100);
}

export function couponCode(raw: string): string {
  return raw.trim().toUpperCase();
}
