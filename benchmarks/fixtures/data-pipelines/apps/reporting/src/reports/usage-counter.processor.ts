import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import type { Knex } from 'knex';

/** One job per API call batch; BullMQ retries a failed job up to 5 times (queue default attempts: 5). */
@Processor('usage')
export class UsageCounterProcessor extends WorkerHost {
  constructor(private readonly knex: Knex) {
    super();
  }

  async process(job: Job<{ tenantId: string; calls: number }>): Promise<void> {
    const day = this.knex.raw(`(now() at time zone 'UTC')::date`);
    await this.knex('api_usage_daily').where({ tenant_id: job.data.tenantId, day }).increment('calls', job.data.calls);
    await this.notifyQuota(job.data.tenantId);
  }

  private async notifyQuota(tenantId: string): Promise<void> {
    await this.knex('quota_events').insert({ tenant_id: tenantId, at: this.knex.fn.now() });
  }
}
