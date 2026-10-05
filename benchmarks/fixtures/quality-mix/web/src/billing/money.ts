// The portal's amount fields are free text ("12.5", "12,50"). The API takes integer cents.
export function amountInputToCents(amountInput: string): number {
  return Math.round(parseFloat(amountInput.trim().replace(',', '.')) * 100);
}

export function formatCents(cents: number, currency: string, locale?: string): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(cents / 100);
}
