import { Injectable } from '@nestjs/common';
import { OutboundClient } from '../../http/outbound-client';

@Injectable()
export class ReturnsClient {
  constructor(private readonly http: OutboundClient) {}

  async issueReturnLabel(exchangeId: string): Promise<void> {
    await this.http.request({ method: 'PUT', url: `${process.env.RETURNS_URL}/labels/${exchangeId}` });
  }

  async cancelReturnLabel(exchangeId: string): Promise<void> {
    await this.http.request({ method: 'DELETE', url: `${process.env.RETURNS_URL}/labels/${exchangeId}` });
  }
}
