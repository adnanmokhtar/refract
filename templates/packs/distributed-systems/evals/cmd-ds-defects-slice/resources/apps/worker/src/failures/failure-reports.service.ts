import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Writes a row the on-call dashboard lists and pages on (alert: failed_jobs_unacknowledged > 0 for 15m). */
@Injectable()
export class FailureReports {
  constructor(private readonly em: EntityManager) {}

  async file(report: { queue: string; jobId?: string; attempts: number; error: string }): Promise<void> {
    await this.em.getConnection().execute(
      'INSERT INTO failed_jobs (queue, job_id, attempts, error) VALUES (?, ?, ?, ?) ON CONFLICT (queue, job_id) DO NOTHING',
      [report.queue, report.jobId ?? null, report.attempts, report.error],
    );
  }
}
