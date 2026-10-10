import { Injectable } from '@nestjs/common';
import { context, propagation } from '@opentelemetry/api';
import axios from 'axios';

// Only these headers may leave the cluster towards the fulfilment partner.
const FORWARD_HEADERS = ['content-type', 'accept', 'authorization', 'idempotency-key'];

function pick(source: Record<string, string>, keys: string[]): Record<string, string> {
  return Object.fromEntries(Object.entries(source).filter(([k]) => keys.includes(k.toLowerCase())));
}

@Injectable()
export class PartnerClient {
  private readonly baseUrl = process.env.PARTNER_API_URL ?? 'https://fulfilment.partner.example';

  async createShipment(orderId: string, body: unknown, token: string): Promise<string> {
    const carrier: Record<string, string> = {
      'content-type': 'application/json',
      authorization: `Bearer ${token}`,
      'idempotency-key': `shipment-${orderId}`,
    };
    propagation.inject(context.active(), carrier);
    const { data } = await axios.post<{ id: string }>(`${this.baseUrl}/v1/shipments`, body, {
      headers: pick(carrier, FORWARD_HEADERS),
      timeout: 10_000,
    });
    return data.id;
  }
}
