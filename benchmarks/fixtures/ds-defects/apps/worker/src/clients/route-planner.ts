import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class RoutePlanner {
  async pendingRegions(): Promise<string[]> {
    const res = await request(`${process.env.ROUTING_URL}/regions/pending`);
    return (await res.body.json()) as string[];
  }

  async planRegion(region: string): Promise<void> {
    await request(`${process.env.ROUTING_URL}/regions/${region}/plan`, { method: 'POST' });
  }
}
