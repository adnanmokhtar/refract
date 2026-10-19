import { exponentOf } from './currency';

/** Integer minor units → the decimal string a document or a payload carries (exponent per currency). */
export function formatMajor(minor: number, currency: string): string {
  const e = exponentOf(currency);
  const sign = minor < 0 ? '-' : '';
  const abs = Math.abs(minor).toString().padStart(e + 1, '0');
  return e === 0 ? sign + abs : `${sign}${abs.slice(0, -e)}.${abs.slice(-e)}`;
}
