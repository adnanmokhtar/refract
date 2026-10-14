import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../../http/outbound-client';

@Injectable()
export class CarrierBookingClient {
  constructor(private readonly http: OutboundClient) {}

  async book(orderId: string, parcels: number): Promise<{ id: string }> {
    return this.http.request({ method: 'POST', url: `${process.env.CARRIER_GW_URL}/bookings`, body: { orderId, parcels }, timeoutMs: 20_000 });
  }

  async cancel(bookingId: string): Promise<void> {
    await this.http.request({ method: 'DELETE', url: `${process.env.CARRIER_GW_URL}/bookings/${bookingId}` });
  }

  async bookOutbound(exchangeId: string): Promise<void> {
    await this.http.request({ method: 'PUT', url: `${process.env.CARRIER_GW_URL}/bookings/by-ref/${exchangeId}` });
  }

  async cancelOutbound(exchangeId: string): Promise<void> {
    await this.http.request({ method: 'DELETE', url: `${process.env.CARRIER_GW_URL}/bookings/by-ref/${exchangeId}` });
  }
}
