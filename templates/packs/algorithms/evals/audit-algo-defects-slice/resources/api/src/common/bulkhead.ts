/**
 * Bounds concurrent calls to a slow dependency (the carrier label API). At most `maxConcurrent` run;
 * up to `maxWaiting` callers queue, and the next caller beyond that is refused at once.
 */
export class BulkheadFullError extends Error {}

type Waiter = () => void;

export interface BulkheadOptions {
  maxConcurrent: number;
  maxWaiting: number;
}

export class Bulkhead {
  private active = 0;
  private readonly waiting: Waiter[] = [];

  constructor(private readonly opts: BulkheadOptions) {}

  async run<T>(task: () => Promise<T>): Promise<T> {
    if (this.active >= this.opts.maxConcurrent) {
      if (this.waiting.length >= this.opts.maxWaiting) {
        throw new BulkheadFullError('bulkhead full');
      }
      await new Promise<void>((resolve) => this.waiting.push(resolve));
    }
    this.active++;
    try {
      return await task();
    } finally {
      this.active--;
      this.release();
    }
  }

  private release(): void {
    while (this.waiting.length && this.active < this.opts.maxConcurrent) {
      const next = this.waiting.shift()!;
      this.active++;
      queueMicrotask(() => {
        this.active--;
        next();
      });
    }
  }
}
