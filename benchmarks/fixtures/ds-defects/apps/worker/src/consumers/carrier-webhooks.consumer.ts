import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Channel, ConsumeMessage } from 'amqplib';
import { amqpChannel } from '../amqp/amqp-connection';
import { CarrierWebhookHandler } from './carrier-webhook.handler';

const MAX_ATTEMPTS = 5;

/**
 * Carrier webhooks queued by the ingress. A failure is dead-lettered to carrier-webhooks.retry (TTL 30 s), which
 * dead-letters back here (deploy/rabbitmq/definitions.json); x-death counts the round trips.
 */
@Injectable()
export class CarrierWebhooksConsumer implements OnModuleInit {
  private readonly logger = new Logger(CarrierWebhooksConsumer.name);
  private channel!: Channel;

  constructor(private readonly handler: CarrierWebhookHandler) {}

  async onModuleInit(): Promise<void> {
    this.channel = await amqpChannel();
    await this.channel.prefetch(20);
    await this.channel.consume('carrier-webhooks', (msg) => void this.onMessage(msg));
  }

  private async onMessage(msg: ConsumeMessage | null): Promise<void> {
    if (!msg) return;
    try {
      await this.handler.handle(JSON.parse(msg.content.toString()));
      this.channel.ack(msg);
    } catch (err) {
      const deaths = (msg.properties.headers?.['x-death'] as Array<{ count: number }> | undefined)?.[0]?.count ?? 0;
      if (deaths >= MAX_ATTEMPTS) {
        await this.handler.park(msg.content.toString(), String(err));
        this.channel.ack(msg);
        return;
      }
      this.channel.nack(msg, false, false);
    }
  }
}
