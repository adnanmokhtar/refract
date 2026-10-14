import { Global, Module } from '@nestjs/common';
import { Kafka, Producer } from 'kafkajs';

export const KAFKA_PRODUCER = Symbol('KAFKA_PRODUCER');

@Global()
@Module({
  providers: [
    { provide: Kafka, useFactory: () => new Kafka({ clientId: 'fulfilment-api', brokers: (process.env.KAFKA_BROKERS ?? '').split(',') }) },
    {
      provide: KAFKA_PRODUCER,
      inject: [Kafka],
      useFactory: async (kafka: Kafka): Promise<Producer> => {
        const producer = kafka.producer({ idempotent: true, maxInFlightRequests: 5 });
        await producer.connect();
        return producer;
      },
    },
  ],
  exports: [Kafka, KAFKA_PRODUCER],
})
export class KafkaModule {}
