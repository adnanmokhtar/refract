import ar from '../locales/ar.json';
import en from '../locales/en.json';

const catalogs = { en, ar } as const;
type Locale = keyof typeof catalogs;
let current: Locale = 'en';

export function setLocale(next: Locale) {
  current = next;
}

export function t(key: string): string {
  const value = key.split('.').reduce<unknown>((node, part) => (node as Record<string, unknown> | undefined)?.[part], catalogs[current]);
  return typeof value === 'string' ? value : key;
}
