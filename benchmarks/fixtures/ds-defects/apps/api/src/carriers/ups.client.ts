import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../http/outbound-client';

/**
 * UPS Shipping API. UPS stores the transaction reference sent in `transId` and answers a repeated create with
 * the original shipment (UPS Shipping API reference, "Idempotent requests": duplicates within 24 h return the
 * first response). The key is the shipment id, so every attempt and every job re-run sends the same one.
 */
@Injectable()
export class UpsClient {
  constructor(private readonly http: OutboundClient) {}

  async createShipment(shipmentId: string, payload: Record<string, unknown>): Promise<{ trackingNo: string }> {
    return this.http.request({
      method: 'POST',
      url: `${process.env.UPS_API_URL}/api/shipments/v2409/ship`,
      headers: { transId: `shipment-${shipmentId}`, 'Idempotency-Key': `shipment-${shipmentId}` },
      body: payload,
      retry: { attempts: 3 },
    });
  }
}
