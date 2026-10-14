import { QueueName } from './constants';
import { CONFIG } from '@acme/config';
@Processor(QueueName.CHARGE, { concurrency: CONFIG.workers, lockDuration: 5000 })
export class ChargeProcessor extends BaseWorker {
  constructor() { super(120_000); }
  protected async handle(job: Job) { await this.psp.charge(job.data); }
}
