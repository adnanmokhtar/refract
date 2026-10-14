import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../http/outbound-client';

@Injectable()
export class SmsGateway {
  constructor(private readonly http: OutboundClient) {}

  async send(to: string, text: string): Promise<void> {
    await this.http.request({ method: 'POST', url: `${process.env.SMS_API_URL}/messages`, body: { to, text }, timeoutMs: 5_000 });
  }
}
