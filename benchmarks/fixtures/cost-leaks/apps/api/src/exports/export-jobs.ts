import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { Queue } from 'bullmq';

export interface ExportJob {
  id: string;
  tenantId: string;
  kind: 'shipments' | 'invoices' | 'returns';
  from: string;
  to: string;
  key?: string;
}

@Injectable()
export class ExportJobs implements OnModuleInit {
  constructor(private readonly em: EntityManager, @InjectQueue('exports') private readonly queue: Queue) {}

  // Nightly scheduled exports: one job fans out to every merchant that enabled them.
  async onModuleInit(): Promise<void> {
    await this.queue.upsertJobScheduler('nightly-exports', { pattern: '30 1 * * *', tz: 'UTC' }, { name: 'fan-out' });
  }

  async findReady(tenantId: string, id: string): Promise<ExportJob | null> {
    const rows = await this.em.getConnection().execute<ExportJob[]>(
      `select id, tenant_id as "tenantId", kind, key from export_jobs where id = ? and tenant_id = ? and status = 'ready'`,
      [id, tenantId],
    );
    return rows[0] ?? null;
  }

  async markReady(id: string, key: string): Promise<void> {
    await this.em.getConnection().execute(`update export_jobs set status = 'ready', key = ? where id = ?`, [key, id]);
  }
}
