import { JOB_ATTEMPTS, BACKOFF } from './constants';
export abstract class BaseProducer {
  protected constructor(protected readonly queue: Queue) {}
  async enqueue(name: string, data: unknown, key?: string, opts?: JobsOptions) {
    return this.add(name, data, key, opts);
  }
  private async add(name: string, data: unknown, key: string | undefined, opts: JobsOptions | undefined) {
    const { priority = 1, ...rest } = opts ?? {};
    return this.queue.add(name, data, { ...(key ? { jobId: key } : {}), removeOnComplete: 1000, attempts: JOB_ATTEMPTS, backoff: BACKOFF, ...rest, priority });
  }
}
