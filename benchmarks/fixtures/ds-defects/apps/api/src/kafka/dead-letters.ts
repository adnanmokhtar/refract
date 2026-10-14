import { Inject, Injectable } from '@nestjs/common';
import { KafkaMessage, Producer } from 'kafkajs';
import { KAFKA_PRODUCER } from './kafka.module';

/** Parks a message that cannot be processed on `<topic>.dlq` with its original key and headers. */
@Injectable()
export class DeadLetters {
  constructor(@Inject(KAFKA_PRODUCER) private readonly producer: Producer) {}

  async park(topic: string, message: KafkaMessage): Promise<void> {
    await this.producer.send({ topic: `${topic}.dlq`, messages: [{ key: message.key, value: message.value, headers: message.headers }] });
  }
}
