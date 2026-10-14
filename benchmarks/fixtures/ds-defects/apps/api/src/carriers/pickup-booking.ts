import { Injectable } from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';
import pRetry from 'p-retry';
import { randomUUID } from 'node:crypto';

/**
 * Books a courier pickup at a merchant's warehouse with the regional courier (Kurier24). Their API
 * deduplicates POST /pickups on the Idempotency-Key header for 24 h.
 */
@Injectable()
export class PickupBooking {
  private readonly http: AxiosInstance = axios.create({ baseURL: process.env.KURIER24_API_URL, timeout: 10_000 });

  async book(warehouseId: string, date: string, parcels: number): Promise<string> {
    const body = { warehouseId, date, parcels };
    const res = await pRetry(
      () => this.http.post('/pickups', body, { headers: { 'Idempotency-Key': randomUUID() } }),
      { retries: 4, randomize: true, minTimeout: 500 },
    );
    return res.data.pickupId as string;
  }
}
