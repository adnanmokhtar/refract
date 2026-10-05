import { Injectable } from '@nestjs/common';

export interface FxQuote {
  base: string;
  quote: string;
  rate: number;
  asOf: string;
}

// Cross-currency refunds are quoted at the provider's mid-market rate of the refund day.
@Injectable()
export class FxRateClient {
  constructor(private readonly baseUrl = process.env.FX_BASE_URL ?? 'https://api.exchangerate.host') {}

  async quote(base: string, quote: string): Promise<FxQuote> {
    const res = await fetch(`${this.baseUrl}/latest?base=${base}&symbols=${quote}`, {
      signal: AbortSignal.timeout(3_000),
    });
    if (!res.ok) throw new Error(`fx provider answered ${res.status}`);
    const body = (await res.json()) as { base: string; date: string; rates: Record<string, number> };
    const rate = body.rates[quote];
    if (typeof rate !== 'number') throw new Error(`fx provider has no ${base}/${quote} rate`);
    return { base, quote, rate, asOf: body.date };
  }

  convert(amountCents: number, fx: FxQuote): number {
    return Math.round(amountCents * fx.rate);
  }
}
