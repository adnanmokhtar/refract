import { Injectable } from '@nestjs/common';
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { format } from 'date-fns';
import { AppConfig } from '../config/app-config';
import { bucketFor, s3ClientFor } from '../storage/object-store';
import { ExportJobs, ExportJob } from './export-jobs';
import { renderCsv } from './csv';

/**
 * Builds a merchant's CSV export (shipments, invoices or returns for a date range). Runs on demand from
 * the dashboard and nightly for every merchant with scheduled exports enabled.
 */
@Injectable()
export class ExportRunner {
  private readonly s3 = s3ClientFor(this.config);

  constructor(private readonly config: AppConfig, private readonly jobs: ExportJobs) {}

  async run(job: ExportJob): Promise<string> {
    const csv = await renderCsv(job);
    const key = `exports/${job.tenantId}/${job.kind}_${format(new Date(), 'yyyyMMdd-HHmmss')}.csv`;
    await this.s3.send(new PutObjectCommand({ Bucket: bucketFor(this.config, 'exports'), Key: key, Body: csv, ContentType: 'text/csv' }));
    await this.jobs.markReady(job.id, key);
    return key;
  }
}
