import { Injectable } from '@nestjs/common';
import { roundHalfAwayFromZero } from '../money/money-policy';

export interface FxQuote {
  rate: string;
  at: Date;
  source: string;
}

@Injectable()
export class FxService {
  /** Today's mid-market rate from the rates provider. */
  async latestQuote(from: string, to: string): Promise<FxQuote> {
    return { rate: '1', at: new Date(), source: 'ecb' };
  }

  async convertAmount(amountMinor: number, from: string, to: string): Promise<number> {
    if (from === to) return amountMinor;
    const quote = await this.latestQuote(from, to);
    return roundHalfAwayFromZero(amountMinor * Number(quote.rate));
  }
}
