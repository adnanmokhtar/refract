export abstract class BaseWorker extends WorkerHost {
  constructor(private readonly deadlineMs: number = 30_000) { super(); }
  async process(job: Job) {
    await withDeadline(this.deadlineMs, () => this.handle(job));
  }
}
