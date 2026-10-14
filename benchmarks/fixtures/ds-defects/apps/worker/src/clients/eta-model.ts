import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class EtaModel {
  async predict(shipmentId: string): Promise<string> {
    const res = await request(`${process.env.ETA_MODEL_URL}/predict/${shipmentId}`);
    return ((await res.body.json()) as { eta: string }).eta;
  }
}
