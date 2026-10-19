import { Injectable } from '@nestjs/common';

export interface RefundResult {
  id: string;
  status: 'pending' | 'succeeded' | 'failed';
}

/** Thin client over the payment service (internal HTTP). */
@Injectable()
export class PaymentsClient {
  private readonly base = process.env.PAYMENTS_URL ?? 'http://payments.internal:8080';

  async refund(paymentIntentId: string | undefined, amountMinor: number, idempotencyKey: string): Promise<RefundResult> {
    const res = await fetch(`${this.base}/refunds`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'idempotency-key': idempotencyKey },
      body: JSON.stringify({ paymentIntentId, amountMinor }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`payments answered ${res.status}`);
    return res.json();
  }
}
