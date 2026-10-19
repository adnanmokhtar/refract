import { Injectable } from '@nestjs/common';
import { HttpClient } from './http-client';

export interface GeoPoint {
  lat: number;
  lon: number;
}

/** The maps provider's geocoding API (shared quota: 50 req/s for the whole company). */
@Injectable()
export class GeoClient {
  constructor(private readonly http: HttpClient) {}

  async geocode(address: string, signal: AbortSignal): Promise<GeoPoint> {
    return this.http.call<GeoPoint>({
      method: 'GET',
      url: `${process.env.MAPS_API_URL}/geocode?q=${encodeURIComponent(address)}`,
      requestTimeout: 5_000,
      retry: { attempts: 3, backoffMs: 500 },
      signal,
    });
  }
}
