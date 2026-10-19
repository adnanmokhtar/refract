import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';

import { loadConfig } from '../config/config.loader';

/** Builds yesterday's totals per currency; scheduled by the reports-daily CronJob. */
@Processor('reports')
export class ReportsDailyProcessor extends WorkerHost {
  private readonly timezone = loadConfig().REPORTS_TIMEZONE;

  async process(job: Job<{ day: string }>): Promise<void> {
    await job.log(`building totals for ${job.data.day} (${this.timezone})`);
  }
}
