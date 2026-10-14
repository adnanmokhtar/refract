import amqp from 'amqplib';
const channel = await conn.createChannel();
await channel.consume('labels', async (msg) => { await print(msg); channel.ack(msg); });
