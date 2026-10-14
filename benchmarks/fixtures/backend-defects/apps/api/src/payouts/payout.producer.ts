import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

export interface Payout {
  merchantId: string;
  amountMinor: number;
  currency: string;
}

@Injectable()
export class PayoutProducer {
  constructor(@InjectQueue('payouts') private readonly payoutsQueue: Queue) {}

  /** Integer minor units plus the currency: no float ever enters the payload. */
  async enqueue(payout: Payout): Promise<void> {
    await this.payoutsQueue.add('payout', { merchantId: payout.merchantId, amountMinor: payout.amountMinor, currency: payout.currency });
  }
}
