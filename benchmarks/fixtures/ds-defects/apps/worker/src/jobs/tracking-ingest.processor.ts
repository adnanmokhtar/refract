import { Processor } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { EntityManager } from '@mikro-orm/postgresql';
import { BaseProcessor } from './base.processor';
import { FailureReports } from '../failures/failure-reports.service';

export interface TrackingIngestJob {
  carrier: string;
  trackingNo: string;
  status: string;
  scannedAt: string;
}

/** Normalises and stores carrier tracking scans (arrival rate and service time: deploy/capacity/tracking-ingest.yaml). */
@Processor('tracking-ingest', { concurrency: 2 })
export class TrackingIngestProcessor extends BaseProcessor<TrackingIngestJob> {
  constructor(
    private readonly em: EntityManager,
    reports: FailureReports,
  ) {
    super(15_000, reports);
  }

  protected async handle(job: Job<TrackingIngestJob>): Promise<void> {
    await this.em.fork().getConnection().execute(
      `INSERT INTO tracking_scans (carrier, tracking_no, status, scanned_at) VALUES (?, ?, ?, ?)
       ON CONFLICT (carrier, tracking_no, scanned_at) DO NOTHING`,
      [job.data.carrier, job.data.trackingNo, job.data.status, job.data.scannedAt],
    );
  }
}
