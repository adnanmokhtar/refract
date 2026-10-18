// Display only. Amounts arrive from the API as V1-rounded decimal strings ("1043.39") and are
// never computed on the client; Intl rounds only what it renders.
export function formatMoney(amount: string, currency: string, locale = 'ar-SA'): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency, maximumFractionDigits: 2 }).format(Number(amount));
}

export function formatDate(iso: string | null, locale = 'ar-SA'): string {
  return iso ? new Intl.DateTimeFormat(locale, { dateStyle: 'medium', timeZone: 'Asia/Riyadh' }).format(new Date(iso)) : '—';
}
