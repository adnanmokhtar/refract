import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import axiosRetry from 'axios-retry';

const psp = axios.create({ baseURL: 'https://psp.example.test/v2', timeout: 8000 });
axiosRetry(psp, { retries: 3, retryDelay: axiosRetry.exponentialDelay });

@Injectable()
export class PspClient {
  private readonly logger = new Logger(PspClient.name);

  async capture(orderId: string, amountMinor: number, currency: string): Promise<{ captureId: string }> {
    const { data } = await psp.post('/captures', { reference: orderId, amount: amountMinor, currency });
    return data;
  }

  async refund(captureId: string, amountMinor: number): Promise<void> {
    try {
      await psp.post(`/captures/${captureId}/refunds`, { amount: amountMinor });
    } catch (err) {
      this.logger.error(`refund failed for ${captureId}: ${(err as Error).message}`);
      throw err;
    }
  }
}
