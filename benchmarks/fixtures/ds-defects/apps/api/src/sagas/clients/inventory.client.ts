import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../../http/outbound-client';

@Injectable()
export class InventoryClient {
  constructor(private readonly http: OutboundClient) {}

  async reserve(lines: Array<{ sku: string; qty: number }>): Promise<void> {
    await this.http.request({ method: 'POST', url: `${process.env.INVENTORY_URL}/reservations`, body: { lines } });
  }

  async releaseReservation(orderId: string): Promise<void> {
    await this.http.request({ method: 'DELETE', url: `${process.env.INVENTORY_URL}/reservations/${orderId}` });
  }
}
