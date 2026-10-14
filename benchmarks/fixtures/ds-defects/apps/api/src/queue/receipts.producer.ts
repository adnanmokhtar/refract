import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { BaseProducer } from './base.producer';

export interface ReceiptJob {
  orderId: string;
}

@Injectable()
export class ReceiptsProducer extends BaseProducer<ReceiptJob> {
  constructor(@InjectQueue('receipts') queue: Queue<ReceiptJob>) {
    super(queue);
  }

  async sendReceipt(orderId: string): Promise<void> {
    await this.enqueue('send-receipt', { orderId });
  }
}
