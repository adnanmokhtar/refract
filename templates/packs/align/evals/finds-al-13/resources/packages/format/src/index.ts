import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';

dayjs.extend(relativeTime);

export function formatMoney(minor: number, currency = 'EUR', locale = 'en'): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(minor / 100);
}

export function formatDate(iso: string, locale = 'en'): string {
  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(new Date(iso));
}

export function formatRelative(iso: string): string {
  return dayjs(iso).fromNow();
}
