const consumer = kafka.consumer({ groupId: 'payments' });
await consumer.run({ partitionsConsumedConcurrently: 3, eachMessage: async ({ message }) => { await handle(message); } });
const producer = kafka.producer({ idempotent: true });
await producer.send({ topic: 'paid', messages: [] });
