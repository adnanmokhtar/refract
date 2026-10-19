import { Injectable } from '@nestjs/common';
import { Queue } from 'bullmq';
import { withTenant } from '../../shared/tenancy/tenant.filter';

@Injectable()
export class WebhooksService {
  private readonly queue = new Queue('webhooks', { connection: { host: 'localhost', port: 6379 } });

  async enqueue(tenantId: string, event: string, payload: unknown): Promise<void> {
    await withTenant(tenantId, async () => {
      await this.queue.add(event, { tenantId, payload }, { attempts: 5, backoff: { type: 'exponential', delay: 2000 } });
    });
  }
}
