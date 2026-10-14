import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class DeliveryMailer {
  async sendDeliveredEmail(to: string, trackingNo: string, signal: AbortSignal): Promise<void> {
    await request(`${process.env.MAIL_API_URL}/send`, {
      method: 'POST',
      body: JSON.stringify({ to, template: 'delivered', trackingNo }),
      headers: { 'content-type': 'application/json' },
      signal,
    });
  }
}
