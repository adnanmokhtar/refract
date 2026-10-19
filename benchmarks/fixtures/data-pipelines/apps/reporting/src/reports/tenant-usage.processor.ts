import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import { EntityManager } from '@mikro-orm/postgresql';

/**
 * Recomputes a tenant's seat usage for a day. Find-then-insert inside a transaction; the unique
 * (tenant_id, day) constraint makes a racing duplicate fail and BullMQ retries it as an update.
 */
@Processor('tenant-usage')
export class TenantUsageProcessor extends WorkerHost {
  constructor(private readonly em: EntityManager) {
    super();
  }

  async process(job: Job<{ tenantId: string; day: string; seats: number }>): Promise<void> {
    await this.em.transactional(async (tx) => {
      const conn = tx.getConnection();
      const [row] = await conn.execute(`select seats from tenant_usage_daily where tenant_id = ? and day = ?`, [job.data.tenantId, job.data.day]);
      if (row) {
        await conn.execute(`update tenant_usage_daily set seats = ? where tenant_id = ? and day = ?`, [job.data.seats, job.data.tenantId, job.data.day]);
      } else {
        await conn.execute(`insert into tenant_usage_daily (tenant_id, day, seats) values (?, ?, ?)`, [job.data.tenantId, job.data.day, job.data.seats]);
      }
    });
  }
}
