import { KafkaMessage } from 'kafkajs';
import { sharedProducer } from './kafka.provider';

/** Parks a message on `<topic>.dlq` with its original key and headers (alert: kafka_dlq_messages > 0). */
export async function deadLetter(topic: string, message: KafkaMessage, error: unknown): Promise<void> {
  const producer = await sharedProducer();
  await producer.send({
    topic: `${topic}.dlq`,
    messages: [{ key: message.key, value: message.value, headers: { ...message.headers, error: String(error) } }],
  });
}
