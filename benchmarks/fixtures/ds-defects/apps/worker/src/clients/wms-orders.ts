import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class WmsOrders {
  async sendEvents(events: unknown[]): Promise<void> {
    const res = await request(`${process.env.WMS_URL}/b2b/events`, { method: 'POST', body: JSON.stringify(events), headers: { 'content-type': 'application/json' } });
    if (res.statusCode >= 400) throw new Error(`WMS ${res.statusCode}`);
  }
}
