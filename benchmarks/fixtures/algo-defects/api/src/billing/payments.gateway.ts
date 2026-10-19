import { Injectable } from '@nestjs/common';

@Injectable()
export class PaymentsGateway {
  private readonly base = process.env.PSP_URL ?? 'https://psp.kestrelway.example';

  async capture(orderId: string, amountMinor: number, currency: string): Promise<void> {
    const res = await fetch(`${this.base}/v2/captures`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'idempotency-key': orderId },
      body: JSON.stringify({ order_id: orderId, amount: amountMinor, currency }),
    });
    if (!res.ok) throw new Error(`capture failed: ${res.status}`);
  }
}
