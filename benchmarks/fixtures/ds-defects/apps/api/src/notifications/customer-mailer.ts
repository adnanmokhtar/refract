import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../http/outbound-client';

@Injectable()
export class CustomerMailer {
  constructor(private readonly http: OutboundClient) {}

  sendShippedEmail(to: string, trackingNo: string): void {
    void this.http.request({ method: 'POST', url: `${process.env.MAIL_API_URL}/send`, body: { to, template: 'shipped', trackingNo } });
  }
}
