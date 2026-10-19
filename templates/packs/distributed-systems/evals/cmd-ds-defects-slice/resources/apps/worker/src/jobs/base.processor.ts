import { OnWorkerEvent, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { FailureReports } from '../failures/failure-reports.service';
import { withDeadline } from './with-deadline';

/**
 * Every processor extends this class. BullMQ calls process(); subclasses implement handle(job, signal).
 * Failed jobs stay in the failed set (no removeOnFail anywhere): that set is the dead letter, and the
 * failure report is how the on-call hears of it.
 */
export abstract class BaseProcessor<T = unknown> extends WorkerHost {
  protected readonly logger = new Logger(this.constructor.name);

  protected constructor(
    private readonly deadlineMs: number,
    private readonly reports: FailureReports,
  ) {
    super();
  }

  protected abstract handle(job: Job<T>, signal: AbortSignal): Promise<void>;

  async process(job: Job<T>): Promise<void> {
    await withDeadline(this.deadlineMs, (signal) => this.handle(job, signal));
  }

  @OnWorkerEvent('failed')
  async onFailed(job: Job<T>, err: Error): Promise<void> {
    if (job.attemptsMade < (job.opts.attempts ?? 1)) return;
    try {
      await this.reports.file({ queue: job.queueName, jobId: job.id, attempts: job.attemptsMade, error: err.message });
    } catch (reportErr) {
      this.logger.warn(`failure report not filed for ${job.queueName}/${job.id}: ${String(reportErr)}`);
    }
  }
}
