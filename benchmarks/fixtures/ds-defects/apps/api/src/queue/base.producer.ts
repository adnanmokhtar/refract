import { Logger, ServiceUnavailableException } from '@nestjs/common';
import { JobsOptions, Queue } from 'bullmq';

const ENQUEUE_TIMEOUT_MS = 3_000;

export const DEFAULT_JOB_OPTIONS: JobsOptions = {
  attempts: 3,
  backoff: { type: 'exponential', delay: 2_000 },
  removeOnComplete: 1_000,
  removeOnFail: false,
};

/**
 * Every producer of the job Redis extends this class. A Redis outage must not hang an HTTP request, so the
 * enqueue is bounded: past 3 s the caller gets 503 and the client app retries the request.
 */
export abstract class BaseProducer<T> {
  protected readonly logger = new Logger(this.constructor.name);

  protected constructor(protected readonly queue: Queue<T>) {}

  protected async enqueue(name: string, data: T, opts: JobsOptions = {}): Promise<void> {
    let timer: NodeJS.Timeout | undefined;
    const timeout = new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new ServiceUnavailableException('queue unavailable')), ENQUEUE_TIMEOUT_MS);
    });
    try {
      await Promise.race([this.queue.add(name as never, data as never, { ...DEFAULT_JOB_OPTIONS, ...opts }), timeout]);
    } finally {
      clearTimeout(timer);
    }
  }
}
