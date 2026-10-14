import { QueueName } from './constants';
import { BaseProducer } from './base.producer';
export class ChargeProducer extends BaseProducer {
  constructor(@InjectQueue(QueueName.CHARGE) queue: Queue) { super(queue); }
  override async enqueue(name: string, data: unknown, key?: string, opts?: JobsOptions) {
    return super.enqueue(name, data, key, { attempts: 5, ...opts });
  }
}
