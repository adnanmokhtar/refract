import amqp from 'amqplib';
const ch = await conn.createChannel();
await ch.prefetch(10);
await ch.consume('mail', async (msg) => { await send(msg); ch.ack(msg); }, { noAck: false });
