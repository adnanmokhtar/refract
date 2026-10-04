import { Injectable } from '@nestjs/common';
import { createHmac } from 'node:crypto';
import { env } from '../common/env';

// Outgoing webhooks to sellers' own endpoints (order.paid, order.cancelled, payout.paid).
@Injectable()
export class WebhookSender {
  async post(url: string, body: unknown): Promise<void> {
    const payload = JSON.stringify(body);
    const signature = createHmac('sha256', env('WEBHOOK_SIGNING_KEY')).update(payload).digest('hex');
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-stallwise-signature': signature },
      body: payload,
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) throw new Error(`webhook ${url} answered ${res.status}`);
  }
}
