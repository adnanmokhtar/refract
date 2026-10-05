// VAT on a subscription line, in minor units. Rates by country; B2B with a valid VAT id in another
// EU country is reverse-charged (0 here, the customer self-accounts).
const VAT_RATES: Record<string, number> = { DE: 0.19, FR: 0.2, NL: 0.21, SE: 0.25, AT: 0.2 };

export interface TaxInput {
  netCents: number;
  country: string;
  sellerCountry: string;
  b2bVatId?: string;
}

export function computeTax(input: TaxInput): number {
  if (input.b2bVatId && input.country !== input.sellerCountry) return 0;
  const rate = VAT_RATES[input.country] ?? 0;
  const exact = input.netCents * rate;
  // Banker's rounding on the half cent (fix: invoice totals off by a cent against the tax authority's calculator).
  const floor = Math.floor(exact);
  const diff = exact - floor;
  if (Math.abs(diff - 0.5) < 1e-9) return floor % 2 === 0 ? floor : floor + 1;
  return Math.round(exact);
}
