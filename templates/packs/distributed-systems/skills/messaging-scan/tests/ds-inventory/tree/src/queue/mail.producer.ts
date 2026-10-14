import { QueueName } from './constants';
import { BaseProducer } from './base.producer';
export class MailProducer extends BaseProducer {
  constructor(@InjectQueue(QueueName.MAIL) queue: Queue) { super(queue); }
  async send(to: string) {
    await this.enqueue('send', { to }, to, { attempts: 1 });
  }
}
