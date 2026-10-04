import { Injectable } from '@nestjs/common';
import { env } from '../common/env';

export interface Recommendation {
  productId: string;
  slug: string;
  title: string;
  priceCents: number;
  currency: string;
  imageUrl: string;
}

// Internal recommendations service (owned by the data team). Best effort: an empty rail is fine.
@Injectable()
export class RecommendationsClient {
  private readonly baseUrl = env('RECS_URL');

  async similarTo(productIds: string[], opts: { limit: number }): Promise<Recommendation[]> {
    try {
      const res = await fetch(`${this.baseUrl}/v1/similar`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ productIds: productIds.slice(0, 20), limit: opts.limit }),
        signal: AbortSignal.timeout(800),
      });
      if (!res.ok) return [];
      return (await res.json()) as Recommendation[];
    } catch {
      return [];
    }
  }

  // The platform-wide "featured" ranking. Expensive on their side: cache the result.
  async featured(opts: { limit: number }): Promise<Recommendation[]> {
    const res = await fetch(`${this.baseUrl}/v1/featured?limit=${opts.limit}`, { signal: AbortSignal.timeout(5_000) });
    if (!res.ok) throw new Error(`featured ranking failed with ${res.status}`);
    return (await res.json()) as Recommendation[];
  }
}
