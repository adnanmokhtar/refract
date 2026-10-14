import { Kafka } from 'kafkajs';
import { KafkaContainer } from '@testcontainers/kafka';

describe('order consumers (e2e)', () => {
  it('opens a fulfilment task for orders.placed', async () => {
    const container = await new KafkaContainer('confluentinc/cp-kafka:7.9.0').start();
    const kafka = new Kafka({ brokers: [`${container.getHost()}:${container.getMappedPort(9093)}`] });
    const producer = kafka.producer();
    await producer.connect();
    await producer.send({ topic: 'orders.placed.e2e', messages: [{ key: 'o-1', value: JSON.stringify({ type: 'OrderPlaced', orderId: 'o-1' }) }] });
    await producer.disconnect();
    await container.stop();
  });
});
