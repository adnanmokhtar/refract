import { createHmac } from 'node:crypto';

import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import type { Queue } from 'bullmq';

import { loadConfig } from '../config/config.loader';

@Injectable()
export class WebhooksService {
  private readonly secret = loadConfig().WEBHOOK_SECRET;

  constructor(@InjectQueue('webhook-deliveries') private readonly deliveries: Queue) {}

  listEndpoints() {
    return [];
  }

  createEndpoint(url: string, events: string[]) {
    return { id: 'whe_new', url, events };
  }

  sign(payload: string, timestamp: number): string {
    return createHmac('sha256', this.secret).update(`${timestamp}.${payload}`).digest('hex');
  }

  enqueue(endpointId: string, payload: string) {
    return this.deliveries.add('deliver', { endpointId, payload });
  }
}
