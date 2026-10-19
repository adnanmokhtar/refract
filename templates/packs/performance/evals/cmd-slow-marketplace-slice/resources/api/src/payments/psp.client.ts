import { Injectable, Logger } from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';
import { env } from '../common/env';

export interface CaptureResult {
  id: string;
  status: 'succeeded' | 'requires_action' | 'failed';
  amountCaptured: number;
}

export interface RefundResult {
  id: string;
  status: 'pending' | 'succeeded' | 'failed';
}

// Payment service provider (card capture, refunds). Captures are idempotent on the intent id.
@Injectable()
export class PspClient {
  private readonly logger = new Logger(PspClient.name);
  private readonly http: AxiosInstance;

  constructor() {
    this.http = axios.create({
      baseURL: env('PSP_BASE_URL'),
      headers: {
        Authorization: `Bearer ${env('PSP_SECRET_KEY')}`,
        'Psp-Version': '2024-06-20',
      },
    });
  }

  async capture(intentId: string, amountCents: number): Promise<CaptureResult> {
    const { data } = await this.http.post<CaptureResult>(`/v1/payment_intents/${encodeURIComponent(intentId)}/capture`, {
      amount_to_capture: amountCents,
    });
    if (data.status !== 'succeeded') this.logger.warn(`capture ${intentId} returned ${data.status}`);
    return data;
  }

  async refund(intentId: string, amountCents: number, reason: string): Promise<RefundResult> {
    const { data } = await this.http.post<RefundResult>('/v1/refunds', {
      payment_intent: intentId,
      amount: amountCents,
      reason,
    });
    return data;
  }
}
