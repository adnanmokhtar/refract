import { Injectable } from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';
import { env } from '../common/env';

// The carrier aggregator answers in ~150 ms at p99; anything slower is an outage on their side.
const CARRIER_TIMEOUT_MS = 3_000;

export interface QuoteItem {
  sku: string;
  quantity: number;
  weightKg: number;
  originPostcode: string;
}

export interface Destination {
  country: string;
  postcode: string;
}

export interface Quote {
  carrier: string;
  service: string;
  amountCents: number;
  currency: string;
  etaDays: number;
}

export interface TrackingInfo {
  status: string;
  lastEvent?: string;
  eta?: string;
}

@Injectable()
export class CarrierClient {
  private readonly http: AxiosInstance;

  constructor() {
    this.http = axios.create({
      baseURL: env('CARRIER_API_URL'),
      timeout: CARRIER_TIMEOUT_MS,
      headers: { 'x-api-key': env('CARRIER_API_KEY') },
    });
  }

  async quote(item: QuoteItem, destination: Destination): Promise<Quote> {
    const { data } = await this.http.post<Quote>(
      '/v2/quotes',
      { item, destination },
      { signal: AbortSignal.timeout(CARRIER_TIMEOUT_MS) },
    );
    return data;
  }

  async pickupWindow(warehouseId: string, day: string): Promise<{ from: string; to: string } | null> {
    const { data } = await this.http.get(`/v2/warehouses/${encodeURIComponent(warehouseId)}/pickup`, {
      params: { day },
      signal: AbortSignal.timeout(CARRIER_TIMEOUT_MS),
    });
    return data ?? null;
  }

  async tracking(ref?: string): Promise<TrackingInfo | null> {
    if (!ref) return null;
    const { data } = await this.http.get<TrackingInfo>(`/v2/tracking/${encodeURIComponent(ref)}`, {
      signal: AbortSignal.timeout(CARRIER_TIMEOUT_MS),
    });
    return data;
  }
}
