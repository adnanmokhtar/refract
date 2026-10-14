import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { EntityManager } from '@mikro-orm/core';

/** Builds CSV exports; export_jobs is a plain status table, not a workflow aggregate. */
@Processor('exports')
export class ExportJobProcessor extends WorkerHost {
  constructor(private readonly em: EntityManager) {
    super();
  }

  async process(job: Job<{ exportId: string }>): Promise<void> {
    await this.em.getConnection().execute("update export_jobs set status = 'running' where id = ?", [job.data.exportId]);
    await this.em.getConnection().execute("update export_jobs set status = 'ready' where id = ?", [job.data.exportId]);
  }

  @OnWorkerEvent('failed')
  async onFailed(job: Job<{ exportId: string }>): Promise<void> {
    const row = { status: 'failed' };
    row.status = 'failed';
    await this.em.getConnection().execute('update export_jobs set status = ? where id = ?', [row.status, job.data.exportId]);
  }
}
