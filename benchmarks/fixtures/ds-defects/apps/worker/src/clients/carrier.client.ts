import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class CarrierClient {
  async closeShipment(trackingNo: string, signal: AbortSignal): Promise<void> {
    const res = await request(`${process.env.CARRIER_GW_URL}/shipments/${trackingNo}/close`, { method: 'POST', signal });
    if (res.statusCode >= 400) throw new Error(`carrier close failed: ${res.statusCode}`);
  }
}
