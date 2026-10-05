import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { PaymentDeclinedError } from '../common/errors';

const ChargeList = z.object({ data: z.array(z.object({ id: z.string(), status: z.string(), amount: z.number().int() })) });
const RefundBody = z.object({ id: z.string() });

export interface ProviderCharge {
  id: string;
  status: 'succeeded' | 'failed';
  amountCents: number;
}

// The payment provider's REST API. 402 = declined, 409 = idempotency replay, 5xx = retry later.
@Injectable()
export class ProviderClient {
  private readonly baseUrl = process.env.PAYMENT_PROVIDER_URL;
  private readonly headers = {
    'content-type': 'application/json',
    authorization: `Bearer ${process.env.PAYMENT_PROVIDER_TOKEN}`,
  };

  async createCharge(customerRef: string, amountCents: number, currency: string, idempotencyKey: string): Promise<ProviderCharge> {
    const res = await fetch(`${this.baseUrl}/v1/charges`, {
      method: 'POST',
      headers: { ...this.headers, 'idempotency-key': idempotencyKey },
      body: JSON.stringify({ customer: customerRef, amount: amountCents, currency }),
      signal: AbortSignal.timeout(10_000),
    });
    const body = await res.json();
    return { id: body.id, status: body.status, amountCents: body.amount };
  }

  async listCharges(customerRef: string): Promise<ProviderCharge[]> {
    const res = await fetch(`${this.baseUrl}/v1/charges?customer=${encodeURIComponent(customerRef)}`, {
      headers: this.headers,
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`provider list charges: ${res.status}`);
    const body = ChargeList.parse(await res.json());
    return body.data.map((c) => ({ id: c.id, status: c.status === 'succeeded' ? 'succeeded' : 'failed', amountCents: c.amount }));
  }

  async refund(chargeId: string, amountCents: number): Promise<{ id: string }> {
    const res = await fetch(`${this.baseUrl}/v1/refunds`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({ charge: chargeId, amount: amountCents }),
      signal: AbortSignal.timeout(10_000),
    });
    if (res.status === 402) throw new PaymentDeclinedError(`refund of ${chargeId} declined`);
    if (!res.ok) throw new Error(`provider refund: ${res.status}`);
    return RefundBody.parse(await res.json());
  }
}
