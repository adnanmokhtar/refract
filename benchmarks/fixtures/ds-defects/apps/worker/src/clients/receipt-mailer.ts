import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class ReceiptMailer {
  async sendReceipt(orderId: string): Promise<void> {
    const res = await request(`${process.env.MAIL_API_URL}/send`, {
      method: 'POST',
      body: JSON.stringify({ template: 'receipt', orderId }),
      headers: { 'content-type': 'application/json', 'idempotency-key': `receipt-${orderId}` },
    });
    if (res.statusCode >= 400) throw new Error(`mail API ${res.statusCode}`);
  }
}
