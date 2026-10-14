import { Injectable } from '@nestjs/common';

export interface Rates {
  base: string;
  rates: Record<string, number>;
}

@Injectable()
export class FxClient {
  async latest(base: string): Promise<Rates> {
    const res = await fetch(`https://fx.example.test/latest?base=${encodeURIComponent(base)}`, { signal: AbortSignal.timeout(3000) });
    if (!res.ok) throw new Error(`fx provider answered ${res.status}`);
    return (await res.json()) as Rates;
  }
}
