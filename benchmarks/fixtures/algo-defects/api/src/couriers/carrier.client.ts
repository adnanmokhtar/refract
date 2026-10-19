import { Injectable } from '@nestjs/common';

@Injectable()
export class CarrierClient {
  private readonly base = process.env.CARRIER_URL ?? 'https://carrier.kestrelway.example';

  /** References of shipments the carrier marked delivered since the last acknowledged call. */
  async deliveredRefs(opts: { limit: number }): Promise<string[]> {
    const res = await fetch(`${this.base}/v1/delivered?limit=${opts.limit}`);
    if (!res.ok) throw new Error(`carrier poll failed: ${res.status}`);
    const body = (await res.json()) as { refs: string[] };
    return body.refs.slice(0, opts.limit);
  }
}
