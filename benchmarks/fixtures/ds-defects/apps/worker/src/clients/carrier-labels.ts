import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class CarrierLabels {
  async buy(carrier: string, shipmentId: string, signal: AbortSignal): Promise<Buffer> {
    const res = await request(`${process.env.CARRIER_GW_URL}/${carrier}/labels`, {
      method: 'POST',
      body: JSON.stringify({ shipmentId }),
      headers: { 'content-type': 'application/json' },
      signal,
    });
    if (res.statusCode >= 400) throw new Error(`label purchase failed: ${res.statusCode}`);
    return Buffer.from(await res.body.arrayBuffer());
  }

  async store(shipmentId: string, pdf: Buffer): Promise<void> {
    await request(`${process.env.LABEL_STORE_URL}/${shipmentId}.pdf`, { method: 'PUT', body: pdf });
  }
}
