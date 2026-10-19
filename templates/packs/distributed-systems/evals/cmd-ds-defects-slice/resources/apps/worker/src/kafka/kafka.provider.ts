import { Kafka, Producer } from 'kafkajs';

export const kafka = new Kafka({ clientId: 'fulfilment-worker', brokers: (process.env.KAFKA_BROKERS ?? '').split(',') });

let producer: Producer | undefined;
export async function sharedProducer(): Promise<Producer> {
  if (!producer) {
    producer = kafka.producer({ idempotent: true, maxInFlightRequests: 5 });
    await producer.connect();
  }
  return producer;
}
