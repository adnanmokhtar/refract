import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class WmsCatalog {
  async pushSkus(merchantId: string, skus: string[], signal: AbortSignal): Promise<void> {
    const res = await request(`${process.env.WMS_URL}/catalog/${merchantId}`, {
      method: 'PUT',
      body: JSON.stringify({ skus }),
      headers: { 'content-type': 'application/json' },
      signal,
    });
    if (res.statusCode >= 400) throw new Error(`WMS ${res.statusCode}`);
  }
}
