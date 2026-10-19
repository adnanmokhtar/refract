import { HttpClient } from '../lib/http';
import { fetchWithRetry } from '../lib/retry';

export interface CaptureResult { id: string; status: 'captured' | 'declined' }

export class ProviderClient {
  constructor(private readonly http: HttpClient, private readonly base: string) {}

  async authorize(paymentId: string, amountMinor: number): Promise<CaptureResult> {
    const body = JSON.stringify({ payment_id: paymentId, amount: amountMinor });
    return this.http.post(`${this.base}/authorizations`, body, { timeoutMs: 3000 });
  }

  async capture(paymentId: string, amountMinor: number): Promise<CaptureResult> {
    const body = JSON.stringify({ payment_id: paymentId, amount: amountMinor });
    return fetchWithRetry(() => this.http.post(`${this.base}/captures`, body, { timeoutMs: 3000 }), { retries: 8, backoffMs: 0 });
  }
}
