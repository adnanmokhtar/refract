import { Producer } from 'kafkajs';
import { KAFKA_PRODUCER } from '../kafka/kafka.module';
export class PlaceOrder {
  constructor(@Inject(KAFKA_PRODUCER) private readonly kafka: Producer) {}
  async run(id: string) {
    await this.kafka.send({ topic: 'orders.placed', messages: [{ key: id, value: id }] });
  }
}
