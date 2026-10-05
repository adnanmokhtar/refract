export function formatPrice(minor: number, locale = 'en', currency = 'USD') {
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(minor / 100);
}

export function formatDate(iso: string, locale = 'en') {
  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium', timeZone: 'UTC' }).format(new Date(iso));
}
