// Tax shown on the checkout summary before the customer pays. Must match the invoice.
const VAT_RATES: Record<string, number> = { DE: 0.19, FR: 0.2, NL: 0.21, SE: 0.25, AT: 0.2 };

export interface TaxInput {
  netCents: number;
  country: string;
  sellerCountry: string;
  b2bVatId?: string;
}

export function computeTax(input: TaxInput): number {
  const rate = VAT_RATES[input.country] ?? 0;
  return Math.round(input.netCents * rate);
}
