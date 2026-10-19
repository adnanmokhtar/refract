// Money: an integer count of minor units plus an ISO currency code. Never a float.

const SYMBOLS = { EUR: '€', GBP: '£', USD: '$' };

export function money(amountMinor, currency) {
  if (!Number.isInteger(amountMinor)) {
    throw new TypeError(`money(): amountMinor must be an integer count of minor units, got ${amountMinor}`);
  }
  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new TypeError(`money(): currency must be an ISO code, got ${currency}`);
  }
  return Object.freeze({ amountMinor, currency });
}

export function addMoney(a, b) {
  if (a.currency !== b.currency) {
    throw new TypeError(`addMoney(): ${a.currency} + ${b.currency}`);
  }
  return money(a.amountMinor + b.amountMinor, a.currency);
}

export function formatMoney(value) {
  const sign = value.amountMinor < 0 ? '-' : '';
  const abs = Math.abs(value.amountMinor);
  const units = Math.floor(abs / 100);
  const cents = String(abs % 100).padStart(2, '0');
  return `${sign}${SYMBOLS[value.currency] ?? value.currency + ' '}${units}.${cents}`;
}
