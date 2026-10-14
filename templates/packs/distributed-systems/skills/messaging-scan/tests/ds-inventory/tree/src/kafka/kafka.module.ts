import { Kafka, Producer } from 'kafkajs';
export const KAFKA_PRODUCER = Symbol('KAFKA_PRODUCER');
@Module({ providers: [{
  provide: KAFKA_PRODUCER,
  inject: [Kafka],
  useFactory: async (kafka: Kafka): Promise<Producer> => {
    const p = kafka.producer({ idempotent: true, maxInFlightRequests: 5 });
    await p.connect();
    return p;
  },
}], exports: [KAFKA_PRODUCER] })
export class KafkaModule {}
