import { Injectable } from '@nestjs/common';

/** Order and ticket notifications by SMS through the carrier's REST API. */
@Injectable()
export class SmsClient {
  private readonly from = process.env.SMS_SENDER_ID ?? 'QuillDesk';

  async send(to: string, text: string): Promise<{ id: string }> {
    const res = await fetch('https://sms.example.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.SMS_API_TOKEN}` },
      body: JSON.stringify({ to, from: this.from, text }),
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) throw new Error(`sms provider answered ${res.status}`);
    return res.json();
  }
}
