import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../../http/outbound-client';

@Injectable()
export class WmsClient {
  constructor(private readonly http: OutboundClient) {}

  async createPickWave(orderId: string, lines: Array<{ sku: string; qty: number }>): Promise<void> {
    await this.http.request({ method: 'PUT', url: `${process.env.WMS_URL}/waves/by-order/${orderId}`, body: { lines } });
  }

  async cancelPickWaveForOrder(orderId: string): Promise<void> {
    await this.http.request({ method: 'DELETE', url: `${process.env.WMS_URL}/waves/by-order/${orderId}` });
  }

  async allocateReplacement(exchangeId: string, sku: string): Promise<void> {
    await this.http.request({ method: 'PUT', url: `${process.env.WMS_URL}/replacements/${exchangeId}`, body: { sku } });
  }

  async releaseReplacement(exchangeId: string): Promise<void> {
    await this.http.request({ method: 'DELETE', url: `${process.env.WMS_URL}/replacements/${exchangeId}` });
  }

  async releaseBay(bayId: string): Promise<void> {
    await this.http.request({ method: 'POST', url: `${process.env.WMS_URL}/bays/${bayId}/decrement-in-use` });
  }

  async occupyBay(bayId: string, consolidationId: string): Promise<void> {
    await this.http.request({ method: 'POST', url: `${process.env.WMS_URL}/bays/${bayId}/increment-in-use`, body: { consolidationId } });
  }
}
