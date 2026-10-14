import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class PartnerFeed {
  async publish(rows: unknown[]): Promise<void> {
    await request(`${process.env.PARTNER_FEED_URL}/orders`, { method: 'POST', body: JSON.stringify(rows), headers: { 'content-type': 'application/json' } });
  }
}
