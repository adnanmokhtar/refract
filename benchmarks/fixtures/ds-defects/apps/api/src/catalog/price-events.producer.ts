import { Inject, Injectable } from '@nestjs/common';
import { Producer } from 'kafkajs';
import { KAFKA_PRODUCER } from '../kafka/kafka.module';

/**
 * Publishes surcharge changes for the quoting service. The quoting service compacts the topic and keeps the
 * latest value per key.
 */
@Injectable()
export class PriceEventsProducer {
  constructor(@Inject(KAFKA_PRODUCER) private readonly producer: Producer) {}

  async surchargeChanged(carrier: string, pct: number): Promise<void> {
    await this.producer.send({
      topic: 'pricing.surcharge-changed',
      messages: [{ key: `${Date.now()}`, value: JSON.stringify({ carrier, pct }) }],
    });
  }
}
