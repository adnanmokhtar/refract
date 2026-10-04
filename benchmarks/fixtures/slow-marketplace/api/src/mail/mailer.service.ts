import { Injectable } from '@nestjs/common';
import { env } from '../common/env';

export interface OutgoingMail {
  to: string;
  template: string;
  fields: Record<string, string | number>;
}

// Transactional e-mail provider. Batch endpoint: up to 500 messages per call.
@Injectable()
export class MailerService {
  private readonly baseUrl = env('MAIL_API_URL');

  async sendBatch(messages: OutgoingMail[]): Promise<void> {
    for (let i = 0; i < messages.length; i += 500) {
      const res = await fetch(`${this.baseUrl}/v1/batch`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ messages: messages.slice(i, i + 500) }),
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok) throw new Error(`mail batch failed with ${res.status}`);
    }
  }
}
