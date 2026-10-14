import * as amqp from 'amqplib';

let connection: amqp.ChannelModel | undefined;

export async function amqpChannel(): Promise<amqp.Channel> {
  connection ??= await amqp.connect(process.env.AMQP_URL ?? 'amqp://localhost/fulfilment');
  return connection.createChannel();
}
