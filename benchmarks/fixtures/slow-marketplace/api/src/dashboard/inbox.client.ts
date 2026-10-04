import { Injectable } from '@nestjs/common';
import { env } from '../common/env';

// Buyer ↔ seller messaging lives in a separate service.
@Injectable()
export class InboxClient {
  private readonly baseUrl = env('INBOX_URL');

  async unreadCount(storeId: string): Promise<number> {
    const res = await fetch(`${this.baseUrl}/v1/stores/${storeId}/unread`, { signal: AbortSignal.timeout(1_000) });
    if (!res.ok) return 0;
    const body = (await res.json()) as { unread: number };
    return body.unread;
  }
}
