import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

export interface PushMessage {
  userId: string;
  title: string;
  body: string;
  deepLink?: string;
}

@Injectable()
export class NotificationProducer {
  constructor(@InjectQueue('push') private readonly pushQueue: Queue<PushMessage>) {}

  /** Delivery status pushes to the merchant app; the worker's push processor fans them out to devices. */
  async push(message: PushMessage): Promise<void> {
    await this.pushQueue.add('push', message);
  }
}
