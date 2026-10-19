import { Injectable } from '@nestjs/common';
import { HttpClient } from './http-client';

/**
 * Carrier ETA lookups. This client never retries (attempts 1): the eta-refresh job's own attempts are the one
 * retrying layer for this chain.
 */
@Injectable()
export class EtaClient {
  constructor(private readonly http: HttpClient) {}

  async fetchEta(trackingNo: string, signal: AbortSignal): Promise<{ eta: string }> {
    return this.http.call({ method: 'GET', url: `${process.env.CARRIER_GW_URL}/eta/${trackingNo}`, requestTimeout: 5_000, retry: { attempts: 1 }, signal });
  }
}
