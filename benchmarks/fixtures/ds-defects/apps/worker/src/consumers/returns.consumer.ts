import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Channel, ConsumeMessage } from 'amqplib';
import { amqpChannel } from '../amqp/amqp-connection';
import { ReturnsInspection } from './returns-inspection.service';

/**
 * Consumes returns.inspect (a quorum queue on RabbitMQ 4.3, deploy/rabbitmq/definitions.json: x-delivery-limit 10,
 * DLX returns.dlx). A failed inspection goes back to the queue; the delivery limit dead-letters a message that
 * keeps failing.
 */
@Injectable()
export class ReturnsConsumer implements OnModuleInit {
  private readonly logger = new Logger(ReturnsConsumer.name);
  private channel!: Channel;

  constructor(private readonly inspection: ReturnsInspection) {}

  async onModuleInit(): Promise<void> {
    this.channel = await amqpChannel();
    await this.channel.prefetch(10);
    await this.channel.consume('returns.inspect', (msg) => void this.onMessage(msg));
  }

  private async onMessage(msg: ConsumeMessage | null): Promise<void> {
    if (!msg) return;
    try {
      await this.inspection.inspect(JSON.parse(msg.content.toString()));
      this.channel.ack(msg);
    } catch (err) {
      this.logger.warn(`inspection failed, requeueing: ${String(err)}`);
      this.channel.nack(msg);
    }
  }
}
