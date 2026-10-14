import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class PspClient {
  async transfer(t: { merchantId: string; amountMinor: number; currency: string; idempotencyKey?: string }, signal: AbortSignal): Promise<void> {
    const res = await request(`${process.env.PSP_URL}/v1/transfers`, {
      method: 'POST',
      body: JSON.stringify(t),
      headers: { 'content-type': 'application/json', ...(t.idempotencyKey ? { 'Idempotency-Key': t.idempotencyKey } : {}) },
      signal,
    });
    if (res.statusCode >= 400) throw new Error(`PSP transfer ${res.statusCode}`);
  }

  async charge(c: { customerId: string; amountMinor: number; currency: string; idempotencyKey: string }, signal: AbortSignal): Promise<void> {
    const res = await request(`${process.env.PSP_URL}/v1/charges`, {
      method: 'POST',
      body: JSON.stringify(c),
      headers: { 'content-type': 'application/json', 'Idempotency-Key': c.idempotencyKey },
      signal,
    });
    if (res.statusCode >= 400) throw new Error(`PSP charge ${res.statusCode}`);
  }
}
