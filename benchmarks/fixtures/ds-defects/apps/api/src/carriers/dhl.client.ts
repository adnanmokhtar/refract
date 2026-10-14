import { Injectable } from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';
import axiosRetry from 'axios-retry';

export interface ShipmentBooking {
  shipmentId: string;
  parcels: Array<{ weightKg: number; lengthCm: number; widthCm: number; heightCm: number }>;
  shipTo: Record<string, string>;
}

/** DHL Parcel API client: creates shipments (one label per parcel) and cancels them. */
@Injectable()
export class DhlClient {
  private readonly http: AxiosInstance = axios.create({ baseURL: process.env.DHL_API_URL, timeout: 15_000 });

  constructor() {
    axiosRetry(this.http, { retries: 3, retryDelay: axiosRetry.exponentialDelay });
  }

  async createShipment(booking: ShipmentBooking): Promise<{ trackingNo: string; labelUrl: string }> {
    const { data } = await this.http.post('/v2/shipments', booking);
    return data;
  }

  async cancelShipment(trackingNo: string): Promise<void> {
    await this.http.delete(`/v2/shipments/${trackingNo}`);
  }
}
