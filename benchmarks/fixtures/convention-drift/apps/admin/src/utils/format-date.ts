export function formatDate(iso: string, locale = 'en'): string {
  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(new Date(iso));
}
