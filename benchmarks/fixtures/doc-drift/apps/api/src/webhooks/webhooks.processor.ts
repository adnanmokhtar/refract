import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';

import { backoffMs } from '../billing/retry';
import { loadConfig } from '../config/config.loader';

@Processor('webhook-deliveries')
export class WebhookDeliveryProcessor extends WorkerHost {
  private readonly limit = loadConfig().RETRY_LIMIT;

  async process(job: Job<{ endpointId: string; payload: string }>): Promise<void> {
    if (job.attemptsMade >= this.limit) {
      await job.log(`parking delivery to ${job.data.endpointId} after ${job.attemptsMade} attempts`);
      return;
    }
    await job.updateData({ ...job.data });
    await job.log(`next attempt in ${backoffMs(job.attemptsMade)} ms`);
  }
}
