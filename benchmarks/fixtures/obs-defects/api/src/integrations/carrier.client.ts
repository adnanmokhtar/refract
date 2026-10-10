import { Injectable } from '@nestjs/common';
import { trace } from '@opentelemetry/api';
import axios, { AxiosInstance } from 'axios';

export interface Parcel { weightGrams: number; postcode: string; country: string }
export interface Quote { service: string; amountCents: number; etaDays: number }

@Injectable()
export class CarrierClient {
  private readonly http: AxiosInstance = axios.create({ timeout: 5_000 });
  private readonly baseUrl = process.env.CARRIER_API_URL ?? 'https://api.carrier.example';

  async quote(parcel: Parcel): Promise<Quote> {
    const url = `${this.baseUrl}/v2/quotes`;
    trace.getActiveSpan()?.setAttribute('http.url', url);
    const { data } = await this.http.post<Quote>(url, parcel);
    return data;
  }
}
