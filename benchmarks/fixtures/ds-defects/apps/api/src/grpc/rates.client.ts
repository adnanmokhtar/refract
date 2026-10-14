import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../http/outbound-client';

export interface RateOffer {
  carrier: string;
  priceMinor: number;
  currency: string;
}

const CARRIER_RATE_URLS: Record<string, string> = {
  dhl: 'https://rates.dhl.example/v1/quote',
  ups: 'https://rates.ups.example/v1/quote',
  kurier24: 'https://api.kurier24.example/v1/rates',
};

@Injectable()
export class RatesClient {
  constructor(private readonly http: OutboundClient) {}

  async fetchAll(merchantId: string, weightKg: number, country: string): Promise<RateOffer[]> {
    return Promise.all(
      Object.entries(CARRIER_RATE_URLS).map(([carrier, url]) =>
        this.http.request<RateOffer>({ method: 'POST', url, body: { merchantId, weightKg, country, carrier }, timeoutMs: 5_000 }),
      ),
    );
  }
}
