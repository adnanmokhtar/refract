import { QueueName, CONCURRENCY, LIMITER } from './constants';
@Processor(QueueName.MAIL, {
  concurrency: CONCURRENCY,
  limiter: { ...LIMITER, max: 10 },
  settings: { backoffStrategy: (n: number) => jittered(n) },
})
export class MailProcessor extends BaseWorker {
  protected async handle(job: Job) { await this.mailer.send(job.data.to); }
  @OnWorkerEvent('failed')
  onFailed() {}
}
