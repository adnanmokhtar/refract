import { Injectable } from '@nestjs/common';

export interface ReturnLabel {
  trackingNumber: string;
  labelUrl: string;
  carrier: string;
  costCents: number;
}

// The carrier's label API (v3). Its response shape is the carrier's, not ours.
@Injectable()
export class CarrierClient {
  private readonly baseUrl = process.env.CARRIER_BASE_URL;

  async createReturnLabel(orderId: string, fromPostcode: string, weightGrams: number): Promise<ReturnLabel> {
    const res = await fetch(`${this.baseUrl}/v3/labels`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.CARRIER_API_TOKEN}` },
      body: JSON.stringify({ reference: orderId, direction: 'return', from: { postcode: fromPostcode }, parcel: { weight_g: weightGrams } }),
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) throw new Error(`carrier answered ${res.status}`);
    const body = await res.json();
    return {
      trackingNumber: body.tracking.number,
      labelUrl: body.documents[0].url,
      carrier: body.service.carrier_code,
      costCents: Math.round(body.price.amount * 100),
    };
  }
}
