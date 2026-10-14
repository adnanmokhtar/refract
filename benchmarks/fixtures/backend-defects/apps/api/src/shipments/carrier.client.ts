import { Injectable } from '@nestjs/common';
import { OutboundHttp } from '../common/http-client';

@Injectable()
export class CarrierClient {
  constructor(private readonly http: OutboundHttp) {}

  async bookPickup(shipmentId: string): Promise<void> {
    await this.http.postJson('carrier', 'https://carrier.example.test/pickups', { shipmentId });
  }
}
